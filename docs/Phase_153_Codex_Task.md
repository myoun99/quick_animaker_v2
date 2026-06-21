# Phase 153 Codex Task

## Title

DirtyRegion / DirtyTileSet model foundation

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

QuickAnimaker v2 is complete through Phase 152.

Phase 152 added pure bitmap storage model foundations:

```txt
TileCoord
BitmapTile
BitmapSurface
```

Current long-term direction:

```txt
QuickAnimaker v2 is bitmap-first.
Final artwork source of truth should be bitmap tile data.
BitmapSurface stores sparse BitmapTile entries.
Future brush drawing should update only affected tiles.
Future undo should restore tile deltas.
Future playback should use baked preview caches.
```

Phase 153 adds dirty tracking foundations.

This phase still must not add drawing, brush rasterization, undo, cache, save/load, or canvas UI.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> BrushStrokeBuilder
-> DabPlacement
-> DirtyRegion
-> DirtyTileSet
-> BitmapTile updates
-> TileDeltaCommand
-> FrameCompositeCache invalidation
-> PlaybackPreviewCache invalidation
```

This phase only creates:

```txt
DirtyRegion
DirtyTileSet
```

Meaning:

```txt
DirtyRegion
= an integer pixel rectangle that describes the changed area

DirtyTileSet
= a set of TileCoord values affected by one or more dirty regions
```

This is model-only.

## Required references

Before editing, read:

```txt
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
```

Also inspect:

```txt
lib/src/models/tile_coord.dart
lib/src/models/bitmap_tile.dart
lib/src/models/bitmap_surface.dart
lib/src/models/canvas_point.dart
lib/src/models/canvas_viewport.dart
test/models/tile_coord_test.dart
test/models/bitmap_tile_test.dart
test/models/bitmap_surface_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure Dart dirty tracking model foundations:

```txt
DirtyRegion
DirtyTileSet
```

The goal is to prepare the project for future brush rasterization, tile delta undo, and cache invalidation without implementing those systems yet.

## Strong scope rule

Allowed:

```txt
pure Dart model classes
integer rectangle math
dirty tile coordinate derivation
copyWith / equality / hashCode / toJson / fromJson
focused model tests
```

Not allowed:

```txt
brush rasterizer
dab placement
actual drawing behavior
canvas UI
pointer event handling
gesture handling
CustomPainter
renderer
cache invalidation
FrameCompositeCache
PlaybackPreviewCache
TileDeltaCommand
undo/redo
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Coordinate convention

Use integer pixel coordinates.

Use exclusive-right / exclusive-bottom rectangle bounds.

```txt
left
top
rightExclusive
bottomExclusive
```

Meaning:

```txt
x is inside if left <= x < rightExclusive
y is inside if top <= y < bottomExclusive
```

This avoids off-by-one errors when converting pixel regions to tile coordinates.

For Phase 153, dirty regions must be non-negative.

```txt
left >= 0
top >= 0
rightExclusive > left
bottomExclusive > top
```

Do not introduce infinite canvas or negative dirty regions in this phase.

If future infinite canvas needs negative pixel coordinates, that should be a separate explicit design phase.

## Required production files

### 1. DirtyRegion

Create:

```txt
lib/src/models/dirty_region.dart
```

Required fields:

```dart
final int left;
final int top;
final int rightExclusive;
final int bottomExclusive;
```

Required behavior:

```txt
- immutable model
- non-negative coordinates
- rightExclusive > left
- bottomExclusive > top
- invalid values throw ArgumentError
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Required getters:

```dart
int get width
int get height
```

Definitions:

```txt
width = rightExclusive - left
height = bottomExclusive - top
```

Required factories:

```dart
DirtyRegion.fromLTBR({
  required int left,
  required int top,
  required int rightExclusive,
  required int bottomExclusive,
})

DirtyRegion.fromXYWH({
  required int x,
  required int y,
  required int width,
  required int height,
})
```

`fromXYWH` rules:

```txt
x >= 0
y >= 0
width > 0
height > 0
rightExclusive = x + width
bottomExclusive = y + height
```

