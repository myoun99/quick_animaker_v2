# Phase 163 Codex Task

## Title

BitmapTile RGBA read/write helper foundation

## Repository

```txt id="vznr4a"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="r37me1"
master
```

## Project type

```txt id="lobfut"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 162.

Recent bitmap canvas / brush foundation phases:

```txt id="uk0i28"
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
```

## Existing BitmapTile facts

`BitmapTile` already exists as a model.

It currently stores:

```txt id="qio6uo"
coord: TileCoord
size: int
_pixels: Uint8List
```

Pixel format:

```txt id="01kxmu"
RGBA8888
4 bytes per pixel
R, G, B, A order
```

Existing useful APIs:

```txt id="tfbfxr"
BitmapTile.bytesPerPixel == 4
BitmapTile.blank(...)
BitmapTile.pixels returns a defensive copy
BitmapTile.byteOffsetForPixel(x, y)
BitmapTile.copyWith(...)
BitmapTile.toJson/fromJson
BitmapTile equality/hashCode
```

Important existing boundary:

```txt id="5bkldy"
BitmapTile.pixels returns a copy, not the internal buffer.
```

So this phase should add helper logic around `BitmapTile`, not expose or mutate internal `_pixels`.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="gcmay1"
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA color and source-over blend math foundation
6. BrushDab pixel coverage foundation
7. BrushDab pixel blend foundation
8. BrushDabSequence pixel operation foundation
9. BitmapTile read/write helper foundation
10. BitmapBrushRasterizer
11. Brush stroke commit pipeline
12. Canvas UI integration
13. Undo/cache/playback integration
14. Save/load/export
```

Current local roadmap:

```txt id="z0nvt0"
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

Phase 163 adds pure helpers for reading and writing one local tile pixel as `RgbaColor`.

This phase must remain small and deterministic.

This phase must not apply brush operations yet.

This phase must not add BitmapBrushRasterizer, BitmapSurface mutation, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future tile writing should eventually flow like this:

```txt id="4kb0ca"
BitmapTile
-> readRgbaColorFromBitmapTile(...)
-> BrushPixelBlendOperation before/after validation
-> writeRgbaColorToBitmapTile(...)
-> future BitmapTile updated copy
-> future TileDeltaCommand
```

This phase only creates one-pixel RGBA read/write helpers.

Meaning:

```txt id="7r7coa"
readRgbaColorFromBitmapTile
= read a local x/y pixel from BitmapTile RGBA8888 bytes as RgbaColor

writeRgbaColorToBitmapTile
= return a new BitmapTile with one local x/y pixel replaced by a RgbaColor
```

This is not brush rasterization.

This is not applying a list of operations.

This is not delta generation.

This is pure tile helper logic.

## Required references

Before editing, read:

```txt id="bc6k7e"
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
```

Also inspect:

```txt id="8khdne"
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
lib/src/models/rgba_color.dart
lib/src/models/brush_pixel_blend_operation.dart
lib/src/services/brush_dab_sequence_blend.dart
test/models/bitmap_tile_test.dart
test/models/rgba_color_test.dart
test/models/brush_pixel_blend_operation_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BitmapTile RGBA read/write helper foundation:

```txt id="u0zkfb"
readRgbaColorFromBitmapTile
writeRgbaColorToBitmapTile
```

The goal is to prepare for future BitmapTile operation application while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt id="fw13fv"
pure Dart service
BitmapTile local pixel read
BitmapTile local pixel write returning a new BitmapTile
RgbaColor <-> RGBA8888 byte mapping
focused service tests
```

Not allowed:

```txt id="7byigg"
BitmapBrushRasterizer
BrushDabSequence processing
BrushPixelBlendOperation list application
TileDeltaCommand generation
CacheInvalidationPlan generation
BitmapSurface mutation
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

```txt id="smg8po"
lib/src/services/bitmap_tile_rgba.dart
```

Required public functions:

```dart id="vbmewf"
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

## Coordinate convention

This phase uses **local tile coordinates** only.

```txt id="yzql87"
x: 0 <= x < tile.size
y: 0 <= y < tile.size
```

Do not use global canvas coordinates.

Do not convert from global coordinates to tile coordinates in this phase.

Use existing:

```txt id="of68e8"
tile.byteOffsetForPixel(x: x, y: y)
```

for validation and offset calculation.

## RGBA byte order

Use existing `BitmapTile` pixel format:

```txt id="vg7q6p"
offset + 0 = R
offset + 1 = G
offset + 2 = B
offset + 3 = A
```

`readRgbaColorFromBitmapTile` should return:

```dart id="vqkrs7"
RgbaColor(
  r: pixels[offset],
  g: pixels[offset + 1],
  b: pixels[offset + 2],
  a: pixels[offset + 3],
)
```

`writeRgbaColorToBitmapTile` should write:

```txt id="j9vhkk"
pixels[offset] = color.r
pixels[offset + 1] = color.g
pixels[offset + 2] = color.b
pixels[offset + 3] = color.a
```

## Immutability rule

Do not mutate the original tile.

Important:

```txt id="8i84hg"
BitmapTile.pixels returns a defensive copy.
```

So `writeRgbaColorToBitmapTile` should:

```txt id="aatplb"
1. read a copy using tile.pixels
2. write into that copy
3. return tile.copyWith(pixels: updatedPixels)
```

The returned tile should preserve:

```txt id="vnxqnn"
tile.coord
tile.size
```

unless `copyWith` already handles this.

## No-op behavior

If the target pixel already equals `color`, still returning a new equal `BitmapTile` is acceptable.

Do not add no-op optimization in this phase unless it naturally falls out.

Reason:

```txt id="4irzib"
Operation-level no-op skipping already exists in Phase 162.
This helper should stay simple and deterministic.
```

## Required tests

Create:

```txt id="hgzxco"
test/services/bitmap_tile_rgba_test.dart
```

Required tests:

```txt id="7s47di"
readRgbaColorFromBitmapTile reads transparent pixel from blank tile
readRgbaColorFromBitmapTile reads RGBA bytes in R,G,B,A order
readRgbaColorFromBitmapTile rejects negative x
readRgbaColorFromBitmapTile rejects negative y
readRgbaColorFromBitmapTile rejects x >= tile.size
readRgbaColorFromBitmapTile rejects y >= tile.size

