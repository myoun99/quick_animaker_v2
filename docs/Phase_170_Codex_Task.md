# Phase 170 Codex Task

## Title

Create BrushCommitResult builder service

## Repository

```txt id="c93tbh"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="gjj6yl"
master
```

## Project type

```txt id="hsltam"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 169.

Recent bitmap canvas / brush foundation phases:

```txt id="fcjnqm"
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
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
Phase 169: BrushCommitResult model
```

## Existing brush commit pieces

The current pipeline has these independent pieces:

```txt id="xt0dau"
BrushDabSequence + BitmapSurface
-> tileDeltaCommandForBrushDabSequenceOnBitmapSurface(...)
-> TileDeltaCommand?
```

```txt id="qfjj2i"
TileDeltaCommand? + LayerId + FrameId
-> cacheInvalidationPlanForTileDeltaCommand(...)
-> CacheInvalidationPlan
```

```txt id="8euo0s"
TileDeltaCommand? + CacheInvalidationPlan
-> BrushCommitResult
```

Phase 170 should connect them into one builder:

```txt id="exmpzp"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushCommitResult
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="cvia7w"
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
15. BrushCommitResult model
16. BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
17. BrushCommitResult apply service
18. Canvas UI integration
19. Undo/cache/playback integration
20. Save/load/export
```

Current local roadmap:

```txt id="vqu6oh"
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
Phase 169: BrushCommitResult model
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult apply service
```

Phase 170 is service-only.

It must not apply a command.

It must not mutate a surface.

It must not invalidate actual caches.

It must not add undo/cache execution.

It must not add canvas UI.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="huqex5"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushCommitResult
-> future surface apply
-> future cache invalidation
-> future undo stack
```

This phase only creates:

```txt id="9ykmkn"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushCommitResult
```

Meaning:

```txt id="wo0p35"
brushCommitResultForBrushDabSequenceOnBitmapSurface
= calls tileDeltaCommandForBrushDabSequenceOnBitmapSurface
= calls cacheInvalidationPlanForTileDeltaCommand
= returns BrushCommitResult.noOp() if command is null
= returns BrushCommitResult.changed(...) if command is non-null
```

This is not actual brush commit execution.

This is not surface mutation.

This is not cache execution.

This is not undo integration.

## Required references

Before editing, read:

```txt id="d6650v"
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
docs/Phase_168_Codex_Task.md
docs/Phase_169_Codex_Task.md
```

Also inspect:

```txt id="t4etqj"
lib/src/models/brush_commit_result.dart
lib/src/models/bitmap_surface.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/tile_delta_command.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/services/bitmap_surface_brush_commit.dart
lib/src/services/brush_commit_cache_invalidation.dart
test/models/brush_commit_result_test.dart
test/services/bitmap_surface_brush_commit_test.dart
test/services/brush_commit_cache_invalidation_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure builder service:

```dart id="82ubhv"
BrushCommitResult brushCommitResultForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

## Required production file

Create:

```txt id="28fegq"
lib/src/services/brush_commit_builder.dart
```

## Required behavior

The function should:

```txt id="0z53fx"
1. Call tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
     surface: surface,
     sequence: sequence,
   )

2. Store the result as TileDeltaCommand? command.

3. Call cacheInvalidationPlanForTileDeltaCommand(
     layerId: layerId,
     frameId: frameId,
     command: command,
   )

4. If command == null:
     return BrushCommitResult.noOp()

5. If command != null:
     return BrushCommitResult.changed(
       command: command,
       cacheInvalidationPlan: cacheInvalidationPlan,
     )
```

Important:

```txt id="g908dr"
Do not manually build TileDeltaCommand.
Do not manually build CacheInvalidationPlan.
Do not manually build LayerTileCacheKey.
Do not manually apply TileDeltaCommand.
Do not mutate BitmapSurface.
```

Reason:

```txt id="wf8lh3"
Phase 167 owns BrushDabSequence + BitmapSurface -> TileDeltaCommand?.
Phase 168 owns TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan.
Phase 169 owns BrushCommitResult.
Phase 170 should only compose these existing pieces.
```

## no-op behavior

If the sequence produces no tile changes:

```txt id="bv9fq0"
tileDeltaCommandForBrushDabSequenceOnBitmapSurface returns null
cacheInvalidationPlanForTileDeltaCommand returns CacheInvalidationPlan.empty()
brushCommitResultForBrushDabSequenceOnBitmapSurface returns BrushCommitResult.noOp()
```

