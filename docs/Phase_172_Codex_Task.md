# Phase 172 Codex Task

## Title

Create BrushCommitResult BitmapSurface revert service

## Repository

```txt id="wrtf7p"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="untmye"
master
```

## Project type

```txt id="r0ju1q"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 171.

Recent bitmap canvas / brush foundation phases:

```txt id="qbvcv4"
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
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult -> BitmapSurface applyAfter service
```

## Existing brush commit pieces

The current pipeline has:

```txt id="8dcbmr"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushCommitResult
```

A `BrushCommitResult` contains:

```txt id="wivx4o"
TileDeltaCommand? command
CacheInvalidationPlan cacheInvalidationPlan
```

Phase 171 added forward application:

```txt id="47lpwv"
BrushCommitResult + BitmapSurface
-> applyBrushCommitResultToBitmapSurface(...)
-> BitmapSurface
```

That service uses:

```txt id="8xmfw9"
result.command == null
  -> return surface

result.command != null
  -> result.command!.applyAfter(surface)
```

Phase 172 should add the reverse side:

```txt id="hgrmxy"
BrushCommitResult + BitmapSurface
-> revertBrushCommitResultOnBitmapSurface(...)
-> BitmapSurface
```

using:

```txt id="n6m7g9"
result.command!.applyBefore(surface)
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="eothvu"
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
17. BrushCommitResult -> BitmapSurface apply service
18. BrushCommitResult -> BitmapSurface revert service
19. Canvas state integration
20. Undo/cache/playback integration
21. Save/load/export
```

Current local roadmap:

```txt id="ka62iw"
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult -> BitmapSurface applyAfter service
Phase 172: BrushCommitResult -> BitmapSurface applyBefore/revert service
Phase 173: Forward/reverse round-trip helper or CanvasEditPreview draft
```

Phase 172 is service-only.

It must not build a brush commit.

It must not generate deltas.

It must not generate cache invalidation plans.

It must not execute actual cache invalidation.

It must not add UndoService or an undo stack.

It must not add canvas UI.

## What structure this phase should create

Future undo will eventually flow like this:

```txt id="nv8vki"
currentSurface
-> apply BrushCommitResult
-> updatedSurface

updatedSurface
-> revert BrushCommitResult
-> previousSurface
```

This phase only creates:

```txt id="xiogna"
BrushCommitResult + BitmapSurface -> BitmapSurface
```

for the reverse direction.

Meaning:

```txt id="og2abu"
revertBrushCommitResultOnBitmapSurface
= takes an existing BitmapSurface
= takes a BrushCommitResult
= if result is no-op, returns the original surface
= if result has a command, returns result.command!.applyBefore(surface)
```

This is not an undo stack.

This is not HistoryService.

This is not mutable state management.

This is not UI.

This is not cache execution.

## Required references

Before editing, read:

```txt id="c6tlnf"
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
docs/Phase_170_Codex_Task.md
docs/Phase_171_Codex_Task.md
```

Also inspect:

```txt id="hb4el5"
lib/src/models/brush_commit_result.dart
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/tile_delta_command.dart
lib/src/models/tile_delta.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/models/tile_coord.dart
lib/src/services/brush_commit_result_apply.dart
test/models/brush_commit_result_test.dart
test/models/tile_delta_command_test.dart
test/models/bitmap_surface_test.dart
test/services/brush_commit_result_apply_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure revert service:

```dart id="j8sz2b"
BitmapSurface revertBrushCommitResultOnBitmapSurface({
  required BitmapSurface surface,
  required BrushCommitResult result,
})
```

## Required production file

Create:

```txt id="u7h8en"
lib/src/services/brush_commit_result_revert.dart
```

## Required behavior

The function should:

```txt id="4qfv8n"
1. If result.command == null:
   return surface

2. If result.command != null:
   return result.command!.applyBefore(surface)
```

Use `result.command` as the source of truth.

Do not inspect `result.cacheInvalidationPlan` for revert behavior.

