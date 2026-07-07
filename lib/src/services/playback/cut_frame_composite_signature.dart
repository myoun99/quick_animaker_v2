import '../../core/collection_equality.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/playback_quality.dart';
import '../cut_frame_composite_plan.dart';

/// Resolves the brush store's current source revision for a layer frame
/// (0 when nothing has been drawn on it yet).
typedef BrushFrameRevisionResolver =
    int Function(LayerId layerId, FrameId frameId);

/// One layer's contribution to a composited cut frame, reduced to exactly
/// the inputs that change its pixels.
class CompositeLayerSignature {
  const CompositeLayerSignature({
    required this.layerId,
    required this.frameId,
    required this.opacity,
    required this.sourceRevision,
  });

  final LayerId layerId;
  final FrameId frameId;
  final double opacity;
  final int sourceRevision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeLayerSignature &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.opacity == opacity &&
          other.sourceRevision == sourceRevision;

  @override
  int get hashCode => Object.hash(layerId, frameId, opacity, sourceRevision);

  @override
  String toString() =>
      'CompositeLayerSignature(layerId: $layerId, frameId: $frameId, '
      'opacity: $opacity, sourceRevision: $sourceRevision)';
}

/// Identity of a composited cut frame's pixels.
///
/// A cached composite is valid iff its stored signature equals the freshly
/// recomputed one — this self-validates against timeline exposure edits,
/// layer visibility/opacity/reorder, canvas resizes, brush edits (via
/// sourceRevision) and undo/redo without hooking every command. Held
/// exposures produce equal signatures, so composites deduplicate across
/// held frames. Camera data is deliberately absent: composites are
/// canvas-space and camera changes must not invalidate them.
class CutFrameCompositeSignature {
  CutFrameCompositeSignature({
    required this.canvasSize,
    required this.quality,
    required List<CompositeLayerSignature> layers,
  }) : layers = List.unmodifiable(layers);

  final CanvasSize canvasSize;
  final PlaybackQuality quality;

  /// Bottom → top, matching [planCutFrameComposite] order.
  final List<CompositeLayerSignature> layers;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutFrameCompositeSignature &&
          other.canvasSize == canvasSize &&
          other.quality == quality &&
          listEquals(other.layers, layers);

  @override
  int get hashCode => Object.hash(canvasSize, quality, Object.hashAll(layers));

  @override
  String toString() =>
      'CutFrameCompositeSignature(canvasSize: $canvasSize, '
      'quality: $quality, layers: $layers)';
}

/// Computes the signature of the cut's picture at [frameIndex], visiting
/// layers with the exact skip/exposure rules of [planCutFrameComposite].
CutFrameCompositeSignature computeCutFrameCompositeSignature({
  required Cut cut,
  required int frameIndex,
  required PlaybackQuality quality,
  required BrushFrameRevisionResolver revisionOf,
}) {
  final layers = <CompositeLayerSignature>[];
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
    layers.add(
      CompositeLayerSignature(
        layerId: layer.id,
        frameId: frame.id,
        opacity: layer.opacity.clamp(0.0, 1.0).toDouble(),
        sourceRevision: revisionOf(layer.id, frame.id),
      ),
    );
  }
  return CutFrameCompositeSignature(
    canvasSize: cut.canvasSize,
    quality: quality,
    layers: layers,
  );
}
