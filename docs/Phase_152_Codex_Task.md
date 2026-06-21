# Phase 152 Codex Task

## Title

BitmapSurface / BitmapTile / TileCoord model foundation

## Repository

```txt
myoun99/quick_animaker_v2
```

## Base branch

```txt
master
```

## Project type

```txt
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 150.

The long-term architecture documentation has been updated after Phase 150.

Current direction:

```txt
QuickAnimaker v2 is a bitmap-first animation tool.
Final artwork source of truth should be bitmap tile data.
Stroke data is input/history metadata, not the display-time source of truth.
Undo should eventually use tile deltas.
Playback should eventually use baked preview cache images.
```

Phase 152 begins the actual bitmap canvas storage foundation.

This phase must only introduce pure bitmap storage models.

Do not add drawing behavior yet.

Do not add brush rasterization yet.

Do not add canvas UI yet.

Do not add undo/redo yet.

Do not add cache or save/load yet.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> StrokeBuilder
-> DabPlacement
-> BitmapBrushRasterizer
-> DirtyTileSet
-> BitmapTile updates
-> TileDeltaCommand
-> FrameCompositeCache invalidation
-> PlaybackPreviewCache invalidation
```

This phase only creates the storage foundation for the middle part:

```txt
BitmapSurface
-> sparse map of BitmapTile
-> indexed by TileCoord
```

This is the first step toward a lightweight bitmap engine.

## Required references

Before editing, read:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
```

Also inspect:

```txt
lib/src/models/canvas_size.dart
lib/src/models/canvas_point.dart
lib/src/models/viewport_point.dart
lib/src/models/canvas_viewport.dart
lib/src/models/brush_input_sample.dart
lib/src/models/stroke_point.dart
test/models/canvas_viewport_test.dart
test/models/brush_input_sample_test.dart
```

Do not modify timeline or storyboard behavior in this phase.

## Goal

Add pure Dart bitmap storage model foundations:

```txt
TileCoord
BitmapTile
BitmapSurface
```

The goal is to define where bitmap pixel data will live before future phases add dirty tile tracking, tile delta undo, brush rasterization, cache, or canvas UI integration.

## Strong scope rule

This phase is model-only.

Allowed:

```txt
pure Dart model classes
pure Dart validation
copyWith / equality / hashCode / toJson / fromJson
focused model tests
```

Not allowed:

```txt
brush rasterizer
drawing behavior
canvas UI
pointer event handling
gesture handling
CustomPainter changes
renderer/cache implementation
undo/redo
save/load
persistence service
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Pixel storage convention

For this phase, use a simple fixed pixel format:

```txt
RGBA8888
```

Meaning:

```txt
4 bytes per pixel
byte order: R, G, B, A
alpha range: 0..255
```

Do not introduce multiple pixel formats yet.

Do not use Flutter `Color`, `Image`, `Canvas`, `Paint`, `ui.Image`, or `dart:ui`.

Use plain Dart and `dart:typed_data`.

Recommended constant:

```dart
static const int bytesPerPixel = 4;
```

## Required production files

### 1. TileCoord

Create:

```txt
lib/src/models/tile_coord.dart
```

Required fields:

```dart
final int x;
final int y;
```

Meaning:

```txt
x: tile column index inside the surface
y: tile row index inside the surface
```

For Phase 152, tile coordinates must be non-negative.

Required behavior:

```txt
- immutable model
- const constructor if possible
- x >= 0
- y >= 0
- invalid values throw ArgumentError
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Required helper:

```dart
TileCoord.fromPixel({
  required int pixelX,
  required int pixelY,
  required int tileSize,
})
```

Rules:

```txt
pixelX >= 0
pixelY >= 0
tileSize > 0
tileSize must be finite integer naturally because it is int
invalid values throw ArgumentError
```

Formula:

```txt
tileX = pixelX ~/ tileSize
tileY = pixelY ~/ tileSize
```

Do not add infinite canvas semantics in this phase.

If future infinite canvas needs negative tile coordinates, that should be a separate explicit design phase.

### 2. BitmapTile

Create:

```txt
lib/src/models/bitmap_tile.dart
```

Required fields:

```dart
final TileCoord coord;
final int size;
final Uint8List pixels;
```

Meaning:

```txt
coord: tile coordinate in the BitmapSurface
size: tile width and height in pixels
pixels: RGBA8888 pixel data
```

Required behavior:

```txt
- immutable public API
- size > 0
- pixels.length == size * size * 4
- invalid values throw ArgumentError
- defensive copy input pixels on construction
- do not expose mutable internal pixel buffer directly if avoidable
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Important:

`Uint8List` is mutable, so avoid accidental shared mutation.

Preferred approach:

```txt
- constructor copies incoming Uint8List with Uint8List.fromList(...)
- pixels getter returns a copy, or expose a read-only view if the project already uses one
- internal equality compares pixel bytes by value
```