Do not use cache invalidation plan to decide surface revert behavior.

## No-op behavior

If result is no-op:

```txt id="689e64"
result.command == null
```

Expected:

```txt id="hkh4qy"
revertBrushCommitResultOnBitmapSurface(
  surface: surface,
  result: BrushCommitResult.noOp(),
) == surface
```

Prefer returning the same instance when no-op:

```dart id="3nmuvy"
if (result.command == null) return surface;
```

## Changed behavior

If result has changes:

```txt id="kx9e8l"
result.command != null
```

Expected:

```txt id="m23e6v"
previousSurface == result.command!.applyBefore(surface)
```

The service should not manually call `surface.putTile`.

The service should not manually call `surface.removeTile`.

The service should not manually apply tile deltas.

The service should not manually inspect `TileDelta` objects.

## Error behavior

If `result.command!.applyBefore(surface)` throws:

```txt id="wpu1cx"
let the error propagate
```

Do not hide errors.

Reason:

```txt id="p7lpbg"
TileDeltaCommand already owns validation for reverting a command on a surface.
This service should not duplicate or weaken that behavior.
```

## Required tests

Create:

```txt id="v4juaz"
test/services/brush_commit_result_revert_test.dart
```

Required tests:

```txt id="938yi2"
returns original surface for noOp result
returns same surface instance for noOp result
reverts creation delta by removing created tile
reverts replacement delta to previous tile
reverts multi-tile command
result equals command.applyBefore(surface)
forward apply then revert restores original surface
does not mutate current BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushCommitResult
does not mutate TileDeltaCommand
does not inspect or depend on CacheInvalidationPlan contents
propagates applyBefore errors
does not execute cache invalidation
does not add undo stack behavior
```

## Suggested helpers

Suggested IDs:

```dart id="2zcc7f"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="qsm4r7"
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

```dart id="qnxn70"
BitmapTile tile({
  required int tileX,
  required int tileY,
  int size = 2,
  int firstByte = 0,
}) {
  return BitmapTile(
    coord: TileCoord(x: tileX, y: tileY),
    size: size,
    pixels: Uint8List(size * size * BitmapTile.bytesPerPixel)..[0] = firstByte,
  );
}
```

Suggested command helper:

```dart id="8z0xzf"
TileDeltaCommand commandForCreatedTiles(List<BitmapTile> tiles) {
  return TileDeltaCommand(
    deltas: tiles.map(TileDelta.created),
  );
}
```

Suggested plan helper:

```dart id="hnrxhf"
CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
  return CacheInvalidationPlan.fromTileDeltaCommand(
    layerId: layerId,
    frameId: frameId,
    command: command,
  );
}
```

Suggested result helper:

```dart id="m1mlos"
BrushCommitResult resultForCommand(TileDeltaCommand command) {
  return BrushCommitResult.changed(
    command: command,
    cacheInvalidationPlan: planForCommand(command),
  );
}
```

## Suggested examples

### No-op result

```txt id="ucd4x3"
surface = BitmapSurface(...)
result = BrushCommitResult.noOp()

expected:
revertBrushCommitResultOnBitmapSurface(surface: surface, result: result)
returns surface
```

### Revert creation delta

```txt id="m9wp0q"
before surface has no tile at TileCoord(0,0)
after surface has created tile at TileCoord(0,0)
command = TileDeltaCommand([TileDelta.created(tile(0,0))])
result = BrushCommitResult.changed(command, plan)

expected:
revertedSurface.tileAt(TileCoord(0,0)) == null
```

### Revert replacement delta

```txt id="glal2o"
before surface has beforeTile at TileCoord(0,0)
after surface has afterTile at TileCoord(0,0)
command = TileDeltaCommand([
  TileDelta.replaced(before: beforeTile, after: afterTile)
])

expected:
revertedSurface.tileAt(TileCoord(0,0)) == beforeTile
```

### Multi-tile command

```txt id="fqn0tm"
command has deltas for:
TileCoord(0,0)
TileCoord(1,0)

