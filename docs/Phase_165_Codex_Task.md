# Phase 165 Codex Task

## Title

Create TileDeltaCommand from BitmapTile brush operations

## Repository

```txt id="awyjre"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="u56ek7"
master
```

## Project type

```txt id="95acfy"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 164.

Recent bitmap canvas / brush foundation phases:

```txt id="06n94w"
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
```

## Existing facts

`TileDelta` already exists.

It supports:

```dart id="5o6kq7"
TileDelta.created(BitmapTile after)
TileDelta.removed(BitmapTile before)
TileDelta.replaced({
  required BitmapTile before,
  required BitmapTile after,
})
```

`TileDelta.replaced` is correct when an existing tile changes from one pixel state to another.

`TileDelta` rejects invalid states:

```txt id="b73xrm"
before == null && after == null
before.coord != coord
after.coord != coord
before.size != after.size
before == after
```

`TileDeltaCommand` already exists.

It requires a non-empty delta list.

It supports:

```txt id="i3g53p"
deltas
dirtyTiles
length
containsCoord
deltaFor
applyBefore
applyAfter
validateAgainstSurface
toJson/fromJson
```

Important:

```txt id="7fd9rv"
TileDeltaCommand cannot represent an empty/no-op change.
```

So Phase 165 should return `null` when no tile change occurs.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="stf5xf"
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
12. BitmapBrushRasterizer
13. Brush stroke commit pipeline
14. Canvas UI integration
15. Undo/cache/playback integration
16. Save/load/export
```

Current local roadmap:

```txt id="en2vws"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: BrushPixelBlendOperation list -> BitmapTile updated copy
Phase 165: BrushPixelBlendOperation list + BitmapTile -> TileDeltaCommand?
Phase 166: Brush stroke commit pipeline draft
```

Phase 165 connects Phase 164 with the existing TileDeltaCommand model.

This phase must remain pure service logic.

This phase must not mutate BitmapSurface, apply the command to a surface, invalidate cache, implement undo, add a rasterizer, add canvas UI, add renderer, add save/load, or modify timeline/storyboard behavior.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="2zq61w"
BrushDabSequence
-> BrushPixelBlendOperation list
-> applyBrushPixelBlendOperationsToBitmapTile(...)
-> updated BitmapTile
-> TileDelta.replaced(before: originalTile, after: updatedTile)
-> TileDeltaCommand
-> future BitmapSurface apply
-> future CacheInvalidationPlan
-> future Undo stack
```

This phase only creates the `BitmapTile + operations -> TileDeltaCommand?` step.

Meaning:

```txt id="kk19fc"
tileDeltaCommandForBitmapTileOperations
= takes one existing BitmapTile
= takes global BrushPixelBlendOperation list
= applies relevant operations to that tile using Phase 164 service
= returns null if the tile is unchanged
= returns TileDeltaCommand with one TileDelta.replaced if the tile changed
```

This is not BitmapSurface mutation.

This is not actual undo.

This is not cache invalidation.

This is not brush rasterization.

## Required references

Before editing, read:

```txt id="lafrz4"
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
```

Also inspect:

```txt id="yzbolx"
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
lib/src/models/brush_pixel_blend_operation.dart
lib/src/services/bitmap_tile_operation_apply.dart
lib/src/services/bitmap_tile_rgba.dart
test/models/tile_delta_test.dart
test/models/tile_delta_command_test.dart
test/services/bitmap_tile_operation_apply_test.dart
test/services/bitmap_tile_rgba_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure TileDeltaCommand creation service:

```dart id="nchsam"
TileDeltaCommand? tileDeltaCommandForBitmapTileOperations({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
})
```

The goal is to prepare for future brush commit and undo/cache wiring while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt id="5vgz4g"
pure Dart service
BitmapTile + BrushPixelBlendOperation list -> TileDeltaCommand?
reuse applyBrushPixelBlendOperationsToBitmapTile
TileDelta.replaced creation
TileDeltaCommand creation
focused service tests
```

Not allowed:

```txt id="k0z9eq"
BitmapBrushRasterizer
BrushDabSequence processing
BrushDab processing
BrushPixelCoverage processing
BitmapSurface mutation
BitmapSurface helper
TileDeltaCommand applyBefore/applyAfter usage
CacheInvalidationPlan generation
actual cache implementation
UndoService
undo stack
canvas UI
pointer event handling
gesture handling
CustomPainter
renderer
playback
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Required production file

