# Phase 164 Codex Task

## Title

Apply BrushPixelBlendOperation list to BitmapTile

## Repository

```txt id="9yfyxx"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="te7qdy"
master
```

## Project type

```txt id="gg5hl5"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 163.

Recent bitmap canvas / brush foundation phases:

```txt id="cmfk0f"
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
```

## Existing facts

`BitmapTile` already stores RGBA8888 bytes.

```txt id="3uaqbt"
offset + 0 = R
offset + 1 = G
offset + 2 = B
offset + 3 = A
```

`BitmapTile.pixels` returns a defensive copy.

`bitmap_tile_rgba.dart` already provides:

```dart id="k76uot"
RgbaColor readRgbaColorFromBitmapTile({
  required BitmapTile tile,
  required int x,
  required int y,
})

BitmapTile writeRgbaColorToBitmapTile({
  required BitmapTile tile,
  required int x,
  required int y,
  required RgbaColor color,
})
```

`BrushPixelBlendOperation` already exists:

```dart id="n1w54i"
final int x;
final int y;
final RgbaColor before;
final RgbaColor after;
```

Important coordinate distinction:

```txt id="wpgfmh"
BrushPixelBlendOperation.x/y are canvas/global pixel coordinates.
BitmapTile read/write helpers use local tile pixel coordinates.
```

This phase must bridge that distinction for one `BitmapTile`.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="6ou4td"
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

```txt id="gz5btz"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: BrushPixelBlendOperation list -> BitmapTile updated copy
Phase 165: BitmapTile before/after -> TileDeltaCommand connection
Phase 166: Brush stroke commit pipeline draft
```

Phase 164 applies existing pixel operations to a single tile.

This phase must remain pure tile operation logic.

This phase must not modify BitmapSurface, generate TileDeltaCommand, invalidate cache, create a rasterizer, add canvas UI, add undo, add renderer, add save/load, or change timeline/storyboard behavior.

## What structure this phase should create

Future brush rasterization should eventually flow like this:

```txt id="6hqkvz"
BrushDabSequence
-> BrushPixelBlendOperation list
-> applyBrushPixelBlendOperationsToBitmapTile(...)
-> updated BitmapTile
-> future TileDeltaCommand(beforeTile, afterTile)
-> future CacheInvalidationPlan
```

This phase only creates the `operation list -> updated BitmapTile` step.

Meaning:

```txt id="0zt8g2"
applyBrushPixelBlendOperationsToBitmapTile
= takes one BitmapTile and a list of global pixel operations
= applies only operations that fall inside that tile
= verifies each operation.before matches the current tile pixel
= writes operation.after into an updated pixel buffer
= returns a BitmapTile
```

This is not BitmapSurface mutation.

This is not TileDelta generation.

This is not cache invalidation.

This is not brush rasterization.

## Required references

Before editing, read:

```txt id="08h25f"
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
```

Also inspect:

```txt id="5h6ykm"
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
lib/src/models/rgba_color.dart
lib/src/models/brush_pixel_blend_operation.dart
lib/src/services/bitmap_tile_rgba.dart
test/services/bitmap_tile_rgba_test.dart
test/models/brush_pixel_blend_operation_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BitmapTile operation application foundation:

```dart id="cjeweu"
BitmapTile applyBrushPixelBlendOperationsToBitmapTile({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
})
```

The goal is to prepare for future TileDeltaCommand creation while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt id="vaxvwq"
pure Dart service
BitmapTile copy update
BrushPixelBlendOperation list application to one tile
global pixel coordinate -> local tile coordinate mapping
operation.before verification
focused service tests
```

Not allowed:

```txt id="xtwzt2"
BitmapBrushRasterizer
BrushDabSequence processing
BrushDab processing
BrushPixelCoverage processing
BitmapSurface mutation
BitmapSurface helper
TileDeltaCommand generation
CacheInvalidationPlan generation
actual cache implementation
canvas UI
pointer event handling
gesture handling
CustomPainter
renderer
playback
UndoService
undo stack
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Required production file

Create:

```txt id="w0q86o"
lib/src/services/bitmap_tile_operation_apply.dart
```

Required public function:

```dart id="ehz5gu"
BitmapTile applyBrushPixelBlendOperationsToBitmapTile({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
})
```

## Coordinate mapping

`BrushPixelBlendOperation.x/y` are canvas/global pixel coordinates.