expected:
revertedSurface restores/removes both tiles according to command.before state
```

### Forward then revert

```txt id="98xk01"
afterSurface = command.applyAfter(originalSurface)
revertedSurface = revertBrushCommitResultOnBitmapSurface(
  surface: afterSurface,
  result: result,
)

expected:
revertedSurface == originalSurface
```

### Manual equivalence

```txt id="pxeldy"
actual = revertBrushCommitResultOnBitmapSurface(surface, result)
expected = result.command!.applyBefore(surface)

expect(actual, expected)
```

## Architecture rules

Brush commit result revert rules:

```txt id="of2o7e"
brush_commit_result_revert.dart may know about BrushCommitResult.
brush_commit_result_revert.dart may know about BitmapSurface.
brush_commit_result_revert.dart may call result.command!.applyBefore(surface).
brush_commit_result_revert.dart must not manually create TileDeltaCommand.
brush_commit_result_revert.dart must not manually apply TileDelta objects.
brush_commit_result_revert.dart must not call surface.putTile directly.
brush_commit_result_revert.dart must not call surface.removeTile directly.
brush_commit_result_revert.dart must not mutate BitmapSurface.
brush_commit_result_revert.dart must not execute cache invalidation.
brush_commit_result_revert.dart must not inspect LayerTileCacheKey.
brush_commit_result_revert.dart must not inspect FrameCompositeCacheKey.
brush_commit_result_revert.dart must not inspect PlaybackPreviewCacheKey.
brush_commit_result_revert.dart must not implement UndoService.
brush_commit_result_revert.dart must not add undo stack behavior.
brush_commit_result_revert.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="x9y8gv"
TileDeltaCommand describes changed tiles.
TileDeltaCommand.applyBefore owns immutable surface revert.
CacheInvalidationPlan describes stale cache keys.
BrushCommitResult bundles command and cache plan.
Brush commit result revert service only reverts the command on a surface.
Actual cache eviction/recomputation is not performed by this service.
Undo stack is not performed by this service.
```

Timeline/storyboard boundary:

```txt id="vbubjs"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="ni5fvx"
UndoService
UndoStack
RedoStack
HistoryService
actual cache storage
cache eviction
cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
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

```txt id="dshni9"
lib/src/services/brush_commit_result_revert.dart
test/services/brush_commit_result_revert_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="ohsrz9"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="3lgf50"
- changed files
- revertBrushCommitResultOnBitmapSurface behavior
- no-op behavior
- changed behavior
- command.applyBefore reuse confirmation
- forward-then-revert round-trip behavior
- original/current surface immutability behavior
- existing tile immutability behavior
- error propagation behavior
- confirmation that no UndoService/undo stack was added
- confirmation that no manual TileDelta application was added
- confirmation that no direct surface.putTile/removeTile usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 172 is complete when:

```txt id="rspn9q"
- brush_commit_result_revert.dart exists and is tested.
- revertBrushCommitResultOnBitmapSurface returns original surface for noOp result.
- noOp result returns the same surface instance.
- creation delta is reverted by removing created tile.
- replacement delta is reverted to previous tile.
- multi-tile command is reverted correctly.
- result equals result.command!.applyBefore(surface) for changed result.
- forward apply then revert restores original surface.
- current BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- BrushCommitResult is not mutated.
- TileDeltaCommand is not mutated.
- applyBefore errors are propagated.
- CacheInvalidationPlan is not executed.
- No UndoService / undo stack behavior is added.
- Existing brush commit result apply tests still pass.
- Existing BrushCommitResult tests still pass.
- Existing brush commit builder tests still pass.
- Existing brush commit cache invalidation tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing CacheInvalidationPlan tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BitmapTile operation delta tests still pass.
- Existing one-tile brush commit tests still pass.
- Existing bitmap / dirty region / brush tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No manual TileDelta application was added.
- No direct surface.putTile/removeTile usage was added.
- No cache execution behavior was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="z3v8j2"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
