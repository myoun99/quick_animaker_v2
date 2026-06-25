import '../models/brush_dab_sequence.dart';
import '../models/brush_edit_session_cache_operation_result.dart';
import '../models/brush_edit_session_operation_kind.dart';
import '../models/brush_edit_session_state.dart';
import '../models/cache_invalidation_execution_result.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_edit_session_state_operations.dart';
import 'cache_invalidation_executor.dart';

BrushEditSessionCacheOperationResult
commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
  required CacheInvalidationSink cacheInvalidationSink,
}) {
  final commitResult = commitBrushDabSequenceToBrushEditSessionState(
    sessionState: sessionState,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );
  final historyEntry = commitResult.historyEntry;

  return BrushEditSessionCacheOperationResult(
    kind: BrushEditSessionOperationKind.commit,
    sessionState: sessionStateFromCommitResult(commitResult),
    affectedEntry: historyEntry,
    cacheInvalidationResult: historyEntry == null
        ? _zeroCacheInvalidationResult()
        : executeCacheInvalidationPlan(
            plan: historyEntry.cacheInvalidationPlan,
            sink: cacheInvalidationSink,
          ),
  );
}

BrushEditSessionCacheOperationResult
undoLatestBrushEditInSessionStateWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required CacheInvalidationSink cacheInvalidationSink,
}) {
  final undoResult = undoLatestBrushEditInSessionState(
    sessionState: sessionState,
  );
  final undoneEntry = undoResult.undoneEntry;

  return BrushEditSessionCacheOperationResult(
    kind: BrushEditSessionOperationKind.undo,
    sessionState: sessionStateFromUndoResult(undoResult),
    affectedEntry: undoneEntry,
    cacheInvalidationResult: undoneEntry == null
        ? _zeroCacheInvalidationResult()
        : executeCacheInvalidationPlan(
            plan: undoneEntry.cacheInvalidationPlan,
            sink: cacheInvalidationSink,
          ),
  );
}

BrushEditSessionCacheOperationResult
redoLatestBrushEditInSessionStateWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required CacheInvalidationSink cacheInvalidationSink,
}) {
  final redoResult = redoLatestBrushEditInSessionState(
    sessionState: sessionState,
  );
  final redoneEntry = redoResult.redoneEntry;

  return BrushEditSessionCacheOperationResult(
    kind: BrushEditSessionOperationKind.redo,
    sessionState: sessionStateFromRedoResult(redoResult),
    affectedEntry: redoneEntry,
    cacheInvalidationResult: redoneEntry == null
        ? _zeroCacheInvalidationResult()
        : executeCacheInvalidationPlan(
            plan: redoneEntry.cacheInvalidationPlan,
            sink: cacheInvalidationSink,
          ),
  );
}

CacheInvalidationExecutionResult _zeroCacheInvalidationResult() {
  return CacheInvalidationExecutionResult(
    layerTileCount: 0,
    frameCompositeCount: 0,
    playbackPreviewCount: 0,
  );
}