`BitmapTile` uses tile coordinates:

```txt id="v9t9tt"
tile.coord.x
tile.coord.y
tile.size
```

For a tile:

```txt id="3p3af4"
tileGlobalLeft = tile.coord.x * tile.size
tileGlobalTop = tile.coord.y * tile.size
tileGlobalRightExclusive = tileGlobalLeft + tile.size
tileGlobalBottomExclusive = tileGlobalTop + tile.size
```

An operation affects this tile only if:

```txt id="h5zkfb"
tileGlobalLeft <= operation.x < tileGlobalRightExclusive
tileGlobalTop <= operation.y < tileGlobalBottomExclusive
```

Local tile coordinates are:

```txt id="l9e48n"
localX = operation.x - tileGlobalLeft
localY = operation.y - tileGlobalTop
```

Use local coordinates with `tile.byteOffsetForPixel(...)`.

Do not treat operation.x/y as local coordinates.

## Apply behavior

The function should:

```txt id="3qikhs"
1. Get a defensive copy of tile pixels.
2. Iterate operations in the provided order.
3. Ignore operations outside this tile.
4. For in-tile operations:
   - map global x/y to local x/y
   - read the current pixel color from the working pixel buffer
   - verify current color == operation.before
   - if it does not match, throw StateError
   - write operation.after into the working pixel buffer
5. If no in-tile operations were applied, return the original tile.
6. If at least one operation was applied, return tile.copyWith(pixels: updatedPixels).
```

Important:

```txt id="bcjvze"
The current pixel color must come from the working updated buffer, not repeatedly from the original tile.
```

Reason:

```txt id="psctg0"
A list may contain multiple operations for the same pixel.
The second operation's before color should match the first operation's after color.
```

## Before mismatch behavior

If an in-tile operation's `before` color does not equal the current color in the working tile buffer:

```txt id="zqsp8e"
throw StateError
```

Reason:

```txt id="9zdfvj"
This indicates that the operation list was generated against a different tile state.
Failing early prevents silent pixel corruption.
```

The error message should include useful information if practical:

```txt id="ih1m8k"
global x/y
local x/y
expected before
actual current
```

## RGBA byte order

Use the same byte order as `bitmap_tile_rgba.dart`:

```txt id="45s5ga"
offset + 0 = R
offset + 1 = G
offset + 2 = B
offset + 3 = A
```

Use `RgbaColor` for comparison.

## Efficiency note

Do not repeatedly call `writeRgbaColorToBitmapTile` for every operation if that would copy the whole tile repeatedly.

Preferred approach:

```txt id="9vderh"
- copy tile.pixels once
- update the working Uint8List
- return one new BitmapTile at the end
```

This keeps Phase 164 suitable for future large brush strokes.

## No-op behavior

`BrushPixelBlendOperation` already rejects `before == after`.

So no additional no-op filtering is required inside this function.

However:

```txt id="1y99cv"
operations outside the tile should be ignored
empty operations should return original tile
```

## Required tests

Create:

```txt id="tm97k2"
test/services/bitmap_tile_operation_apply_test.dart
```

Required tests:

```txt id="8s85fb"
returns original tile when operations is empty
returns original tile when no operation affects tile
applies one operation inside tile
maps global coordinates to local tile coordinates
does not treat operation coordinates as local coordinates
ignores operations outside tile
applies multiple operations in provided order
applies repeated same-pixel operations using working buffer
throws StateError when operation.before does not match current tile pixel
does not mutate original tile
preserves tile coord
preserves tile size
only changes targeted pixels
uses RGBA byte order through RgbaColor
```

## Suggested helpers

Use:

```dart id="u3klf5"
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
final purple = RgbaColor(r: 128, g: 0, b: 128, a: 255);
```

Suggested tile helper:

```dart id="ebkyvx"
BitmapTile blankTile({
  int tileX = 0,
  int tileY = 0,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested operation helper:

```dart id="zlyj41"
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

### Empty operation list

```txt id="1l7t90"
tile = blank tile
operations = []

expected:
identical(result, tile) == true
```

### One operation inside tile

```txt id="6f3qgg"
tile.coord = TileCoord(x: 0, y: 0)
tile.size = 2
operation.x = 1
operation.y = 0
before = transparent
after = red

expected:
result pixel local (1,0) = red
original tile pixel local (1,0) = transparent
```