Expected:

```txt id="n5ej7e"
result.command == null
result.cacheInvalidationPlan.isEmpty == true
result.hasChanges == false
result.isNoOp == true
result.changedTileCount == 0
result.dirtyTiles.isEmpty == true
```

## changed behavior

If the sequence changes one or more tiles:

```txt id="gz09j1"
tileDeltaCommandForBrushDabSequenceOnBitmapSurface returns non-null command
cacheInvalidationPlanForTileDeltaCommand returns non-empty plan
brushCommitResultForBrushDabSequenceOnBitmapSurface returns BrushCommitResult.changed(...)
```

Expected:

```txt id="p7xwr1"
result.command != null
result.cacheInvalidationPlan.isNotEmpty == true
result.hasChanges == true
result.isNoOp == false
result.changedTileCount == result.command!.length
result.dirtyTiles == result.command!.dirtyTiles
```

## Required tests

Create:

```txt id="l4e7u3"
test/services/brush_commit_builder_test.dart
```

Required tests:

```txt id="ktxvxb"
returns BrushCommitResult.noOp for empty BrushDabSequence
returns BrushCommitResult.noOp for non-effective dab
returns BrushCommitResult.noOp when dab affects only pixels outside surface

returns changed BrushCommitResult for dab on missing tile
returns changed BrushCommitResult for dab on existing tile
changed result contains TileDeltaCommand
changed result contains non-empty CacheInvalidationPlan
changed result dirtyTiles equals command.dirtyTiles
changed result changedTileCount equals command.length

cache invalidation plan uses provided LayerId
cache invalidation plan uses provided FrameId
cache invalidation plan uses command dirty tile coords

multi-tile dab returns result with multiple changed tiles

result matches manual composition of:
  tileDeltaCommandForBrushDabSequenceOnBitmapSurface
  cacheInvalidationPlanForTileDeltaCommand
  BrushCommitResult.changed/noOp

does not mutate BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushDabSequence
does not mutate BrushDab
```

## Suggested helpers

Suggested IDs:

```dart id="cju9vi"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="w8qki2"
BitmapSurface surface({
  int width = 4,
  int height = 4,
  int tileSize = 2,
  Map<TileCoord, BitmapTile> tiles = const {},
}) {
  return BitmapSurface(
    canvasSize: CanvasSize(width: width, height: height),
    tileSize: tileSize,
    tiles: tiles,
  );
}
```

Suggested tile helper:

```dart id="ibpgn9"
BitmapTile blankTile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested one-pixel dab helper:

```dart id="j1xcbc"
BrushDab onePixelDab({
  required double globalX,
  required double globalY,
  int color = 0xFFFF0000,
  double opacity = 1,
  double flow = 1,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: globalX + 0.5, y: globalY + 0.5),
    color: color,
    size: 1,
    opacity: opacity,
    flow: flow,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: sequence,
  );
}
```

Suggested square dab helper:

```dart id="ah62sz"
BrushDab squareDab({
  required double centerX,
  required double centerY,
  int color = 0xFFFF0000,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: centerX, y: centerY),
    color: color,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: sequence,
  );
}
```

## Suggested examples

### Empty sequence

```txt id="xkex16"
surface = 4x4 canvas, tileSize 2
sequence = BrushDabSequence()

expected:
BrushCommitResult.noOp()
```

### Missing tile draw

```txt id="jsmevb"
surface has no tile at TileCoord(0,0)
dab affects global pixel (0,0)

expected:
result.hasChanges == true
result.command!.deltas.single.isCreation == true
result.cacheInvalidationPlan.layerTiles contains key with:
  layerId
  frameId
  TileCoord(0,0)
```

### Existing tile draw

```txt id="5k7zyv"
surface has existing tile at TileCoord(0,0)
dab affects global pixel (0,0)

expected:
result.hasChanges == true
result.command!.deltas.single.isReplacement == true
```

### Multi-tile draw

```txt id="r7e1ka"
surface = 4x4 canvas, tileSize 2
square dab crosses tile boundary

