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
  });

  final EditorSessionManager session;
  final CameraFrameRenderService renderService;

  final Map<(LayerId, FrameId), BitmapSurface?> _surfaces = {};
  CutId? _surfacesCutId;

  BitmapSurface? _surfaceFor(Cut cut, Layer layer, Frame frame) {
    if (_surfacesCutId != cut.id) {
      _surfaces.clear();
      _surfacesCutId = cut.id;
    }
    return _surfaces.putIfAbsent((layer.id, frame.id), () {
      final frameKey = session.brushFrameKeyForCut(cut, layer.id, frame.id);
      final drawing = session.brushFrameStore.frameOrNull(frameKey);
      if (drawing == null || drawing.allPaintCommandsInDisplayOrder.isEmpty) {
        return null;
      }
      // The store's display cache usually holds the exact pixels already —
      // the editing coordinator donates the session surface on every
      // commit/undo/redo — so reuse it READ-ONLY instead of replaying the
      // frame's whole command list (the storyboard thumbnail re-render after
      // each stroke was a main part of the post-stroke UI freeze). Replay
      // stays the cold fallback; nothing is stored back, so batch exports
      // don't grow the shared cache.
      final cached = session.brushFrameStore.displayCacheOrNull(frameKey);
      if (cached != null &&
          cached.isValid &&
          cached.previewSurface.canvasSize == cut.canvasSize) {
        return cached.previewSurface;
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
      // switch affects the render) — WYSIWYG with playback.
      layers: planCutFrameComposite(
        cut: cut,
        frameIndex: task.frameIndex,
        surfaceResolver: (layer, frame) => _surfaceFor(cut, layer, frame),
        fxBypassedLayerIds: session.fxBypassedLayerIds,
      ),
      pose: pose,
      cameraFrameSize: mode == ExportSizeMode.camera
          ? session.cameraFrameSize
          : cut.canvasSize,
      outputSize: outputSize,
    );
  }

  /// [renderComposite] with the cut fade baked in for VIDEO frames: the
  /// frame draws at its fade opacity over the cut's fade TARGET color
  /// (FO=black default, WO=white — cutFadeTargetColor, the same value
  /// playback overlays) — MP4 carries no alpha (yuv420p drops the channel
  /// without blending), so the fade must land in the RGB values. Unfaded
  /// frames pass through untouched. PNG sequences deliberately stay
  /// unfaded (they are compositing sources).
  Future<ui.Image> renderCompositeForVideo(
    ExportFrameTask task,
    ExportSizeMode mode,
  ) async {
    final image = await renderComposite(task, mode);
    final fade = task.cut.fadeOpacityAt(task.frameIndex);
    if (fade >= 1) {
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
    canvas.drawRect(bounds, ui.Paint()..color = cutFadeTargetColor(task.cut));
    canvas.drawImage(
      image,
      ui.Offset.zero,
      ui.Paint()..color = ui.Color.fromRGBO(0, 0, 0, fade),
    );
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
