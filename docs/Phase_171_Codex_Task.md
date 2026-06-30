# Phase 171 Codex Task

## Title

Create BrushCommitResult BitmapSurface apply service

## Repository

```txt id="iu39t1"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="f3k99j"
master
```

## Project type

```txt id="pjjol1"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 170.

Recent bitmap canvas / brush foundation phases:

```txt id="lexd8d"
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
```

## Existing brush commit pieces

The current pipeline has these pieces:

```txt id="rdnuxh"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> brushCommitResultForBrushDabSequenceOnBitmapSurface(...)
-> BrushCommitResult
```

A `BrushCommitResult` contains:

```txt id="okzusz"
TileDeltaCommand? command
CacheInvalidationPlan cacheInvalidationPlan
```

`TileDeltaCommand` already owns immutable surface application:

```txt id="w7f4du"
command.applyAfter(surface)
command.applyBefore(surface)
```

Phase 171 should add a thin service that applies a `BrushCommitResult` to a `BitmapSurface` by reusing `TileDeltaCommand.applyAfter`.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="4h8lzk"
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
18. Canvas UI integration
19. Undo/cache/playback integration
20. Save/load/export
```

Current local roadmap:

```txt id="722wtb"
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
Phase 169: BrushCommitResult model
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult -> BitmapSurface apply service
Phase 172: BrushCommitResult reverse/applyBefore helper or canvas state integration draft
```

Phase 171 is service-only.

It must not build a brush commit.

It must not generate deltas.

It must not generate cache invalidation plans.

It must not execute actual cache invalidation.

It must not add undo/cache stack behavior.

It must not add canvas UI.

## What structure this phase should create

Future brush commit will eventually flow like this:

```txt id="j5x11v"
BrushDabSequence + current BitmapSurface + LayerId + FrameId
-> BrushCommitResult
-> apply BrushCommitResult to current BitmapSurface
-> update current surface reference
-> future cache invalidation execution
-> future undo stack push
```

This phase only creates:

```txt id="ylua9m"
BrushCommitResult + BitmapSurface -> BitmapSurface
```

Meaning:

```txt id="0y5izo"
applyBrushCommitResultToBitmapSurface
= takes an existing BitmapSurface
= takes a BrushCommitResult
= if result is no-op, returns the original surface
= if result has a command, returns result.command!.applyAfter(surface)
```

This is not mutable state management.

This is not UI.

This is not undo.

This is not cache execution.

## Required references

Before editing, read:

```txt id="gxqov5"
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
```

Also inspect:

```txt id="vtze6p"
lib/src/models/brush_commit_result.dart
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/tile_delta_command.dart
lib/src/models/tile_delta.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/models/tile_coord.dart
lib/src/services/brush_commit_builder.dart
test/models/brush_commit_result_test.dart
test/models/tile_delta_command_test.dart
test/models/bitmap_surface_test.dart
test/services/brush_commit_builder_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure apply service:

```dart id="m8b20r"
BitmapSurface applyBrushCommitResultToBitmapSurface({
  required BitmapSurface surface,
  required BrushCommitResult result,
})
```

## Required production file

Create:

```txt id="fbz5s9"
lib/src/services/brush_commit_result_apply.dart
```

## Required behavior

The function should:

```txt id="24u4cx"
1. If result.command == null:
   return surface

2. If result.command != null:
   return result.command!.applyAfter(surface)
```

Use `result.command` as the source of truth.

Do not inspect `result.cacheInvalidationPlan` for application.

Do not use cache invalidation plan to decide surface application.

## No-op behavior

If result is no-op:

```txt id="k4w7aw"
result.command == null
```

Expected:

```txt id="l9mxmh"
applyBrushCommitResultToBitmapSurface(
  surface: surface,
  result: BrushCommitResult.noOp(),
) == surface
```

Prefer returning the same instance when no-op:

```dart id="0yz48a"
if (result.command == null) return surface;
```

## Changed behavior

If result has changes:

```txt id="xqnz7g"
result.command != null
```

Expected:

```txt id="doqo6q"
updatedSurface == result.command!.applyAfter(surface)
```

The service should not manually call `surface.putTile`.

The service should not manually apply tile deltas.

The service should not manually inspect `TileDelta` objects.

## Error behavior

If `result.command!.applyAfter(surface)` throws:

```txt id="6cjwmb"
let the error propagate
```

Do not hide errors.

Reason:

```txt id="t5xndn"
TileDeltaCommand already owns validation for applying a command to a surface.
This service should not duplicate or weaken that behavior.
```

## Required tests

Create:

```txt id="fd0qru"
test/services/brush_commit_result_apply_test.dart
```

Required tests:

```txt id="7r3jzf"
returns original surface for noOp result
returns same surface instance for noOp result
applies creation delta to missing tile
applies replacement delta to existing tile
applies multi-tile command
result equals command.applyAfter(surface)
does not mutate original BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushCommitResult
does not mutate TileDeltaCommand
does not inspect or depend on CacheInvalidationPlan contents
propagates applyAfter errors
does not execute cache invalidation
```

## Suggested helpers

Suggested IDs:

```dart id="d73va8"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="uudhse"
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

