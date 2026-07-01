import 'brush_commit_result.dart';
import 'cache_invalidation_plan.dart';
import 'dirty_tile_set.dart';
import 'frame_id.dart';
import 'layer_id.dart';

/// Internal bitmap materialization snapshot entry.
///
/// This entry wraps a BrushCommitResult only for temporary/session-local
/// BitmapSurface materialization and cache invalidation. It must not be used as
/// the authoritative brush command or user-facing undo payload; production
/// brush undo uses BrushPaintCommand refs in UnifiedUndoHistory.
class BrushBitmapMaterializationHistoryEntry {
  BrushBitmapMaterializationHistoryEntry({
    required this.layerId,
    required this.frameId,
    required this.commitResult,
  }) {
    if (commitResult.isNoOp) {
      throw ArgumentError(
        'BrushBitmapMaterializationHistoryEntry requires a changed commitResult.',
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

  BrushBitmapMaterializationHistoryEntry copyWith({
    LayerId? layerId,
    FrameId? frameId,
    BrushCommitResult? commitResult,
  }) {
    return BrushBitmapMaterializationHistoryEntry(
      layerId: layerId ?? this.layerId,
      frameId: frameId ?? this.frameId,
      commitResult: commitResult ?? this.commitResult,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushBitmapMaterializationHistoryEntry &&
          other.layerId == layerId &&
          other.frameId == frameId &&
          other.commitResult == commitResult;

  @override
  int get hashCode => Object.hash(layerId, frameId, commitResult);

  @override
  String toString() =>
      'BrushBitmapMaterializationHistoryEntry(layerId: $layerId, frameId: $frameId, '
      'commitResult: $commitResult)';
}