If implementing a copied getter is too cumbersome, at minimum tests must prove that mutating the input Uint8List after construction does not mutate the tile.

Required factories:

```dart
BitmapTile.blank({
  required TileCoord coord,
  required int size,
})
```

Behavior:

```txt
creates a transparent tile
all bytes are 0
```

Optional helper:

```dart
bool get isFullyTransparent
```

If added, test it.

Do not add pixel blending.

Do not add brush drawing.

Do not add per-pixel set/get unless needed for tests.

If adding simple helpers, keep them minimal:

```dart
int byteOffsetForPixel({required int x, required int y})
```

Rules:

```txt
x >= 0
y >= 0
x < size
y < size
offset = (y * size + x) * 4
```

This helper is allowed because it is pure storage math and useful for future brush rasterization.

### 3. BitmapSurface

Create:

```txt
lib/src/models/bitmap_surface.dart
```

Required fields:

```dart
final CanvasSize canvasSize;
final int tileSize;
```

Internal / exposed tile data:

```txt
sparse map from TileCoord to BitmapTile
```

Recommended constructor shape:

```dart
BitmapSurface({
  required this.canvasSize,
  this.tileSize = 256,
  Map<TileCoord, BitmapTile> tiles = const {},
})
```

Required behavior:

```txt
- immutable public API
- tileSize > 0
- canvasSize width/height must be compatible with existing CanvasSize validation
- tiles are sparse
- do not allocate all tiles eagerly
- constructor must validate every tile:
  - tile.coord must match its map key
  - tile.size must equal surface.tileSize
  - tile coord must be inside surface tile bounds
- defensive copy tile map
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Required helpers:

```dart
int get tileColumnCount
int get tileRowCount
int get tileCount
bool containsTileCoord(TileCoord coord)
BitmapTile? tileAt(TileCoord coord)
BitmapSurface putTile(BitmapTile tile)
BitmapSurface removeTile(TileCoord coord)
```

Rules:

```txt
tileColumnCount = ceil(canvasWidth / tileSize)
tileRowCount = ceil(canvasHeight / tileSize)
tileCount = tileColumnCount * tileRowCount
containsTileCoord returns true only for 0 <= x < tileColumnCount and 0 <= y < tileRowCount
tileAt returns null for missing sparse tile
putTile returns a new BitmapSurface with that tile inserted/replaced
removeTile returns a new BitmapSurface without that tile
original surface must not mutate
```

Important:

`BitmapSurface` should be sparse.

A new empty surface must not allocate every tile.

For example, a 1920x1080 canvas with tileSize 256 has many possible tile coordinates, but the surface should store zero tiles until pixels exist.

Do not add dirty tile tracking yet.

Do not add cache invalidation yet.

Do not add undo delta logic yet.

Do not add save/load service yet.

JSON:

For this phase, simple JSON is acceptable.

Expected shape can be:

```json
{
  "canvasSize": { "...": "existing CanvasSize json shape" },
  "tileSize": 256,
  "tiles": [
    { "...": "BitmapTile json" }
  ]
}
```

Do not compress pixel data yet.

For `BitmapTile.toJson`, because `Uint8List` is not JSON directly, use:

```dart
'pixels': pixels.toList()
```

This is not final storage format.

It is only a model test JSON representation.

Long-term compressed tile storage will be a later persistence phase.

## Required tests

### 1. TileCoord tests

Create:

```txt
test/models/tile_coord_test.dart
```

Required tests:

```txt
creates with non-negative x and y
negative x throws
negative y throws
copyWith updates x
copyWith updates y
equality includes x and y
toJson/fromJson round-trips
fromPixel maps pixel coordinate to tile coordinate
fromPixel handles boundary exactly at tile size
fromPixel rejects negative pixelX
fromPixel rejects negative pixelY
fromPixel rejects zero tileSize
fromPixel rejects negative tileSize
```

Example:

```txt
pixelX 0, pixelY 0, tileSize 256 -> TileCoord(0, 0)
pixelX 255, pixelY 255, tileSize 256 -> TileCoord(0, 0)
pixelX 256, pixelY 256, tileSize 256 -> TileCoord(1, 1)
pixelX 511, pixelY 10, tileSize 256 -> TileCoord(1, 0)
```

### 2. BitmapTile tests

Create:

```txt
test/models/bitmap_tile_test.dart
```

Required tests:

```txt
blank creates transparent pixel buffer
blank pixel length is size * size * 4
constructor accepts valid pixels
constructor rejects zero size
constructor rejects negative size
constructor rejects wrong pixel length
constructor defensively copies input pixels
copyWith updates coord
copyWith updates size and pixels together
equality includes coord, size, and pixel bytes
toJson/fromJson round-trips
byteOffsetForPixel returns expected offset if helper is added
byteOffsetForPixel rejects negative x if helper is added
byteOffsetForPixel rejects negative y if helper is added
byteOffsetForPixel rejects x >= size if helper is added
byteOffsetForPixel rejects y >= size if helper is added
isFullyTransparent is true for blank tile if helper is added
isFullyTransparent is false if any byte is non-zero if helper is added
```

### 3. BitmapSurface tests

Create:

```txt
test/models/bitmap_surface_test.dart
```

Required tests:

```txt
empty surface stores no tiles
default tileSize is 256
tileColumnCount uses ceiling division
tileRowCount uses ceiling division
tileCount is columns * rows
containsTileCoord returns true for valid coords
containsTileCoord returns false for coord outside right edge
containsTileCoord returns false for coord outside bottom edge
tileAt returns null for missing tile
putTile inserts a tile
putTile replaces existing tile
putTile does not mutate original surface
removeTile removes a tile
removeTile does not mutate original surface
constructor rejects tile whose coord does not match map key
constructor rejects tile with wrong size
constructor rejects tile outside surface bounds
toJson/fromJson round-trips
surface does not allocate all possible tiles eagerly
```

Example for ceiling division:

```txt
canvas 1920x1080, tileSize 256
tileColumnCount = 8
tileRowCount = 5
tileCount = 40
```

Because:

```txt
ceil(1920 / 256) = 8
ceil(1080 / 256) = 5
```

### 4. Integration / compatibility tests

Do not create UI tests.

Do not modify timeline/storyboard tests unless required by import/export changes.

If useful, add a small pure model compatibility test confirming:

```txt
CanvasPoint can be mapped to TileCoord using TileCoord.fromPixel after integer conversion.
```

But do not add canvas input behavior.

Do not add BrushInputSample integration yet.

## Architecture rules

Bitmap storage rules:

```txt
- BitmapSurface is sparse.
- BitmapSurface does not allocate all possible tiles eagerly.
- BitmapTile owns RGBA8888 pixel data.
- TileCoord is non-negative in Phase 152.
- BitmapSurface validates tile coord and tile size.
- BitmapSurface is not a renderer.
- BitmapSurface is not a cache.
- BitmapSurface is not undo history.
- BitmapSurface is not persistence.
```

Brush/canvas boundary rules:

```txt
- BrushInputSample remains pre-stroke input data.
- StrokePoint remains Stroke coordinate data.
- CanvasViewport remains coordinate conversion only.
- BitmapSurface does not know about PointerEvent.
- BitmapSurface does not know about Flutter widgets.
- BitmapSurface does not know about CustomPainter.
- BitmapSurface does not rasterize brushes.
```

Timeline/storyboard boundary rules:

```txt
- Do not modify TimelinePanel.
- Do not modify LayerTimelineGrid.
- Do not modify TimelineController.
- Do not modify StoryboardPanel.
- Do not modify timeline range semantics.
- Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt
actual canvas UI
drawing canvas
pointer event handling
tablet input
gesture detector
zoom/pan UI integration
brush rasterizer
brush engine execution
dab placement
stroke rendering
dirty tile tracking
dirty region model
tile delta undo
undo/redo service
cache invalidation
FrameCompositeCache
PlaybackPreviewCache
save/load
persistence service
renderer
tile upload
CustomPainter changes
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
playback implementation
export
Photoshop-style / ABR brush import
```

## Expected changed files

Likely:

```txt
lib/src/models/tile_coord.dart
lib/src/models/bitmap_tile.dart
lib/src/models/bitmap_surface.dart
test/models/tile_coord_test.dart
test/models/bitmap_tile_test.dart
test/models/bitmap_surface_test.dart
```

Possibly:

```txt
test/models/bitmap_surface_canvas_point_compatibility_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt
- changed files
- new model files added
- TileCoord fields and validation
- BitmapTile fields, pixel format, and validation
- BitmapSurface fields and sparse tile policy
- confirmation that BitmapSurface does not allocate all tiles eagerly
- confirmation that BitmapTile uses RGBA8888 plain byte data
- confirmation that no dart:ui / Flutter Canvas / Paint / Image is used
- confirmation that no brush rasterizer was added
- confirmation that no canvas UI was added
- confirmation that no dirty tile tracking was added
- confirmation that no undo/redo was added
- confirmation that no cache/save/load was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 152 is complete when:

```txt
- TileCoord exists and is tested.
- BitmapTile exists and is tested.
- BitmapSurface exists and is tested.
- BitmapTile validates pixel buffer length.
- BitmapSurface stores tiles sparsely.
- BitmapSurface does not allocate all possible tiles eagerly.
- BitmapSurface validates tile coord bounds.
- BitmapSurface validates tile size compatibility.
- JSON round-trip tests pass for all new models.
- Existing brush input and canvas viewport tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No brush rasterization was added.
- No drawing canvas UI was added.
- No dirty tile / undo / cache / save-load behavior was added.
```

## Manual check list

This phase is model-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
