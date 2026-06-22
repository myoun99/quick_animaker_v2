# Phase 168 Codex Task

## Title

Create brush commit cache invalidation plan service

## Repository

```txt id="l7xf1r"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="p1mfot"
master
```

## Project type

```txt id="eq3z3s"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 167.

Recent bitmap canvas / brush foundation phases:

```txt id="00iaxf"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
Phase 158: BrushDab.color snapshot / RgbaColor foundation
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab pixel coverage foundation
Phase 161: BrushDab pixel blend foundation
Phase 162: BrushDabSequence pixel blend operation foundation
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: Apply BrushPixelBlendOperation list to BitmapTile
Phase 165: BitmapTile operation list -> TileDeltaCommand?
Phase 166: BrushDabSequence + one BitmapTile -> TileDeltaCommand?
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
```

## Existing cache invalidation model facts

`CacheInvalidationPlan` already exists.

It stores three groups:

```txt id="9xv9fa"
layerTiles
frameComposites
playbackPreviews
```

Existing factory:

```dart id="wiapqx"
CacheInvalidationPlan.fromTileDeltaCommand({
  required LayerId layerId,
  required FrameId frameId,
  required TileDeltaCommand command,
})
```

Current behavior:

```txt id="8g7a9n"
TileDeltaCommand.dirtyTiles
-> LayerTileCacheKey(layerId, frameId, tileCoord)
```

It currently only creates `LayerTileCacheKey` entries.

That is correct for the current phase.

Do not add frame composite invalidation yet.

Do not add playback preview invalidation yet.

Reason:

```txt id="6ac03c"
FrameCompositeCacheKey and PlaybackPreviewCacheKey need CutId/frameIndex/preview size context.
The current brush commit pipeline has LayerId and FrameId context only.
Adding those broader invalidations should be a later phase with explicit context.
```

## Existing brush commit pipeline

The following pieces already exist:

```txt id="2w9rvm"
BrushDabSequence + BitmapSurface
-> tileDeltaCommandForBrushDabSequenceOnBitmapSurface(...)
-> TileDeltaCommand?
```

The next step should be:

```txt id="17m30l"
TileDeltaCommand? + LayerId + FrameId
-> CacheInvalidationPlan
```

This phase should not apply the command.

This phase should not invalidate actual cache storage.

This phase should only build a plan object.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="o8luqh"
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA color and source-over blend math foundation
6. BrushDab pixel coverage foundation
7. BrushDab pixel blend foundation
8. BrushDabSequence pixel operation foundation
9. BitmapTile read/write helper foundation
10. BrushPixelBlendOperation list -> BitmapTile updated copy
11. BitmapTile before/after -> TileDeltaCommand connection
12. BrushDabSequence + one BitmapTile -> TileDeltaCommand?
13. BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
14. TileDeltaCommand? -> CacheInvalidationPlan
15. Canvas UI integration
16. Undo/cache/playback integration
17. Save/load/export
```

Current local roadmap:

```txt id="w5zku4"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: BrushPixelBlendOperation list -> BitmapTile updated copy
Phase 165: BitmapTile + BrushPixelBlendOperation list -> TileDeltaCommand?
Phase 166: BrushDabSequence + one BitmapTile -> TileDeltaCommand?
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
Phase 169: BrushCommitResult model draft
```

Phase 168 is a cache invalidation planning connector.

It must remain pure and deterministic.

It must not mutate cache.

It must not apply TileDeltaCommand.

It must not add canvas UI.

It must not add undo/cache execution.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="y4vwxh"
BrushDabSequence + BitmapSurface
-> TileDeltaCommand?
-> CacheInvalidationPlan
-> BrushCommitResult
-> future surface apply
-> future cache invalidation
-> future undo stack
```

This phase only creates:

```txt id="xxfcdk"
TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
```

Meaning:

```txt id="pn27il"
cacheInvalidationPlanForTileDeltaCommand
= takes nullable TileDeltaCommand
= takes LayerId and FrameId
= returns CacheInvalidationPlan.empty() when command is null
= otherwise uses CacheInvalidationPlan.fromTileDeltaCommand
```

This is not actual cache invalidation.

This is not frame composite invalidation.

This is not playback preview invalidation.

This is not undo integration.

## Required references

Before editing, read:

```txt id="t4l3fn"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
docs/Phase_154_Codex_Task.md
docs/Phase_155_Codex_Task.md
docs/Phase_156_Codex_Task.md
docs/Phase_157_Codex_Task.md
docs/Phase_158_Codex_Task.md
docs/Phase_159_Codex_Task.md
docs/Phase_160_Codex_Task.md
docs/Phase_161_Codex_Task.md
docs/Phase_162_Codex_Task.md
docs/Phase_163_Codex_Task.md
docs/Phase_164_Codex_Task.md
docs/Phase_165_Codex_Task.md
docs/Phase_166_Codex_Task.md
docs/Phase_167_Codex_Task.md
```

Also inspect:

```txt id="ja7jjs"
lib/src/models/cache_invalidation_plan.dart
lib/src/models/layer_tile_cache_key.dart
lib/src/models/frame_composite_cache_key.dart
lib/src/models/playback_preview_cache_key.dart
lib/src/models/tile_delta_command.dart
lib/src/models/tile_delta.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/tile_coord.dart
test/models/cache_invalidation_plan_test.dart
test/models/layer_tile_cache_key_test.dart
test/models/tile_delta_command_test.dart
test/services/bitmap_surface_brush_commit_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure cache invalidation plan service:

