import '../../core/collection_equality.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/cut.dart';
import '../../models/frame_id.dart';
import '../../models/layer_blend_mode.dart';
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
    this.blendMode = LayerBlendMode.normal,
    this.pose,
    this.anchorPoint,
  });

  final LayerId layerId;
  final FrameId frameId;

  /// The layer's composite blend (R26 #30) — a blend change must change
  /// the composite's identity, and the cache paints with exactly this.
  final LayerBlendMode blendMode;

  /// The layer's EFFECTIVE opacity (static × animated Opacity sample ×
  /// enclosing folders' opacity, L3) — an opacity-lane edit must change
  /// the composite's identity.
  final double opacity;

  final int sourceRevision;

  /// The layer's resolved transform at the frame (null = identity): a
  /// transform edit — or a pose that varies across a held exposure — must
  /// change the composite's identity, and the compose loop draws with
  /// exactly this pose (the signature IS the compose input).
  final TransformPose? pose;

  /// The pose's anchor point (null = canvas center) — same rule as [pose].
  /// Folder FX (L3) arrives already COMPOSED into [pose] by the shared
  /// visit, so a folder FX edit changes the identity through it.
  final CanvasPoint? anchorPoint;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeLayerSignature &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.opacity == opacity &&
          other.sourceRevision == sourceRevision &&
          other.blendMode == blendMode &&
          other.pose == pose &&
          other.anchorPoint == anchorPoint;

  @override
  int get hashCode => Object.hash(
    layerId,
    frameId,
    opacity,
    sourceRevision,
    blendMode,
    pose,
    anchorPoint,
  );

  @override
  String toString() =>
      'CompositeLayerSignature(layerId: $layerId, frameId: $frameId, '
      'opacity: $opacity, sourceRevision: $sourceRevision, pose: $pose, '
      'anchorPoint: $anchorPoint)';
}

/// One node of a composited cut frame's identity: a layer's contribution,
/// or a FOLDER's group buffer around the ones inside it.
///
/// The playback cache paints straight off these — the signature IS the
/// compose input — so the group buffer has to live here or playback would
/// disagree with every other route.
sealed class CompositeNodeSignature {
  const CompositeNodeSignature();
}

final class CompositeLeafSignature extends CompositeNodeSignature {
  const CompositeLeafSignature(this.layer);

  final CompositeLayerSignature layer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeLeafSignature && other.layer == layer;

  @override
  int get hashCode => layer.hashCode;

  @override
  String toString() => 'CompositeLeafSignature($layer)';
}

/// A group buffer's identity: what the folder applies to the composed
/// children, plus the children themselves. A blend/opacity change on the
/// FOLDER must invalidate the composite exactly as a layer's does.
final class CompositeGroupSignature extends CompositeNodeSignature {
  CompositeGroupSignature({
    required List<CompositeNodeSignature> children,
    required this.opacity,
    required this.blendMode,
  }) : children = List.unmodifiable(children);

  final List<CompositeNodeSignature> children;
  final double opacity;
  final LayerBlendMode blendMode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompositeGroupSignature &&
          other.opacity == opacity &&
          other.blendMode == blendMode &&
          listEquals(other.children, children);

  @override
  int get hashCode =>
      Object.hash(opacity, blendMode, Object.hashAll(children));

  @override
  String toString() =>
      'CompositeGroupSignature(opacity: $opacity, blendMode: $blendMode, '
      'children: $children)';
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
    required List<CompositeNodeSignature> nodes,
  }) : nodes = List.unmodifiable(nodes);

  final CanvasSize canvasSize;
  final PlaybackQuality quality;

  /// The composite TREE, bottom → top, matching
  /// [planCutFrameCompositeTree] order.
  final List<CompositeNodeSignature> nodes;

  /// Every painted layer under [nodes], depth-first bottom → top — for
  /// the readers that only need "which cels does this frame use".
  Iterable<CompositeLayerSignature> get layers sync* {
    Iterable<CompositeLayerSignature> walk(
      List<CompositeNodeSignature> list,
    ) sync* {
      for (final node in list) {
        switch (node) {
          case CompositeLeafSignature(:final layer):
            yield layer;
          case CompositeGroupSignature(:final children):
            yield* walk(children);
        }
      }
    }

    yield* walk(nodes);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutFrameCompositeSignature &&
          other.canvasSize == canvasSize &&
          other.quality == quality &&
          listEquals(other.nodes, nodes);

  @override
  int get hashCode => Object.hash(canvasSize, quality, Object.hashAll(nodes));

  @override
  String toString() =>
      'CutFrameCompositeSignature(canvasSize: $canvasSize, '
      'quality: $quality, nodes: $nodes)';
}

/// Computes the signature of the cut's picture at [frameIndex] from the
/// SAME shared visit the composite plan consumes
/// ([resolveCutFrameCompositeTree] — skip rules, exposure resolution,
/// fx-bypass view state, the attach-layer expansion AND the group buffers
/// agree by construction, so composites self-invalidate on any of those
/// changing).
CutFrameCompositeSignature computeCutFrameCompositeSignature({
  required Cut cut,
  required int frameIndex,
  required PlaybackQuality quality,
  required BrushFrameRevisionResolver revisionOf,
  Set<LayerId> fxBypassedLayerIds = const {},
}) {
  List<CompositeNodeSignature> mapNodes(
    List<CutFrameCompositeEntryNode> nodes,
  ) => [
    for (final node in nodes)
      switch (node) {
        // R28 #13: the folder bypass rides the ENTRIES (poses and opacity
        // resolve through it), so the signature self-invalidates on a
        // folder fx toggle exactly as it does on a layer's.
        CutFrameCompositeEntryLeaf(:final entry) => CompositeLeafSignature(
          CompositeLayerSignature(
            layerId: entry.layer.id,
            frameId: entry.frame.id,
            opacity: entry.opacity,
            sourceRevision: revisionOf(entry.layer.id, entry.frame.id),
            blendMode: entry.blendMode,
            pose: entry.pose,
            anchorPoint: entry.anchorPoint,
          ),
        ),
        CutFrameCompositeEntryGroup(
          :final children,
          :final opacity,
          :final blendMode,
        ) =>
          CompositeGroupSignature(
            children: mapNodes(children),
            opacity: opacity,
            blendMode: blendMode,
          ),
      },
  ];

  return CutFrameCompositeSignature(
    canvasSize: cut.canvasSize,
    quality: quality,
    nodes: mapNodes(
      resolveCutFrameCompositeTree(
        cut: cut,
        frameIndex: frameIndex,
        fxBypassedLayerIds: fxBypassedLayerIds,
      ),
    ),
  );
}
