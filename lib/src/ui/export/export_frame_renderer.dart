import 'dart:ui' as ui;

import '../../models/bitmap_surface.dart';
import '../../models/camera_pose.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../services/brush_frame_display_cache_renderer.dart';
import '../../services/cut_frame_composite_plan.dart';
import '../camera/camera_frame_render_service.dart';
import '../canvas/layer_pose_paint.dart';
import '../editor_session_manager.dart';
import '../storyboard_cut_fade_policy.dart';
import 'export_plan.dart';

/// Renders export output at full quality straight from the brush store, so
/// exports never depend on the playback quality setting or its caches.
///
/// Surfaces are cached per cut and dropped on cut change: an all-cuts export
/// holds at most one cut's cels in memory while streaming.
class ExportFrameRenderer {
  ExportFrameRenderer({
    required this.session,
    this.renderService = const CameraFrameRenderService(),
    this.applyLayerFx = true,
  });

  final EditorSessionManager session;
  final CameraFrameRenderService renderService;

  /// The export dialog's 'Apply layer FX' toggle: true (default) exports
  /// WYSIWYG with playback (per-layer fx switches respected); false
  /// bypasses EVERY layer's FX — raw cels at their static opacity, no
  /// transforms. The cut fade and the camera work are cut-level and stay.
  final bool applyLayerFx;

  final Map<(LayerId, FrameId), BitmapSurface?> _surfaces = {};
  CutId? _surfacesCutId;

  BitmapSurface? _surfaceFor(Cut cut, Layer layer, Frame frame) {
    if (_surfacesCutId != cut.id) {
      _surfaces.clear();
      _surfacesCutId = cut.id;
    }
    return _surfaces.putIfAbsent((layer.id, frame.id), () {
      final frameKey = session.brushFrameKeyForCut(cut, layer.id, frame.id);
      final store = session.brushFrameStore;
      // Content oracle, not a command check (R19 P3a): an OPENED cel's
      // picture is its baked raster with no commands — the old guard
      // exported every loaded cel BLANK.
      if (!store.celHasRenderableContent(frameKey)) {
        return null;
      }
      // Valid display cache or the baked truth, READ-ONLY (the coordinator
      // donates on every commit/undo/redo, so this is usually the exact
      // pixels already). Nothing is stored back, so batch exports don't
      // grow the shared cache. Replay stays the cold fallback for legacy
      // this-session command cels whose cache went stale.
      final direct = store.currentSurfaceWithoutReplay(
        frameKey,
        canvasSize: cut.canvasSize,
      );
      if (direct != null) {
        return direct;
      }
      final drawing = store.frameOrNull(frameKey);
      if (drawing == null) {
        return null;
      }
      return BrushFrameDisplayCacheRenderer(
        canvasSize: cut.canvasSize,
      ).rebuildPreview(drawing);
    });
  }

  /// One composited frame. [ExportSizeMode.canvas] renders the identity
  /// camera over the cut's own canvas size (centered, zoom 1, no rotation),
  /// which is exactly the raw canvas at 1:1 pixels on the white paper.
  /// [outputSize] scales the same view down (storyboard thumbnails); null
  /// exports at full size.
  Future<ui.Image> renderComposite(
    ExportFrameTask task,
    ExportSizeMode mode, {
    CanvasSize? outputSize,
  }) {
    final cut = task.cut;
    final pose = mode == ExportSizeMode.camera
        ? session.cameraPoseForCut(cut, task.frameIndex)
        : CameraPose(
            center: CanvasPoint(
              x: cut.canvasSize.width / 2,
              y: cut.canvasSize.height / 2,
            ),
          );
    return renderService.renderThroughCamera(
      // The fx-bypass switches apply here too (AE semantics: the layer fx
      // switch affects the render) — WYSIWYG with playback. The dialog's
      // 'Apply layer FX' master toggle bypasses every layer at once.
      layers: planCutFrameComposite(
        cut: cut,
        frameIndex: task.frameIndex,
        surfaceResolver: (layer, frame) => _surfaceFor(cut, layer, frame),
        fxBypassedLayerIds: applyLayerFx
            ? session.fxBypassedLayerIds
            : {for (final layer in cut.layers) layer.id},
      ),
      pose: pose,
      cameraFrameSize: mode == ExportSizeMode.camera
          ? session.cameraFrameSize
          : cut.canvasSize,
      outputSize: outputSize,
    );
  }