Create:

```txt id="ofl9iy"
lib/src/services/bitmap_tile_operation_delta.dart
```

Required public function:

```dart id="3oifir"
TileDeltaCommand? tileDeltaCommandForBitmapTileOperations({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
})
```

## Required behavior

The function should:

```txt id="wdfav0"
1. Call applyBrushPixelBlendOperationsToBitmapTile(tile: tile, operations: operations).
2. If the returned tile equals the original tile, return null.
3. If the returned tile differs from the original tile:
   - create TileDelta.replaced(before: tile, after: updatedTile)
   - create TileDeltaCommand(deltas: [delta])
   - return it
```

Important:

```txt id="4erbgx"
Do not manually re-apply operations in this service.
Do not duplicate Phase 164 global-to-local mapping logic.
Reuse applyBrushPixelBlendOperationsToBitmapTile.
```

Reason:

```txt id="cum8i5"
Phase 164 already owns the tile operation application rules.
Phase 165 should only wrap the resulting before/after tile into TileDeltaCommand.
```

## No-op behavior

If no operations affect the tile, Phase 164 returns the original tile.

Then Phase 165 should return:

```txt id="2ze04d"
null
```

If operations affect the tile but produce no actual change, Phase 164 should also return the original tile or an equal tile.

Then Phase 165 should return:

```txt id="acawpl"
null
```

Reason:

```txt id="riivpl"
TileDeltaCommand cannot be empty.
TileDelta.replaced rejects before == after.
So no-op should be represented by null.
```

## Error behavior

If Phase 164 throws `StateError` because `operation.before` does not match the current tile pixel:

```txt id="xn6me4"
let the StateError propagate
```

Do not catch and hide it.

Reason:

```txt id="5fylog"
A before mismatch indicates the operation list was generated from a different tile state.
Future brush commit should fail early rather than silently corrupt pixels.
```

## Required tests

Create:

```txt id="ph23ik"
test/services/bitmap_tile_operation_delta_test.dart
```

Required tests:

```txt id="lvcj67"
returns null when operations is empty
returns null when no operation affects tile
returns TileDeltaCommand when an operation changes tile
command contains exactly one delta
delta is replacement
delta coord matches tile coord
delta before is original tile
delta after is updated tile
command dirtyTiles contains tile coord
command deltaFor returns the created delta
returned command applyAfter produces updated tile when used on a matching surface if practical
returned command applyBefore restores original tile when used on a matching surface if practical
propagates StateError from before mismatch
does not mutate original tile
preserves updated tile coord
preserves updated tile size
```

Surface apply tests are optional but useful if existing `BitmapSurface` API is easy to use.

If adding surface apply tests, keep them small and use existing model APIs only.

## Suggested helpers

Use:

```dart id="55qisr"
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
```

Suggested tile helper:

```dart id="7v5zo1"
BitmapTile blankTile({
  int tileX = 0,
  int tileY = 0,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested operation helper:

```dart id="oa1nke"
BrushPixelBlendOperation op({
  required int x,
  required int y,
  required RgbaColor before,
  required RgbaColor after,
}) {
  return BrushPixelBlendOperation(
    x: x,
    y: y,
    before: before,
    after: after,
  );
}
```

## Suggested examples

### Empty operations

```txt id="0tz1a1"
tile = blank tile
operations = []

expected:
result == null
```

### Outside-only operations

```txt id="zfrtiz"
tile.coord = TileCoord(x: 0, y: 0)
tile.size = 2
operation.x = 2
operation.y = 0

expected:
result == null
```

### One in-tile operation

```txt id="n8i3yw"
tile.coord = TileCoord(x: 0, y: 0)
tile.size = 2
operation.x = 1
operation.y = 0
before = transparent
after = red

expected:
command != null
command.length == 1
delta.isReplacement == true
delta.before == original tile
delta.after pixel local (1,0) == red
```

### Before mismatch

```txt id="u9vp79"
tile pixel = transparent
operation.before = red
operation.after = blue