```dart id="yu69m9"
BitmapTile blankTile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested command helper:

```dart id="l712hq"
TileDeltaCommand commandForCreatedTiles(List<BitmapTile> tiles) {
  return TileDeltaCommand(
    deltas: tiles.map(TileDelta.created),
  );
}
```

Suggested plan helper:

```dart id="evuhsj"
CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
  return CacheInvalidationPlan.fromTileDeltaCommand(
    layerId: layerId,
    frameId: frameId,
    command: command,
  );
}
```

Suggested result helper:

```dart id="pg7hzg"
BrushCommitResult resultForCommand(TileDeltaCommand command) {
  return BrushCommitResult.changed(
    command: command,
    cacheInvalidationPlan: planForCommand(command),
  );
}
```

## Suggested examples

### No-op result

```txt id="8s9fdn"
surface = BitmapSurface(...)
result = BrushCommitResult.noOp()

expected:
applyBrushCommitResultToBitmapSurface(surface: surface, result: result)
returns surface
```

### Creation delta

```txt id="e44fwl"
surface has no tile at TileCoord(0,0)
command = TileDeltaCommand([TileDelta.created(tile(0,0))])
result = BrushCommitResult.changed(command, plan)

expected:
updatedSurface.tileAt(TileCoord(0,0)) == tile(0,0)
originalSurface.tileAt(TileCoord(0,0)) == null
```

### Replacement delta

```txt id="swk46b"
surface has tile before at TileCoord(0,0)
command = TileDeltaCommand([
  TileDelta.replaced(before: beforeTile, after: afterTile)
])

expected:
updatedSurface.tileAt(TileCoord(0,0)) == afterTile
originalSurface.tileAt(TileCoord(0,0)) == beforeTile
```

### Multi-tile command

```txt id="atw5s5"
command has deltas for:
TileCoord(0,0)
TileCoord(1,0)

expected:
updatedSurface contains both updated tiles
```

### Manual equivalence

```txt id="8ugtk4"
actual = applyBrushCommitResultToBitmapSurface(surface, result)
expected = result.command!.applyAfter(surface)

expect(actual, expected)
```

## Architecture rules

Brush commit result apply rules:

```txt id="363trh"
brush_commit_result_apply.dart may know about BrushCommitResult.
brush_commit_result_apply.dart may know about BitmapSurface.
brush_commit_result_apply.dart may call result.command!.applyAfter(surface).
brush_commit_result_apply.dart must not manually create TileDeltaCommand.
brush_commit_result_apply.dart must not manually apply TileDelta objects.
brush_commit_result_apply.dart must not call surface.putTile directly.
brush_commit_result_apply.dart must not call surface.removeTile directly.
brush_commit_result_apply.dart must not mutate BitmapSurface.
brush_commit_result_apply.dart must not execute cache invalidation.
brush_commit_result_apply.dart must not inspect LayerTileCacheKey.
brush_commit_result_apply.dart must not inspect FrameCompositeCacheKey.
brush_commit_result_apply.dart must not inspect PlaybackPreviewCacheKey.
brush_commit_result_apply.dart must not implement undo.
brush_commit_result_apply.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="9do6kz"
TileDeltaCommand describes changed tiles.
TileDeltaCommand.applyAfter owns immutable surface application.
CacheInvalidationPlan describes stale cache keys.
BrushCommitResult bundles command and cache plan.
Brush commit result apply service only applies the command to a surface.
Actual cache eviction/recomputation is not performed by this service.
Undo stack is not performed by this service.
```

Timeline/storyboard boundary:

```txt id="1a7mgq"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="x9ke5q"
BrushCommitResult reverse/applyBefore service
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

```txt id="kpmrhc"
lib/src/services/brush_commit_result_apply.dart
test/services/brush_commit_result_apply_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="7m1v0i"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="o44dg3"
- changed files
- applyBrushCommitResultToBitmapSurface behavior
- no-op behavior
- changed behavior
- command.applyAfter reuse confirmation
- original surface immutability behavior
- existing tile immutability behavior
- error propagation behavior
- confirmation that no reverse/applyBefore service was added
- confirmation that no manual TileDelta application was added
- confirmation that no direct surface.putTile/removeTile usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 171 is complete when:

```txt id="ehsn80"
- brush_commit_result_apply.dart exists and is tested.
- applyBrushCommitResultToBitmapSurface returns original surface for noOp result.
- noOp result returns the same surface instance.
- creation delta is applied to missing tile.
- replacement delta is applied to existing tile.
- multi-tile command is applied correctly.
- result equals result.command!.applyAfter(surface) for changed result.
- original BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- BrushCommitResult is not mutated.
- TileDeltaCommand is not mutated.
- applyAfter errors are propagated.
- CacheInvalidationPlan is not executed.
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
- No reverse/applyBefore service was added.
- No manual TileDelta application was added.
- No direct surface.putTile/removeTile usage was added.
- No cache execution behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="sa8opx"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
