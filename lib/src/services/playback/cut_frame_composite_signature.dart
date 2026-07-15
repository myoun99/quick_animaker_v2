import '../../core/collection_equality.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/playback_quality.dart';
import '../../models/transform_track.dart';
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
    this.pose,
    this.anchorPoint,
  });

  final LayerId layerId;
  final FrameId frameId;

  /// The layer's EFFECTIVE opacity (static × animated Opacity sample) — an
  /// opacity-lane edit must change the composite's identity.
  final double opacity;

  final int sourceRevision;

  /// The layer's resolved transform at the frame (null = identity): a
  /// transform edit — or a pose that varies across a held exposure — must
  /// change the composite's identity, and the compose loop draws with
  /// exactly this pose (the signature IS the compose input).
  final TransformPose? pose;

  /// The pose's anchor point (null = canvas center) — same rule as [pose].
  final CanvasPoint? anchorPoint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeLayerSignature &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.opacity == opacity &&
          other.sourceRevision == sourceRevision &&
          other.pose == pose &&
          other.anchorPoint == anchorPoint;

  @override
  int get hashCode =>
      Object.hash(layerId, frameId, opacity, sourceRevision, pose, anchorPoint);

  @override
  String toString() =>
      'CompositeLayerSignature(layerId: $layerId, frameId: $frameId, '
      'opacity: $opacity, sourceRevision: $sourceRevision, pose: $pose, '
      'anchorPoint: $anchorPoint)';
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

/// Computes the signature of the cut's picture at [frameIndex] from the
/// SAME shared visit the composite plan consumes
/// ([resolveCutFrameCompositeEntries] — skip rules, exposure resolution,
/// fx-bypass view state and the attach-layer expansion agree by
/// construction, so composites self-invalidate on any of those changing).
CutFrameCompositeSignature computeCutFrameCompositeSignature({
  required Cut cut,
  required int frameIndex,
  required PlaybackQuality quality,
  required BrushFrameRevisionResolver revisionOf,
  Set<LayerId> fxBypassedLayerIds = const {},
  LayerId? soloVisibleLayerId,
}) {
  return CutFrameCompositeSignature(
    canvasSize: cut.canvasSize,
    quality: quality,
    layers: [
      for (final entry in resolveCutFrameCompositeEntries(
        cut: cut,
        frameIndex: frameIndex,
        fxBypassedLayerIds: fxBypassedLayerIds,
        soloVisibleLayerId: soloVisibleLayerId,
      ))
        CompositeLayerSignature(
          layerId: entry.layer.id,
          frameId: entry.frame.id,
          opacity: entry.opacity,
          sourceRevision: revisionOf(entry.layer.id, entry.frame.id),
          pose: entry.pose,
          anchorPoint: entry.anchorPoint,
        ),
    ],
  );
}
