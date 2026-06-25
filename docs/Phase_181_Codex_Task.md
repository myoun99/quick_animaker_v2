# Phase 181 Codex Task

## Title

Create cache invalidation execution service

## Current position

```txt id="qwagjx"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-11. Cache invalidation execution service
```

## Brush work detailed roadmap

```txt id="ohwnrb"
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
1-11. Cache invalidation execution service - current
1-12. Real Canvas UI integration
1-13. Brush work v1 complete
```

## Goal

Create a small service that executes a `CacheInvalidationPlan` by sending invalidation keys to an abstract sink.

This phase should not implement a real cache yet.

It should only provide the execution bridge:

```txt id="15p2kk"
CacheInvalidationPlan
-> CacheInvalidationSink
-> CacheInvalidationExecutionResult
```

## Required files

Create:

```txt id="iq79uh"
lib/src/models/cache_invalidation_execution_result.dart
lib/src/services/cache_invalidation_executor.dart
test/models/cache_invalidation_execution_result_test.dart
test/services/cache_invalidation_executor_test.dart
```

## Required model

Create:

```dart id="walsbn"
class CacheInvalidationExecutionResult {
  CacheInvalidationExecutionResult({
    required this.layerTileCount,
    required this.frameCompositeCount,
    required this.playbackPreviewCount,
  });

  final int layerTileCount;
  final int frameCompositeCount;
  final int playbackPreviewCount;

  int get totalCount;
  bool get didInvalidate;

  CacheInvalidationExecutionResult copyWith({
    int? layerTileCount,
    int? frameCompositeCount,
    int? playbackPreviewCount,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Validation:

```txt id="g79fu4"
- counts must be >= 0
```

No JSON.

## Required service

Create:

```dart id="j7a82i"
abstract class CacheInvalidationSink {
  void invalidateLayerTile(LayerTileCacheKey key);
  void invalidateFrameComposite(FrameCompositeCacheKey key);
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key);
}
```

Create:

```dart id="iu0cyr"
CacheInvalidationExecutionResult executeCacheInvalidationPlan({
  required CacheInvalidationPlan plan,
  required CacheInvalidationSink sink,
})
```

Behavior:

```txt id="fyhm8o"
1. For every plan.layerTiles key:
   sink.invalidateLayerTile(key)

2. For every plan.frameComposites key:
   sink.invalidateFrameComposite(key)

3. For every plan.playbackPreviews key:
   sink.invalidatePlaybackPreview(key)

4. Return CacheInvalidationExecutionResult with each count.
```

Important:

```txt id="rxn1w4"
- Do not implement actual cache storage.
- Do not implement LayerTileCache.
- Do not implement FrameCompositeCache.
- Do not implement PlaybackPreviewCache.
- Do not recompute cache.
- Do not touch BitmapSurface.
- Do not execute brush commit.
- Do not execute undo/redo.
- Do not add UI.
```

## Required tests

Model tests:

```txt id="b0zw52"
- stores counts
- rejects negative counts
- totalCount sums all counts
- didInvalidate false when totalCount is 0
- didInvalidate true when totalCount > 0
- copyWith preserves omitted values
- copyWith updates each count
- equality / hashCode / toString
```

Service tests:

```txt id="zy2w2s"
- empty plan calls nothing and returns zero counts
- layer tile keys are sent to sink
- frame composite keys are sent to sink
- playback preview keys are sent to sink
- all key types can be executed together
- result counts match executed key counts
- execution order is deterministic enough for each collection
- does not mutate CacheInvalidationPlan
- does not implement real cache storage
- does not touch BitmapSurface
- does not execute undo/redo
- does not add UI/state management/timeline/storyboard changes
```

Use a fake sink in tests:

```dart id="kggoaa"
class FakeCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

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

```txt id="m5muuu"
docs/Phase_155_Codex_Task.md
docs/Phase_168_Codex_Task.md
docs/Phase_180_Codex_Task.md
lib/src/models/cache_invalidation_plan.dart
lib/src/models/layer_tile_cache_key.dart
lib/src/models/frame_composite_cache_key.dart
lib/src/models/playback_preview_cache_key.dart
lib/src/models/brush_edit_session_commit_result.dart
lib/src/services/brush_edit_session_commit.dart
```

## Out of scope

Do not add:

```txt id="r6fx41"
Canvas UI
Pointer input
Cache storage
Cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
Provider / Riverpod / Bloc / ChangeNotifier
Save / load
Timeline changes
Storyboard changes
```

## Required checks

Run:

```bash id="e8kc6d"
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

```txt id="tiefdz"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```

## Report back

Report:

```txt id="mks87a"
- changed files
- CacheInvalidationExecutionResult behavior
- CacheInvalidationSink behavior
- executeCacheInvalidationPlan behavior
- empty plan behavior
- count behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
