import '../models/bitmap_surface.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/frame.dart';
import '../models/layer.dart';
import '../models/layer_kind.dart';
import '../models/timeline_coverage.dart';
import '../models/transform_track.dart';

/// One paintable layer of a composited cut frame, bottom → top order.
class CutFrameCompositeLayer {
  const CutFrameCompositeLayer({
    required this.surface,
    required this.opacity,
    this.pose,
  });

  final BitmapSurface surface;
  final double opacity;

  /// The layer's transform at this frame; null = identity (no transform
  /// work — the overwhelmingly common case skips the canvas save/restore).
  final TransformPose? pose;
}

/// A layer's identity pose: content centered, unscaled, unrotated — the
/// same canvas-centered shape the camera defaults to, so an empty track
/// composites exactly as before.
TransformPose layerIdentityPose(CanvasSize canvasSize) => TransformPose(
  center: CanvasPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
);

/// The layer's resolved pose at [frameIndex]; null while the track is
/// empty (identity). Shared by the composite plan, the composite cache
/// signature and the editing canvas's layer stack so every route agrees.
TransformPose? resolveLayerPoseAt({
  required Layer layer,
  required CanvasSize canvasSize,
  required int frameIndex,
}) {
  if (layer.transformTrack.isEmpty) {
    return null;
  }
  return layer.transformTrack.resolveAt(
    frameIndex: frameIndex,
    orElse: () => layerIdentityPose(canvasSize),
  );
}

/// Resolves the drawable surface for a layer's frame (e.g. by replaying the
/// brush store's paint commands); `null` when the frame has no artwork.
typedef LayerFrameSurfaceResolver =
    BitmapSurface? Function(Layer layer, Frame frame);

/// Plans which surfaces make up the cut's picture at [frameIndex].
///
/// Layers are visited in list order (first = bottom, later layers draw on
/// top, matching "add layer above"). The camera layer, hidden layers and
/// fully transparent layers are skipped. Exposure resolution matches the
/// timeline: the drawing block covering [frameIndex] shows; uncovered
/// cells contribute nothing.
List<CutFrameCompositeLayer> planCutFrameComposite({
  required Cut cut,
  required int frameIndex,
  required LayerFrameSurfaceResolver surfaceResolver,
}) {
  final plan = <CutFrameCompositeLayer>[];
  for (final layer in cut.layers) {
    if (layer.kind == LayerKind.camera ||
        !layer.isVisible ||
        layer.opacity <= 0) {
      continue;
    }

    final frame = resolveExposedFrameAt(layer, frameIndex);
    if (frame == null) {
      continue;
    }

    final surface = surfaceResolver(layer, frame);
    if (surface == null) {
      continue;
    }

    plan.add(
      CutFrameCompositeLayer(
        surface: surface,
        opacity: layer.opacity.clamp(0.0, 1.0).toDouble(),
        pose: resolveLayerPoseAt(
          layer: layer,
          canvasSize: cut.canvasSize,
          frameIndex: frameIndex,
        ),
      ),
    );
  }
  return plan;
}

/// The frame exposed at [frameIndex]: the drawing block covering the index
/// (same semantics as TimelineController.resolveFrameForLayer — uncovered
/// cells and marks in empty space show nothing). Shared by the composite
/// plan and the composite cache signature so both always agree on what a
/// frame shows.
Frame? resolveExposedFrameAt(Layer layer, int frameIndex) {
  final frameId = exposedFrameIdAt(layer.timeline, frameIndex);
  if (frameId == null) {
    return null;
  }

  for (final frame in layer.frames) {
    if (frame.id == frameId) {
      return frame;
    }
  }
  return null;
}