  /// [renderComposite] with the cut-level pose and fade baked in for VIDEO
  /// frames — MP4 carries no alpha (yuv420p drops the channel without
  /// blending) and no display-time compositor, so both must land in the
  /// RGB values. The bake mirrors playback exactly: the finished frame
  /// posed over the output space (V track Transform, AE precomp
  /// semantics), then the fade TARGET color (FO=black default, WO=white —
  /// cutFadeTargetColor, the same value playback overlays) at
  /// (1 − fade) on top; without a pose that reduces pixel-for-pixel to
  /// the old frame-at-fade-over-target draw. Untouched frames pass
  /// through. PNG sequences deliberately stay unposed and unfaded (they
  /// are compositing sources).
  Future<ui.Image> renderCompositeForVideo(
    ExportFrameTask task,
    ExportSizeMode mode,
  ) async {
    if (task.isGap) {
      // A leading-gap frame: nothing plays — the project background,
      // exactly what playback shows in the gap (R10-⑥). Transparent
      // backgrounds bake their opaque fallback (MP4 carries no alpha).
      final size = mode == ExportSizeMode.camera
          ? session.cameraFrameSize
          : task.cut.canvasSize;
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        ui.Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
        ui.Paint()..color = ui.Color(session.projectBackground.argb),
      );
      final picture = recorder.endRecording();
      try {
        return await picture.toImage(size.width, size.height);
      } finally {
        picture.dispose();
      }
    }
    final image = await renderComposite(task, mode);
    final fade = task.cut.fadeOpacityAt(task.frameIndex);
    final poseActive = cutPoseIsActive(task.cut);
    if (fade >= 1 && !poseActive) {
      return image;
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final bounds = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    // Black ground: the pose can uncover the output edges; without a pose
    // the frame covers everything and the ground never shows.
    canvas.drawRect(bounds, ui.Paint()..color = const ui.Color(0xFF000000));
    if (poseActive) {
      final space = CanvasSize(width: image.width, height: image.height);
      canvas.save();
      applyLayerPoseTransform(
        canvas,
        cutPoseAt(task.cut, task.frameIndex, space),
        space,
        anchorPoint: cutAnchorPointAt(task.cut, task.frameIndex),
      );
    }
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    if (poseActive) {
      canvas.restore();
    }
    if (fade < 1) {
      canvas.drawRect(
        bounds,
        ui.Paint()
          ..color = cutFadeTargetColor(
            task.cut,
          ).withValues(alpha: (1 - fade).clamp(0.0, 1.0)),
      );
    }
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(image.width, image.height);
    } finally {
      picture.dispose();
      image.dispose();
    }
  }

  /// One cel exactly as drawn, no compositing; `null` when the frame has no
  /// artwork (the export loop skips the file). [transparent] keeps the
  /// background empty; otherwise the cel sits on the white paper at the
  /// cut's canvas size.
  Future<ui.Image?> renderCel(ExportCelTask task, {bool transparent = true}) {
    final surface = _surfaceFor(task.cut, task.layer, task.frame);
    if (surface == null) {
      return Future<ui.Image?>.value();
    }
    if (transparent) {
      return bitmapSurfaceToImage(surface);
    }
    return renderService.renderThroughCamera(
      layers: [CutFrameCompositeLayer(surface: surface, opacity: 1)],
      pose: CameraPose(
        center: CanvasPoint(
          x: task.cut.canvasSize.width / 2,
          y: task.cut.canvasSize.height / 2,
        ),
      ),
      cameraFrameSize: task.cut.canvasSize,
    );
  }
}