writeRgbaColorToBitmapTile writes RGBA bytes in R,G,B,A order
writeRgbaColorToBitmapTile returns a new BitmapTile
writeRgbaColorToBitmapTile does not mutate original tile
writeRgbaColorToBitmapTile preserves tile coord
writeRgbaColorToBitmapTile preserves tile size
writeRgbaColorToBitmapTile only changes the target pixel
writeRgbaColorToBitmapTile rejects negative x
writeRgbaColorToBitmapTile rejects negative y
writeRgbaColorToBitmapTile rejects x >= tile.size
writeRgbaColorToBitmapTile rejects y >= tile.size
```

## Suggested helpers

Use:

```dart id="98vbjl"
final coord = TileCoord(x: 0, y: 0);
final tile = BitmapTile.blank(coord: coord, size: 2);
```

Suggested colors:

```dart id="mmt7lq"
final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
final greenTransparent = RgbaColor(r: 0, g: 255, b: 0, a: 128);
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
```

For byte order tests, use non-symmetric values:

```dart id="0gv0ci"
final color = RgbaColor(r: 1, g: 2, b: 3, a: 4);
```

This avoids false positives from repeated values.

## Suggested examples

### Read blank pixel

```txt id="26a99n"
tile = BitmapTile.blank(coord: TileCoord(x: 0, y: 0), size: 2)
read x=0, y=0

expected:
RgbaColor(r: 0, g: 0, b: 0, a: 0)
```

### Write one pixel

```txt id="u8y1w7"
tile = blank 2x2
write x=1, y=0
color = RgbaColor(r: 1, g: 2, b: 3, a: 4)

expected returned tile pixels:
pixel (0,0) = 0,0,0,0
pixel (1,0) = 1,2,3,4
pixel (0,1) = 0,0,0,0
pixel (1,1) = 0,0,0,0
```

### Original tile remains unchanged

```txt id="92pk91"
original = blank 2x2
updated = writeRgbaColorToBitmapTile(original, x: 1, y: 0, color: red)

read original x=1,y=0 -> transparent
read updated x=1,y=0 -> red
```

## Architecture rules

BitmapTile RGBA helper rules:

```txt id="7kyx5x"
bitmap_tile_rgba.dart may know about BitmapTile.
bitmap_tile_rgba.dart may know about RgbaColor.
bitmap_tile_rgba.dart may use BitmapTile.byteOffsetForPixel.
bitmap_tile_rgba.dart may use BitmapTile.pixels.
bitmap_tile_rgba.dart may use BitmapTile.copyWith.
bitmap_tile_rgba.dart must not know about BitmapSurface.
bitmap_tile_rgba.dart must not know about BrushDab.
bitmap_tile_rgba.dart must not know about BrushDabSequence.
bitmap_tile_rgba.dart must not know about BrushPixelCoverage.
bitmap_tile_rgba.dart must not know about BrushPixelBlendOperation.
bitmap_tile_rgba.dart must not create TileDeltaCommand.
bitmap_tile_rgba.dart must not invalidate cache.
```

Bitmap storage boundary:

```txt id="m9kccp"
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

```txt id="5tfaqj"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="m0b7uw"
BitmapBrushRasterizer
BrushDabSequence processing
BrushPixelBlendOperation list application
pixel operation application
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

```txt id="moe3lq"
lib/src/services/bitmap_tile_rgba.dart
test/services/bitmap_tile_rgba_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="fi00vr"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="80xv9y"
- changed files
- readRgbaColorFromBitmapTile behavior
- writeRgbaColorToBitmapTile behavior
- RGBA byte order behavior
- local tile coordinate behavior
- original tile immutability behavior
- returned tile coord/size preservation
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BrushDabSequence processing was added
- confirmation that no BrushPixelBlendOperation list application was added
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

Phase 163 is complete when:

```txt id="4eo5tw"
- bitmap_tile_rgba.dart exists and is tested.
- readRgbaColorFromBitmapTile reads RGBA8888 bytes in R,G,B,A order.
- writeRgbaColorToBitmapTile writes RGBA8888 bytes in R,G,B,A order.
- read/write use local tile coordinates only.
- invalid local coordinates are rejected.
- write returns a new BitmapTile.
- write does not mutate the original BitmapTile.
- write preserves tile coord.
- write preserves tile size.
- write only changes the target pixel.
- Existing BitmapTile tests still pass.
- Existing RgbaColor tests still pass.
- Existing BrushPixelBlendOperation tests still pass.
- Existing BrushDabSequence blend tests still pass.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BrushDabSequence processing was added.
- No pixel operation list application was added.
- No BitmapSurface mutation was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="pyshq4"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
