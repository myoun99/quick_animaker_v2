# Phase 183 Codex Task

## Title

Create cache-aware brush edit session operation facade

## Current position

```txt id="jccrjw"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-13. Cache-aware commit / undo / redo facade
```

## Brush work detailed roadmap

```txt id="j138tr"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - done
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit - done
1-11. Cache invalidation execution service - done
1-12. BrushEditSessionState + session operation facade - done
1-13. Cache-aware commit / undo / redo facade - current
1-14. Real Canvas UI integration
1-15. Brush work v1 complete
```

## Goal

Create a cache-aware facade for brush session operations.

Previous phases created:

```txt id="gqlwyh"
- BrushEditSessionState
- commit facade
- undo facade
- redo facade
- CacheInvalidationSink
- executeCacheInvalidationPlan
```

This phase should combine them.

When commit / undo / redo changes something, execute the related `CacheInvalidationPlan` through the given `CacheInvalidationSink`.

Do not implement real cache storage.

Do not add UI.

Do not add save/load.

## Required files

Create:

```txt id="lukfta"
lib/src/models/brush_edit_session_operation_kind.dart
lib/src/models/brush_edit_session_cache_operation_result.dart
lib/src/services/brush_edit_session_cache_operations.dart
test/models/brush_edit_session_cache_operation_result_test.dart
test/services/brush_edit_session_cache_operations_test.dart
```

## Required enum

Create:

```dart id="dybq37"
enum BrushEditSessionOperationKind {
  commit,
  undo,
  redo,
}
```

## Required model

Create:

```dart id="x3bdzy"
class BrushEditSessionCacheOperationResult {
  BrushEditSessionCacheOperationResult({
    required this.kind,
    required this.sessionState,
    required this.affectedEntry,
    required this.cacheInvalidationResult,
  });

  final BrushEditSessionOperationKind kind;
  final BrushEditSessionState sessionState;
  final BrushEditHistoryEntry? affectedEntry;
  final CacheInvalidationExecutionResult cacheInvalidationResult;

  bool get didAffectHistory;
  bool get didInvalidateCache;

  BrushEditSessionCacheOperationResult copyWith({
    BrushEditSessionOperationKind? kind,
    BrushEditSessionState? sessionState,
    Object? affectedEntry,
    CacheInvalidationExecutionResult? cacheInvalidationResult,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Getter behavior:

```txt id="hm84oq"
didAffectHistory == affectedEntry != null
didInvalidateCache == cacheInvalidationResult.didInvalidate
```

Use a nullable sentinel in `copyWith` for `affectedEntry`.

Do not add JSON.

## Required services

Create:

```dart id="v910hz"
BrushEditSessionCacheOperationResult commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
  required CacheInvalidationSink cacheInvalidationSink,
})
```

Behavior:

```txt id="bqqrwu"
1. Call existing commitBrushDabSequenceToBrushEditSessionState.
2. Convert the commit result to BrushEditSessionState with sessionStateFromCommitResult.
3. If commitResult.historyEntry is null:
   - do not call executeCacheInvalidationPlan
   - cache result should be zero counts
4. If commitResult.historyEntry is non-null:
   - execute commitResult.historyEntry.cacheInvalidationPlan
   - use executeCacheInvalidationPlan
5. Return BrushEditSessionCacheOperationResult:
   kind = commit
   sessionState = converted session state
   affectedEntry = commitResult.historyEntry
   cacheInvalidationResult = execution result
```

Create:

```dart id="su2n6a"
BrushEditSessionCacheOperationResult undoLatestBrushEditInSessionStateWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required CacheInvalidationSink cacheInvalidationSink,
})
```

Behavior:

```txt id="lwxnts"
1. Call existing undoLatestBrushEditInSessionState.
2. Convert the undo result to BrushEditSessionState with sessionStateFromUndoResult.
3. If undoResult.undoneEntry is null:
   - do not call executeCacheInvalidationPlan
   - cache result should be zero counts
4. If undoResult.undoneEntry is non-null:
   - execute undoResult.undoneEntry.cacheInvalidationPlan
   - use executeCacheInvalidationPlan
5. Return BrushEditSessionCacheOperationResult:
   kind = undo
   sessionState = converted session state
   affectedEntry = undoResult.undoneEntry
   cacheInvalidationResult = execution result
```

Create:

```dart id="jr6idr"
BrushEditSessionCacheOperationResult redoLatestBrushEditInSessionStateWithCacheInvalidation({
  required BrushEditSessionState sessionState,
  required CacheInvalidationSink cacheInvalidationSink,
})
```

Behavior:

```txt id="txx2dm"
1. Call existing redoLatestBrushEditInSessionState.
2. Convert the redo result to BrushEditSessionState with sessionStateFromRedoResult.
3. If redoResult.redoneEntry is null:
   - do not call executeCacheInvalidationPlan
   - cache result should be zero counts