### Global to local mapping

```txt id="gdo5hs"
tile.coord = TileCoord(x: 2, y: 3)
tile.size = 4

tile global origin:
x = 2 * 4 = 8
y = 3 * 4 = 12

operation.x = 8
operation.y = 12

local result:
x = 0
y = 0
```

This operation should write to local pixel `(0,0)`.

### Do not treat global coordinates as local

```txt id="sp5q9b"
tile.coord = TileCoord(x: 2, y: 3)
tile.size = 4
operation.x = 8
operation.y = 12

This is valid for the tile because it maps to local (0,0).
It must not be rejected as x >= tile.size.
```

### Repeated same-pixel operation

```txt id="gf9k7s"
operation 1:
x = 0
y = 0
before = transparent
after = red

operation 2:
x = 0
y = 0
before = red
after = blue

expected:
result pixel (0,0) = blue
```

The second operation should validate against the working buffer after operation 1.

### Before mismatch

```txt id="48bon8"
tile pixel = transparent

operation:
before = red
after = blue

expected:
throws StateError
```

## Architecture rules

BitmapTile operation apply rules:

```txt id="kuhmg5"
bitmap_tile_operation_apply.dart may know about BitmapTile.
bitmap_tile_operation_apply.dart may know about BrushPixelBlendOperation.
bitmap_tile_operation_apply.dart may know about RgbaColor.
bitmap_tile_operation_apply.dart may use BitmapTile.byteOffsetForPixel.
bitmap_tile_operation_apply.dart may use BitmapTile.pixels.
bitmap_tile_operation_apply.dart may use BitmapTile.copyWith.
bitmap_tile_operation_apply.dart must not know about BitmapSurface.
bitmap_tile_operation_apply.dart must not know about BrushDab.
bitmap_tile_operation_apply.dart must not know about BrushDabSequence.
bitmap_tile_operation_apply.dart must not know about BrushPixelCoverage.
bitmap_tile_operation_apply.dart must not call brushPixelBlendOperationsForDabSequence.
bitmap_tile_operation_apply.dart must not create TileDeltaCommand.
bitmap_tile_operation_apply.dart must not invalidate cache.
```

Bitmap storage boundary:

```txt id="gs7dyq"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
BrushPixelCoverage remains geometry coverage data.
BrushPixelBlendOperation remains pixel before/after operation data.
RgbaColor remains RGBA component value object.
```

Timeline/storyboard boundary:

```txt id="3nnslo"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="oyh72v"
BitmapBrushRasterizer
BrushDabSequence processing
BrushDab processing
BrushPixelCoverage processing
BitmapSurface drawing helpers
BitmapSurface mutation
TileDeltaCommand generation from pixels
CacheInvalidationPlan generation from pixels
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

```txt id="386my4"
lib/src/services/bitmap_tile_operation_apply.dart
test/services/bitmap_tile_operation_apply_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="8imbgq"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="q3dsxs"
- changed files
- applyBrushPixelBlendOperationsToBitmapTile behavior
- global-to-local coordinate mapping behavior
- outside-tile operation behavior
- before color verification behavior
- repeated same-pixel operation behavior
- original tile immutability behavior
- returned tile coord/size preservation
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BrushDabSequence processing was added
- confirmation that no BrushDab processing was added
- confirmation that no BrushPixelCoverage processing was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no TileDeltaCommand generation was added
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

Phase 164 is complete when:

```txt id="3o55cp"
- bitmap_tile_operation_apply.dart exists and is tested.
- applyBrushPixelBlendOperationsToBitmapTile applies in-tile BrushPixelBlendOperation items.
- global operation coordinates are mapped to local tile coordinates.
- operations outside the tile are ignored.
- empty/outside-only operations return the original tile.
- operation.before is verified against the working tile buffer.
- before mismatch throws StateError.
- repeated same-pixel operations use the working buffer after earlier operations.
- original BitmapTile is not mutated.
- returned updated BitmapTile preserves coord.
- returned updated BitmapTile preserves size.
- only targeted pixels are changed.
- RGBA byte order remains correct.
- Existing BitmapTile RGBA helper tests still pass.
- Existing BrushPixelBlendOperation tests still pass.
- Existing BrushDabSequence blend tests still pass.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BrushDabSequence processing was added.
- No BitmapSurface mutation was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="5ew8mr"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