```dart id="6p7zr5"
CacheInvalidationPlan cacheInvalidationPlanForTileDeltaCommand({
  required LayerId layerId,
  required FrameId frameId,
  required TileDeltaCommand? command,
})
```

The goal is to prepare for future brush commit result while keeping this phase plan-only and testable.

## Strong scope rule

Allowed:

```txt id="04illh"
pure Dart service
TileDeltaCommand? -> CacheInvalidationPlan
nullable command handling
LayerTileCacheKey invalidation through existing CacheInvalidationPlan factory
focused service tests
```

Not allowed:

```txt id="cxhe94"
actual cache storage
cache eviction
cache recomputation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
BitmapSurface mutation
TileDeltaCommand applyAfter/applyBefore usage
UndoService
undo stack
canvas UI
renderer
playback
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Required production file

Create:

```txt id="k0als3"
lib/src/services/brush_commit_cache_invalidation.dart
```

Required public function:

```dart id="q5wzxh"
CacheInvalidationPlan cacheInvalidationPlanForTileDeltaCommand({
  required LayerId layerId,
  required FrameId frameId,
  required TileDeltaCommand? command,
})
```

## Required behavior

The function should:

```txt id="pm3tbw"
1. If command == null:
   return CacheInvalidationPlan.empty()

2. If command != null:
   return CacheInvalidationPlan.fromTileDeltaCommand(
     layerId: layerId,
     frameId: frameId,
     command: command,
   )
```

Important:

```txt id="qnz4ua"
Do not manually create LayerTileCacheKey items if the existing factory can be used.
Do not generate FrameCompositeCacheKey items.
Do not generate PlaybackPreviewCacheKey items.
Do not merge extra invalidation keys.
Do not apply the TileDeltaCommand to a surface.
```

Reason:

```txt id="s4kztl"
CacheInvalidationPlan.fromTileDeltaCommand already owns the dirty tile -> layer tile cache key conversion.
Phase 168 should only make nullable command handling explicit and reusable.
```

## No-op behavior

If the command is null:

```txt id="id2fpj"
return CacheInvalidationPlan.empty()
```

Expected:

```txt id="bpu32o"
plan.isEmpty == true
plan.totalKeyCount == 0
plan.layerTiles.isEmpty == true
plan.frameComposites.isEmpty == true
plan.playbackPreviews.isEmpty == true
```

## Non-null behavior

If the command contains dirty tiles:

```txt id="ijgv05"
plan.layerTiles should contain one LayerTileCacheKey per dirty tile.
plan.frameComposites should be empty.
plan.playbackPreviews should be empty.
```

Each layer tile key should use:

```txt id="yyrsgv"
the provided LayerId
the provided FrameId
the TileCoord from command.dirtyTiles
```

## Determinism

`CacheInvalidationPlan` already uses sets and sorted JSON internally.

No additional ordering behavior is required.

## Required tests

Create:

```txt id="8o9gsh"
test/services/brush_commit_cache_invalidation_test.dart
```

Required tests:

```txt id="ilezge"
returns empty plan for null command
null command plan has no layerTiles
null command plan has no frameComposites
null command plan has no playbackPreviews
returns layer tile invalidation for one-delta command
returns one layer tile key per dirty tile
uses provided LayerId
uses provided FrameId
uses dirty TileCoord from command
does not add frame composite keys
does not add playback preview keys
does not mutate command
matches CacheInvalidationPlan.fromTileDeltaCommand for non-null command
```

## Suggested helpers

Suggested IDs:

```dart id="aipj8t"
final layerId = LayerId('layer-1');
final frameId = FrameId('frame-1');
```

If IDs require factory methods in this codebase, follow existing tests.

Suggested tile helper:

```dart id="436eyg"
BitmapTile blankTile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested command helper:

```dart id="9sob3k"
TileDeltaCommand commandForTiles(List<BitmapTile> afterTiles) {
  return TileDeltaCommand(
    deltas: afterTiles.map(TileDelta.created),
  );
}
```

Or use replaced deltas if that matches existing tests better.

## Suggested examples

