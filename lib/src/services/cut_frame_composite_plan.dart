import '../models/bitmap_surface.dart';
import '../models/cut.dart';
import '../models/frame.dart';
import '../models/layer.dart';
import '../models/layer_kind.dart';
import '../models/timeline_exposure.dart';
import '../models/timeline_exposure_type.dart';

/// One paintable layer of a composited cut frame, bottom → top order.
class CutFrameCompositeLayer {
  const CutFrameCompositeLayer({required this.surface, required this.opacity});

  final BitmapSurface surface;
  final double opacity;
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
/// timeline: the last exposure entry at or before [frameIndex] holds, and
/// blank exposures contribute nothing.
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

    final frame = _resolveFrameAt(layer, frameIndex);
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
      ),
    );
  }
  return plan;
}

/// The frame exposed at [frameIndex]: the last exposure entry at or before
/// the index (same semantics as TimelineController.resolveFrameForLayer).
Frame? _resolveFrameAt(Layer layer, int frameIndex) {
  if (frameIndex < 0 || layer.timeline.isEmpty) {
    return null;
  }

  TimelineExposure? activeExposure;
  for (final entry in layer.timeline.entries) {
    if (entry.key > frameIndex) {
      break;
    }
    activeExposure = entry.value;
  }

  if (activeExposure == null ||
      activeExposure.type == TimelineExposureType.blank) {
    return null;
  }
  final frameId = activeExposure.frameId;
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