4. If redoResult.redoneEntry is non-null:
   - execute redoResult.redoneEntry.cacheInvalidationPlan
   - use executeCacheInvalidationPlan
5. Return BrushEditSessionCacheOperationResult:
   kind = redo
   sessionState = converted session state
   affectedEntry = redoResult.redoneEntry
   cacheInvalidationResult = execution result
```

## Important constraints

```txt id="punhge"
Do not implement actual cache storage.
Do not implement cache recomputation.
Do not implement LayerTileCache.
Do not implement FrameCompositeCache.
Do not implement PlaybackPreviewCache.

Do not manually build BrushCommitResult.
Do not manually build BrushSurfaceEdit.
Do not manually build BrushEditHistoryEntry.
Do not manually build TileDeltaCommand.
Do not manually build CacheInvalidationPlan.
Do not manually apply TileDelta objects.

Do not call command.applyBefore or command.applyAfter directly.
Do not call surface.putTile or surface.removeTile directly.

Do not add Canvas UI.
Do not add Provider / Riverpod / Bloc / ChangeNotifier.
Do not add save/load.
Do not change timeline.
Do not change storyboard.
```

This phase is a cache-aware facade only.

## Required tests

Model tests:

```txt id="ryp0f8"
- stores kind, sessionState, affectedEntry, cacheInvalidationResult
- didAffectHistory false when affectedEntry is null
- didAffectHistory true when affectedEntry is non-null
- didInvalidateCache delegates to cacheInvalidationResult.didInvalidate
- copyWith preserves omitted values
- copyWith updates kind
- copyWith updates sessionState
- copyWith can set affectedEntry
- copyWith can clear affectedEntry with null
- copyWith updates cacheInvalidationResult
- equality / hashCode / toString
```

Service tests:

```txt id="wocqjx"
- commit no-op does not call cache sink
- commit no-op returns zero cache invalidation result
- commit changed calls cache sink
- commit changed result kind is commit
- commit changed result sessionState matches normal session commit conversion
- commit changed affectedEntry equals normal commit historyEntry

- undo no-op does not call cache sink
- undo no-op returns zero cache invalidation result
- undo changed calls cache sink
- undo changed result kind is undo
- undo changed result sessionState matches normal undo conversion
- undo changed affectedEntry equals normal undo undoneEntry

- redo no-op does not call cache sink
- redo no-op returns zero cache invalidation result
- redo changed calls cache sink
- redo changed result kind is redo
- redo changed result sessionState matches normal redo conversion
- redo changed affectedEntry equals normal redo redoneEntry

- cache invalidation counts match executed plan counts
- commit -> undo -> redo with cache-aware facade works
- input BrushEditSessionState is not mutated
- input CanvasSurfaceState is not mutated
- input BrushEditHistoryState is not mutated
- CacheInvalidationPlan is not mutated
- no real cache storage is implemented
- no UI/state management/timeline/storyboard changes
```

Use a fake sink similar to Phase 181:

```dart id="fh8qgf"
class FakeCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  int get totalCalls =>
      layerTiles.length + frameComposites.length + playbackPreviews.length;

  @override
  void invalidateLayerTile(LayerTileCacheKey key) {
    layerTiles.add(key);
  }

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) {
    frameComposites.add(key);
  }

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) {
    playbackPreviews.add(key);
  }
}
```

## Required references

Read before editing:

```txt id="dv7pj4"
docs/Phase_181_Codex_Task.md
docs/Phase_182_Codex_Task.md
lib/src/models/brush_edit_session_state.dart
lib/src/models/brush_edit_session_commit_result.dart
lib/src/models/brush_edit_undo_result.dart
lib/src/models/brush_edit_redo_result.dart
lib/src/models/cache_invalidation_execution_result.dart
lib/src/services/brush_edit_session_state_operations.dart
lib/src/services/cache_invalidation_executor.dart
test/services/cache_invalidation_executor_test.dart
test/services/brush_edit_session_state_operations_test.dart
```

## Out of scope

Do not add:

```txt id="uwx6rn"
Canvas UI
Pointer input
Brush tool widget
HistoryService
Provider / Riverpod / Bloc / ChangeNotifier
Real cache storage
Cache recomputation
Save / load
Timeline changes
Storyboard changes
```

## Required checks

Run:

```bash id="su32jt"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase is model/service-only.

If the app is run, only confirm:

```txt id="h3gu9j"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```

## Report back

Report:

```txt id="ge03x0"
- changed files
- BrushEditSessionOperationKind behavior
- BrushEditSessionCacheOperationResult behavior
- cache-aware commit behavior
- cache-aware undo behavior
- cache-aware redo behavior
- no-op behavior
- cache execution behavior
- cache count behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