### Null command

```txt id="0vadsv"
command = null

expected:
CacheInvalidationPlan.empty()
```

### One dirty tile

```txt id="9oxcqj"
command dirtyTiles = [TileCoord(x: 1, y: 2)]
layerId = LayerId('layer-1')
frameId = FrameId('frame-1')

expected:
plan.layerTiles contains:
LayerTileCacheKey(
  layerId: layerId,
  frameId: frameId,
  tileCoord: TileCoord(x: 1, y: 2),
)

plan.frameComposites is empty
plan.playbackPreviews is empty
```

### Multiple dirty tiles

```txt id="pktcn0"
command dirtyTiles = [
  TileCoord(x: 0, y: 0),
  TileCoord(x: 1, y: 0),
  TileCoord(x: 0, y: 1),
]

expected:
plan.layerTiles.length == 3
```

## Architecture rules

Brush commit cache invalidation rules:

```txt id="9i64yg"
brush_commit_cache_invalidation.dart may know about CacheInvalidationPlan.
brush_commit_cache_invalidation.dart may know about TileDeltaCommand.
brush_commit_cache_invalidation.dart may know about LayerId.
brush_commit_cache_invalidation.dart may know about FrameId.
brush_commit_cache_invalidation.dart may call CacheInvalidationPlan.empty.
brush_commit_cache_invalidation.dart may call CacheInvalidationPlan.fromTileDeltaCommand.
brush_commit_cache_invalidation.dart must not manually walk command.dirtyTiles unless tests require validation elsewhere.
brush_commit_cache_invalidation.dart must not create FrameCompositeCacheKey.
brush_commit_cache_invalidation.dart must not create PlaybackPreviewCacheKey.
brush_commit_cache_invalidation.dart must not mutate any cache.
brush_commit_cache_invalidation.dart must not apply TileDeltaCommand to BitmapSurface.
brush_commit_cache_invalidation.dart must not implement undo.
brush_commit_cache_invalidation.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="jsqf3r"
TileDeltaCommand describes changed tiles.
CacheInvalidationPlan describes which cache keys become stale.
LayerTileCacheKey invalidates per-layer, per-frame, per-tile cache.
FrameCompositeCacheKey invalidation is not added in this phase.
PlaybackPreviewCacheKey invalidation is not added in this phase.
Actual cache storage is not implemented in this phase.
```

Timeline/storyboard boundary:

```txt id="7o70s7"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="bxxb8s"
actual cache storage
cache eviction
cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
BitmapSurface mutation
TileDeltaCommand applyAfter/applyBefore usage
BrushCommitResult
UndoService
UndoStack
RedoStack
HistoryService
actual canvas UI
drawing canvas
pointer event handling
tablet input
gesture detector
zoom/pan UI integration
renderer
playback implementation
save/load
persistence service
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
export
Photoshop-style / ABR brush import
timeline changes
storyboard changes
```

## Expected changed files

Likely:

```txt id="96j74k"
lib/src/services/brush_commit_cache_invalidation.dart
test/services/brush_commit_cache_invalidation_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="k2h97x"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="9g1dx8"
- changed files
- cacheInvalidationPlanForTileDeltaCommand behavior
- null command behavior
- non-null command behavior
- LayerTileCacheKey generation behavior
- confirmation that CacheInvalidationPlan.fromTileDeltaCommand is reused
- confirmation that no FrameCompositeCacheKey generation was added
- confirmation that no PlaybackPreviewCacheKey generation was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no TileDeltaCommand applyAfter/applyBefore usage was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 168 is complete when:

```txt id="0fw5h8"
- brush_commit_cache_invalidation.dart exists and is tested.
- cacheInvalidationPlanForTileDeltaCommand returns empty plan for null command.
- Empty plan has no layer tile keys.
- Empty plan has no frame composite keys.
- Empty plan has no playback preview keys.
- Non-null command returns one layer tile key per dirty tile.
- Layer tile keys use the provided LayerId.
- Layer tile keys use the provided FrameId.
- Layer tile keys use command dirty TileCoord values.
- Non-null behavior matches CacheInvalidationPlan.fromTileDeltaCommand.
- FrameCompositeCacheKey generation is not added.
- PlaybackPreviewCacheKey generation is not added.
- Actual cache storage is not added.
- Existing CacheInvalidationPlan tests still pass.
- Existing LayerTileCacheKey tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing one-tile brush commit tests still pass.
- Existing BitmapTile operation delta tests still pass.
- Existing BitmapTile operation apply tests still pass.
- Existing BitmapTile RGBA helper tests still pass.
- Existing TileDelta tests still pass.
- Existing BrushPixelBlendOperation tests still pass.
- Existing BrushDabSequence blend tests still pass.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BitmapSurface mutation was added.
- No cache execution behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="ra1ywp"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
