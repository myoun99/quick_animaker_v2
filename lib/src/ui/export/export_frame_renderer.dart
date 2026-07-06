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
      final drawing = session.brushFrameStore.frameOrNull(
        session.brushFrameKeyForCut(cut, layer.id, frame.id),
      );
      if (drawing == null || drawing.allPaintCommandsInDisplayOrder.isEmpty) {
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
      layers: planCutFrameComposite(
        cut: cut,
        frameIndex: task.frameIndex,
        surfaceResolver: (layer, frame) => _surfaceFor(cut, layer, frame),
      ),
      pose: pose,
      cameraFrameSize: mode == ExportSizeMode.camera
          ? session.cameraFrameSize
          : cut.canvasSize,
      outputSize: outputSize,
    );
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
