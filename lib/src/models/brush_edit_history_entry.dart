import 'brush_commit_result.dart';
import 'cache_invalidation_plan.dart';
import 'dirty_tile_set.dart';
import 'frame_id.dart';
import 'layer_id.dart';

class BrushEditHistoryEntry {
  BrushEditHistoryEntry({
    required this.layerId,
    required this.frameId,
    required this.commitResult,
  }) {
    if (commitResult.isNoOp) {
      throw ArgumentError(
        'BrushEditHistoryEntry requires a changed commitResult.',
      );
    }
  }

  final LayerId layerId;
  final FrameId frameId;
  final BrushCommitResult commitResult;

  CacheInvalidationPlan get cacheInvalidationPlan =>
      commitResult.cacheInvalidationPlan;

  DirtyTileSet get dirtyTiles => commitResult.dirtyTiles;

  int get changedTileCount => commitResult.changedTileCount;

  BrushEditHistoryEntry copyWith({
    LayerId? layerId,
    FrameId? frameId,
    BrushCommitResult? commitResult,
  }) {
    return BrushEditHistoryEntry(
      layerId: layerId ?? this.layerId,
      frameId: frameId ?? this.frameId,
      commitResult: commitResult ?? this.commitResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditHistoryEntry &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.commitResult == commitResult;

  @override
  int get hashCode => Object.hash(layerId, frameId, commitResult);

  @override
  String toString() =>
      'BrushEditHistoryEntry(layerId: $layerId, frameId: $frameId, '
      'commitResult: $commitResult)';
}