Required helpers:

```dart
bool containsPixel({required int x, required int y})
bool intersects(DirtyRegion other)
DirtyRegion union(DirtyRegion other)
Set<TileCoord> toTileCoords({required int tileSize})
```

Rules:

```txt
containsPixel:
- true only when left <= x < rightExclusive and top <= y < bottomExclusive

intersects:
- true when two non-empty regions overlap

union:
- returns the smallest DirtyRegion that contains both regions

toTileCoords:
- tileSize > 0
- returns all TileCoord values touched by the dirty region
- output must be order-independent from a semantic point of view
- may return Set<TileCoord>
```

Tile conversion formula:

```txt
startTileX = left ~/ tileSize
endTileX = (rightExclusive - 1) ~/ tileSize

startTileY = top ~/ tileSize
endTileY = (bottomExclusive - 1) ~/ tileSize
```

Then include every tile coordinate:

```txt
x in startTileX..endTileX
y in startTileY..endTileY
```

Examples:

```txt
DirtyRegion(left: 0, top: 0, rightExclusive: 1, bottomExclusive: 1), tileSize 256
-> TileCoord(0, 0)

DirtyRegion(left: 255, top: 0, rightExclusive: 257, bottomExclusive: 1), tileSize 256
-> TileCoord(0, 0), TileCoord(1, 0)

DirtyRegion(left: 0, top: 255, rightExclusive: 1, bottomExclusive: 257), tileSize 256
-> TileCoord(0, 0), TileCoord(0, 1)

DirtyRegion(left: 255, top: 255, rightExclusive: 257, bottomExclusive: 257), tileSize 256
-> TileCoord(0, 0), TileCoord(1, 0), TileCoord(0, 1), TileCoord(1, 1)
```

Do not clamp to BitmapSurface bounds in DirtyRegion.

DirtyRegion is pure pixel-region math.

Surface bounds filtering can be done later or by DirtyTileSet / future application code.

### 2. DirtyTileSet

Create:

```txt
lib/src/models/dirty_tile_set.dart
```

Required internal data:

```dart
Set<TileCoord>
```

Recommended constructor shape:

```dart
DirtyTileSet([Iterable<TileCoord> coords = const []])
```

Required behavior:

```txt
- immutable public API
- defensive copy input coords
- expose unmodifiable coords
- copyWith or equivalent immutable update helpers
- toJson/fromJson
- equality/hashCode
- hashCode must be order-independent
- toString
```

Required getters:

```dart
Set<TileCoord> get coords
int get length
bool get isEmpty
bool get isNotEmpty
```

Required factories:

```dart
DirtyTileSet.empty()

DirtyTileSet.fromRegion({
  required DirtyRegion region,
  required int tileSize,
})

DirtyTileSet.fromRegions({
  required Iterable<DirtyRegion> regions,
  required int tileSize,
})
```

Required helpers:

```dart
bool contains(TileCoord coord)
DirtyTileSet add(TileCoord coord)
DirtyTileSet addAll(Iterable<TileCoord> coords)
DirtyTileSet remove(TileCoord coord)
DirtyTileSet union(DirtyTileSet other)
DirtyTileSet intersect(DirtyTileSet other)
DirtyTileSet difference(DirtyTileSet other)
```

Rules:

```txt
All helpers return a new DirtyTileSet.
Original DirtyTileSet must not mutate.
Equality must ignore insertion order.
hashCode must ignore insertion order.
```

Recommended hashCode:

```dart
@override
int get hashCode => Object.hashAllUnordered(_coords);
```

or equivalent order-independent hashing.

Do not use list-order-dependent hashing.

## Required tests

### 1. DirtyRegion tests

Create:

```txt
test/models/dirty_region_test.dart
```

Required tests:

```txt
creates from left/top/rightExclusive/bottomExclusive
creates from x/y/width/height
width returns rightExclusive - left
height returns bottomExclusive - top
negative left throws
negative top throws
rightExclusive <= left throws
bottomExclusive <= top throws
fromXYWH rejects negative x
fromXYWH rejects negative y
fromXYWH rejects zero width
fromXYWH rejects zero height
fromXYWH rejects negative width
fromXYWH rejects negative height
copyWith updates fields
equality includes all bounds
toJson/fromJson round-trips
containsPixel is true inside region
containsPixel is false at rightExclusive
containsPixel is false at bottomExclusive
intersects returns true for overlapping regions
intersects returns false for touching but non-overlapping regions
union returns bounding region
toTileCoords returns one tile for region fully inside one tile
toTileCoords returns two horizontal tiles across tile boundary
toTileCoords returns two vertical tiles across tile boundary
toTileCoords returns four tiles across both boundaries
toTileCoords rejects zero tileSize
toTileCoords rejects negative tileSize
```

### 2. DirtyTileSet tests

Create:

```txt
test/models/dirty_tile_set_test.dart
```

Required tests:

```txt
empty set has length 0
constructor stores coords
constructor defensively copies input coords
coords getter is unmodifiable
contains returns true for stored coord
contains returns false for missing coord
add returns new set with coord
add does not mutate original
addAll returns new set with all coords
remove returns new set without coord
remove does not mutate original
union combines two sets
intersect keeps shared coords
difference removes coords from other set
fromRegion derives touched tiles
fromRegions merges touched tiles from multiple regions
equality ignores insertion order
hashCode ignores insertion order
toJson/fromJson round-trips
```

Important equality/hashCode test:

```txt
DirtyTileSet([a, b]) == DirtyTileSet([b, a])
and both have the same hashCode
```

### 3. Integration boundary tests

Do not add UI tests.

Do not modify timeline/storyboard tests.

If useful, add a small test confirming:

```txt
DirtyRegion.toTileCoords(tileSize: 256)
produces TileCoord values compatible with BitmapSurface.containsTileCoord(...)
```

But do not add clipping or cache invalidation behavior yet.

## Architecture rules

Dirty tracking rules:

```txt
DirtyRegion is pixel-space rectangle math.
DirtyTileSet is tile-coordinate set math.
DirtyRegion does not know about BrushInputSample.
DirtyRegion does not rasterize brushes.
DirtyTileSet does not update BitmapTile pixels.
DirtyTileSet does not create TileDeltaCommand.
DirtyTileSet does not invalidate cache.
DirtyTileSet does not know about Flutter widgets.
```

Bitmap storage boundary:

```txt
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
TileCoord remains non-negative tile coordinate.
DirtyRegion and DirtyTileSet may depend on TileCoord.
DirtyRegion and DirtyTileSet should not change BitmapSurface behavior in this phase.
```

Timeline/storyboard boundary:

```txt
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
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
pixel blending
BitmapTile mutation helpers for drawing
TileDeltaCommand
undo/redo
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
lib/src/models/dirty_region.dart
lib/src/models/dirty_tile_set.dart
test/models/dirty_region_test.dart
test/models/dirty_tile_set_test.dart
```

Possibly:

```txt
test/models/dirty_region_bitmap_surface_compatibility_test.dart
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
- DirtyRegion fields and validation
- DirtyRegion tile conversion convention
- DirtyTileSet storage and immutability policy
- confirmation that DirtyTileSet equality/hashCode ignore insertion order
- confirmation that no brush rasterizer was added
- confirmation that no BitmapTile drawing mutation helpers were added
- confirmation that no canvas UI was added
- confirmation that no TileDelta/undo was added
- confirmation that no cache/save/load was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 153 is complete when:

```txt
- DirtyRegion exists and is tested.
- DirtyTileSet exists and is tested.
- DirtyRegion uses left/top/rightExclusive/bottomExclusive.
- DirtyRegion can convert pixel bounds to touched TileCoord values.
- DirtyTileSet is immutable from the public API.
- DirtyTileSet equality ignores insertion order.
- DirtyTileSet hashCode ignores insertion order.
- Existing Phase 152 BitmapSurface / BitmapTile / TileCoord tests still pass.
- Existing canvas viewport and brush input tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No brush rasterization was added.
- No drawing canvas UI was added.
- No TileDelta / undo / cache / save-load behavior was added.
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