expected:
result.changedTileCount == 2
result.cacheInvalidationPlan.layerTiles.length == 2
```

### Manual composition equivalence

```txt id="rzm0gk"
command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(...)
plan = cacheInvalidationPlanForTileDeltaCommand(...)
expected = command == null
  ? BrushCommitResult.noOp()
  : BrushCommitResult.changed(command: command, cacheInvalidationPlan: plan)

actual = brushCommitResultForBrushDabSequenceOnBitmapSurface(...)

expect(actual, expected)
```

## Architecture rules

Brush commit builder rules:

```txt id="0d23fn"
brush_commit_builder.dart may know about BrushCommitResult.
brush_commit_builder.dart may know about BitmapSurface.
brush_commit_builder.dart may know about BrushDabSequence.
brush_commit_builder.dart may know about LayerId.
brush_commit_builder.dart may know about FrameId.
brush_commit_builder.dart may call tileDeltaCommandForBrushDabSequenceOnBitmapSurface.
brush_commit_builder.dart may call cacheInvalidationPlanForTileDeltaCommand.
brush_commit_builder.dart may call BrushCommitResult.noOp.
brush_commit_builder.dart may call BrushCommitResult.changed.
brush_commit_builder.dart must not manually create TileDeltaCommand.
brush_commit_builder.dart must not manually create CacheInvalidationPlan.
brush_commit_builder.dart must not manually create LayerTileCacheKey.
brush_commit_builder.dart must not call TileDeltaCommand.applyAfter.
brush_commit_builder.dart must not call TileDeltaCommand.applyBefore.
brush_commit_builder.dart must not mutate BitmapSurface.
brush_commit_builder.dart must not call surface.putTile.
brush_commit_builder.dart must not call surface.removeTile.
brush_commit_builder.dart must not mutate cache.
brush_commit_builder.dart must not implement undo.
brush_commit_builder.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="m5yb5b"
TileDeltaCommand describes changed tiles.
CacheInvalidationPlan describes stale cache keys.
BrushCommitResult bundles both.
Brush commit builder composes existing services.
Actual BitmapSurface mutation is not performed by the builder.
Actual cache eviction/recomputation is not performed by the builder.
Undo stack is not performed by the builder.
```

Timeline/storyboard boundary:

```txt id="ifwnau"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="2vffef"
BrushCommitResult apply service
BitmapSurface mutation
TileDeltaCommand applyAfter/applyBefore usage
actual cache storage
cache eviction
cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
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

```txt id="n2ozu4"
lib/src/services/brush_commit_builder.dart
test/services/brush_commit_builder_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="ikb2xn"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="r0n91w"
- changed files
- brushCommitResultForBrushDabSequenceOnBitmapSurface behavior
- no-op result behavior
- changed result behavior
- TileDeltaCommand generation reuse confirmation
- CacheInvalidationPlan generation reuse confirmation
- BrushCommitResult construction behavior
- LayerId / FrameId cache key behavior
- multi-tile behavior
- immutability behavior
- confirmation that no BrushCommitResult apply service was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no TileDeltaCommand applyAfter/applyBefore usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no FrameCompositeCacheKey generation was added
- confirmation that no PlaybackPreviewCacheKey generation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 170 is complete when:

```txt id="736qfk"
- brush_commit_builder.dart exists and is tested.
- brushCommitResultForBrushDabSequenceOnBitmapSurface returns noOp for empty sequence.
- returns noOp for non-effective dab.
- returns noOp when all affected pixels are outside surface.
- returns changed result for dab on missing tile.
- returns changed result for dab on existing tile.
- changed result contains TileDeltaCommand.
- changed result contains non-empty CacheInvalidationPlan.
- changed result dirtyTiles equals command.dirtyTiles.
- changed result changedTileCount equals command.length.
- cache invalidation plan uses provided LayerId.
- cache invalidation plan uses provided FrameId.
- cache invalidation plan uses command dirty tile coords.
- multi-tile dab returns multiple changed tiles.
- result equals manual composition of existing services.
- original BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- BrushDabSequence is not mutated.
- BrushDab is not mutated.
- Existing BrushCommitResult tests still pass.
- Existing brush commit cache invalidation tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing CacheInvalidationPlan tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BitmapTile operation delta tests still pass.
- Existing one-tile brush commit tests still pass.
- Existing bitmap / dirty region / brush tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BrushCommitResult apply service was added.
- No BitmapSurface mutation was added.
- No cache execution behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="x24j0t"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