expected:
throws StateError
```

## Architecture rules

BitmapTile operation delta rules:

```txt id="0d9x48"
bitmap_tile_operation_delta.dart may know about BitmapTile.
bitmap_tile_operation_delta.dart may know about BrushPixelBlendOperation.
bitmap_tile_operation_delta.dart may know about TileDelta.
bitmap_tile_operation_delta.dart may know about TileDeltaCommand.
bitmap_tile_operation_delta.dart may call applyBrushPixelBlendOperationsToBitmapTile.
bitmap_tile_operation_delta.dart must not know about BrushDab.
bitmap_tile_operation_delta.dart must not know about BrushDabSequence.
bitmap_tile_operation_delta.dart must not know about BrushPixelCoverage.
bitmap_tile_operation_delta.dart must not manually map global coordinates.
bitmap_tile_operation_delta.dart must not manually write pixel bytes.
bitmap_tile_operation_delta.dart must not mutate BitmapSurface.
bitmap_tile_operation_delta.dart must not generate CacheInvalidationPlan.
bitmap_tile_operation_delta.dart must not implement undo.
```

Bitmap storage boundary:

```txt id="ju1a1v"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDelta remains before/after tile delta data.
TileDeltaCommand remains a command object over one or more tile deltas.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
BrushPixelCoverage remains geometry coverage data.
BrushPixelBlendOperation remains pixel before/after operation data.
RgbaColor remains RGBA component value object.
```

Timeline/storyboard boundary:

```txt id="1i86vv"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="dgbe8n"
BitmapBrushRasterizer
BrushDabSequence processing
BrushDab processing
BrushPixelCoverage processing
manual BitmapTile byte writing
manual global-to-local coordinate mapping
BitmapSurface drawing helpers
BitmapSurface mutation
CacheInvalidationPlan generation
actual cache implementation
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
renderer
playback implementation
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
save/load
persistence service
tile upload
CustomPainter changes
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
export
Photoshop-style / ABR brush import
```

## Expected changed files

Likely:

```txt id="brlhff"
lib/src/services/bitmap_tile_operation_delta.dart
test/services/bitmap_tile_operation_delta_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="0an2n3"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="crha4v"
- changed files
- tileDeltaCommandForBitmapTileOperations behavior
- no-op null behavior
- TileDelta.replaced behavior
- TileDeltaCommand behavior
- dirtyTiles behavior
- StateError propagation behavior
- original tile immutability behavior
- confirmation that applyBrushPixelBlendOperationsToBitmapTile is reused
- confirmation that no manual global-to-local mapping was added
- confirmation that no manual pixel byte writing was added
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BrushDabSequence processing was added
- confirmation that no BrushDab processing was added
- confirmation that no BrushPixelCoverage processing was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no CacheInvalidationPlan generation was added
- confirmation that no cache implementation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 165 is complete when:

```txt id="w7d1iu"
- bitmap_tile_operation_delta.dart exists and is tested.
- tileDeltaCommandForBitmapTileOperations returns null for empty operations.
- tileDeltaCommandForBitmapTileOperations returns null for outside-only operations.
- tileDeltaCommandForBitmapTileOperations returns a TileDeltaCommand for actual tile changes.
- command contains exactly one TileDelta.
- delta is a replacement delta.
- delta.before is the original tile.
- delta.after is the updated tile.
- command.dirtyTiles contains the tile coord.
- command.deltaFor(tile.coord) returns the created delta.
- StateError from Phase 164 before mismatch propagates.
- original BitmapTile is not mutated.
- applyBrushPixelBlendOperationsToBitmapTile is reused.
- No manual pixel byte writing is duplicated.
- No manual global-to-local mapping is duplicated.
- Existing BitmapTile operation apply tests still pass.
- Existing BitmapTile RGBA helper tests still pass.
- Existing TileDelta tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BrushPixelBlendOperation tests still pass.
- Existing BrushDabSequence blend tests still pass.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BrushDabSequence processing was added.
- No BitmapSurface mutation was added.
- No cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="91jw2a"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
