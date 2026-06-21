# Phase 154 Codex Task

## Title

TileDelta / TileDeltaCommand model foundation

## Repository

```txt id="b2n0pz"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="w1zqgs"
master
```

## Project type

```txt id="ns0sms"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 153.

Recent bitmap canvas foundation phases:

```txt id="h6ectc"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
```

Current long-term direction:

```txt id="wqg2jo"
QuickAnimaker v2 is bitmap-first.
Final artwork source of truth should be bitmap tile data.
BitmapSurface stores sparse BitmapTile entries.
DirtyRegion describes changed pixel bounds.
DirtyTileSet describes affected tile coordinates.
Future undo should restore tile deltas instead of replaying vector strokes.
```

Phase 154 adds pure tile delta model foundations.

This phase still must not add UndoService, undo stack, brush rasterization, cache, save/load, or canvas UI.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt id="k2gl3z"
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
-> future Undo stack
-> future FrameCompositeCache invalidation
-> future PlaybackPreviewCache invalidation
```

This phase only creates the model layer for:

```txt id="a0ipyb"
TileDelta
TileDeltaCommand
```

Meaning:

```txt id="75mfa4"
TileDelta
= one tile's before/after bitmap state

TileDeltaCommand
= a set of tile deltas produced by one future drawing/editing operation
```

This is model-only.

## Required references

Before editing, read:

```txt id="an4hko"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
```

Also inspect:

```txt id="o5g2ow"
lib/src/models/tile_coord.dart
lib/src/models/bitmap_tile.dart
lib/src/models/bitmap_surface.dart
lib/src/models/dirty_region.dart
lib/src/models/dirty_tile_set.dart
test/models/tile_coord_test.dart
test/models/bitmap_tile_test.dart
test/models/bitmap_surface_test.dart
test/models/dirty_region_test.dart
test/models/dirty_tile_set_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure Dart tile delta model foundations:

```txt id="cvfxpn"
TileDelta
TileDeltaCommand
```

The goal is to prepare the project for future tile-delta undo/redo without implementing UndoService yet.

## Strong scope rule

Allowed:

```txt id="s5s9yo"
pure Dart model classes
before/after tile state modeling
tile absence modeling for sparse BitmapSurface
copyWith / equality / hashCode / toJson / fromJson
focused model tests
pure applyBefore/applyAfter helpers that return a new BitmapSurface
```

Not allowed:

```txt id="t1yf43"
UndoService
undo stack
redo stack
history manager
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
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Sparse tile absence convention

`BitmapSurface` is sparse.

A tile may be absent from the surface.

Tile absence means:

```txt id="cnykcb"
No BitmapTile is allocated for this TileCoord.
The rendered result should eventually be treated as transparent by future renderer/cache code.
```

Phase 154 must model both existing and absent tile states.

Use `BitmapTile?` for before/after tile state.

```txt id="9h6mdr"
before == null
= the tile did not exist before the operation

after == null
= the tile does not exist after the operation
```

This is important for future operations:

```txt id="g4l436"
created tile:
before = null
after = BitmapTile

removed tile:
before = BitmapTile
after = null

modified tile:
before = BitmapTile
after = BitmapTile
```

Do not introduce a separate transparent tile policy yet.

Do not force fully transparent tiles to be removed in this phase.

That can be a future compaction policy.

## Required production files

### 1. TileDelta

Create:

```txt id="u0a8tr"
lib/src/models/tile_delta.dart
```

Required fields:

```dart id="xs7411"
final TileCoord coord;
final BitmapTile? before;
final BitmapTile? after;
```

Required behavior:

```txt id="1jiiqo"
- immutable model
- coord is required
- before and after may be nullable
- before and after must not both be null
- if before != null, before.coord must equal coord
- if after != null, after.coord must equal coord
- if before != null and after != null, before.size must equal after.size
- if before == after, reject as no-op
- invalid values throw ArgumentError
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Recommended constructor:

```dart id="g9ojd7"
TileDelta({
  required this.coord,
  required this.before,
  required this.after,
})
```

Required factories:

```dart id="f1kmkk"
TileDelta.created(BitmapTile after)

TileDelta.removed(BitmapTile before)

TileDelta.replaced({
  required BitmapTile before,
  required BitmapTile after,
})
```

Factory meanings:

```txt id="pa3yb2"
created:
- coord = after.coord
- before = null
- after = after

removed:
- coord = before.coord
- before = before
- after = null

replaced:
- before.coord must equal after.coord
- coord = before.coord
- before = before
- after = after
```

Required getters:

```dart id="k1tst7"
bool get isCreation
bool get isRemoval
bool get isReplacement
int get tileSize
```

Rules:

```txt id="c8qgvj"
isCreation = before == null && after != null
isRemoval = before != null && after == null
isReplacement = before != null && after != null
tileSize = before?.size ?? after!.size
```

JSON shape:

```json id="fk0soc"
{
  "coord": { "x": 0, "y": 0 },
  "before": null,
  "after": { "...": "BitmapTile json" }
}
```

Do not compress pixel data yet.

Do not introduce binary persistence.

Do not introduce tile delta compression.

### 2. TileDeltaCommand

Create:

```txt id="hp33i9"
lib/src/models/tile_delta_command.dart
```

Required internal data:

```txt id="sri7dv"
A set/map of TileDelta values keyed by TileCoord
```

Long-term design rule:

```txt id="kpa5y8"
TileDeltaCommand is semantically coordinate-keyed.
Insertion order must not affect equality or hashCode.
```

Recommended internal shape:

```dart id="rr02ey"
final Map<TileCoord, TileDelta> _deltasByCoord;
```

Recommended constructor:

```dart id="ypdwvb"
TileDeltaCommand({
  required Iterable<TileDelta> deltas,
})
```

Required validation:

```txt id="aet881"
- deltas must not be empty
- no duplicate TileCoord entries
- each TileDelta.coord becomes its key
- invalid values throw ArgumentError
```

Required public API:

```dart id="gq4qbc"
List<TileDelta> get deltas
DirtyTileSet get dirtyTiles
int get length
bool containsCoord(TileCoord coord)
TileDelta? deltaFor(TileCoord coord)
```

`deltas` getter:

```txt id="8gjp06"
- returns an unmodifiable list
- returns deltas in deterministic order
- recommended order: row-major by coord.y, then coord.x
```

Why deterministic order:

```txt id="wnzsq5"
JSON output and test output should be stable.
But equality/hashCode must still ignore insertion order.
```

Required helpers:

```dart id="keoyqg"
BitmapSurface applyBefore(BitmapSurface surface)
BitmapSurface applyAfter(BitmapSurface surface)
void validateAgainstSurface(BitmapSurface surface)
```

Meaning:

```txt id="h8z5vx"
applyBefore:
- returns a new BitmapSurface where every delta's before state is restored

applyAfter:
- returns a new BitmapSurface where every delta's after state is applied

validateAgainstSurface:
- confirms all delta coords are inside the target surface
- confirms all non-null before/after tile sizes match surface.tileSize
- throws ArgumentError if invalid
```

Apply rules:

```txt id="ogodfc"
For each delta:
- if target tile state is null, removeTile(coord)
- if target tile state is BitmapTile, putTile(tile)
```

Important:

```txt id="6k176s"
applyBefore/applyAfter are pure helpers.
They must return a new BitmapSurface.
They must not mutate the input BitmapSurface.
They are not UndoService.
They are not an undo stack.
They do not know about cache invalidation.
```

Equality/hashCode:

```txt id="jmxq4a"
- equality ignores insertion order
- hashCode ignores insertion order
- use Object.hashAllUnordered or equivalent
```

Recommended hashCode:

```dart id="4xwx6u"
@override
int get hashCode => Object.hashAllUnordered(
  _deltasByCoord.values.map((delta) => Object.hash(delta.coord, delta)),
);
```

or equivalent order-independent strategy.

JSON shape:

```json id="rkjvxr"
{
  "deltas": [
    { "...": "TileDelta json" }
  ]
}
```

`toJson` should emit deltas in deterministic order.

`fromJson` should validate duplicate coords through the constructor.

## Required tests

### 1. TileDelta tests

Create:

```txt id="nrj0no"
test/models/tile_delta_test.dart
```

Required tests:

```txt id="l2mq3p"
created factory creates creation delta
removed factory creates removal delta
replaced factory creates replacement delta
constructor rejects before and after both null
constructor rejects before coord mismatch
constructor rejects after coord mismatch
constructor rejects before/after size mismatch
constructor rejects no-op before == after
isCreation is true only for creation
isRemoval is true only for removal
isReplacement is true only for replacement
tileSize uses after size for creation
tileSize uses before size for removal
tileSize uses before/after size for replacement
copyWith updates coord/before/after and revalidates
equality includes coord, before, and after
hashCode is value-based
toJson/fromJson round-trips creation
toJson/fromJson round-trips removal
toJson/fromJson round-trips replacement
```

Use small tile sizes in tests when possible, such as size 2, to keep test data readable.

### 2. TileDeltaCommand tests

Create:

```txt id="m9al9z"
test/models/tile_delta_command_test.dart
```

Required tests:

```txt id="gv0spw"
constructor stores deltas
constructor rejects empty deltas
constructor rejects duplicate coords
deltas getter is unmodifiable
deltas getter returns deterministic row-major order
dirtyTiles returns DirtyTileSet of delta coords
length returns delta count
containsCoord returns true for existing coord
containsCoord returns false for missing coord
deltaFor returns delta for coord
deltaFor returns null for missing coord
equality ignores insertion order
hashCode ignores insertion order
toJson/fromJson round-trips
toJson emits deterministic delta order
validateAgainstSurface accepts in-bounds matching tileSize deltas
validateAgainstSurface rejects coord outside surface
validateAgainstSurface rejects tile size mismatch
applyAfter creates missing tile
applyBefore removes created tile
applyAfter removes deleted tile
applyBefore restores deleted tile
applyAfter replaces modified tile
applyBefore restores original modified tile
applyBefore/applyAfter do not mutate original surface
```

Important test cases:

### Creation

```txt id="cyjdo8"
before = null
after = BitmapTile(coord: A)
```

`applyAfter(emptySurface)` should insert tile A.

`applyBefore(surfaceWithTileA)` should remove tile A.

### Removal

```txt id="77799r"
before = BitmapTile(coord: A)
after = null
```

`applyAfter(surfaceWithTileA)` should remove tile A.

`applyBefore(emptySurface)` should restore tile A.

### Replacement

```txt id="ex7gyx"
before = BitmapTile(coord: A, pixels old)
after = BitmapTile(coord: A, pixels new)
```

`applyAfter(surfaceWithOldTile)` should produce new tile.

`applyBefore(surfaceWithNewTile)` should restore old tile.

## Architecture rules

Tile delta rules:

```txt id="xhrnyr"
TileDelta models one tile's before/after state.
TileDeltaCommand models one operation's changed tiles.
TileDeltaCommand is coordinate-keyed.
TileDeltaCommand is not an UndoService.
TileDeltaCommand is not an undo stack.
TileDeltaCommand does not own cache invalidation.
TileDeltaCommand does not know about brush rasterization.
```

Bitmap storage boundary:

```txt id="ppvpsm"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand may use BitmapSurface, BitmapTile, TileCoord, and DirtyTileSet.
TileDeltaCommand must not change BitmapSurface semantics.
```

Timeline/storyboard boundary:

```txt id="m1azty"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="tlxs9i"
UndoService
UndoStack
RedoStack
HistoryService
command history manager
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
BitmapTile drawing mutation helpers
dirty region calculation from brush input
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

```txt id="sff9lq"
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
test/models/tile_delta_test.dart
test/models/tile_delta_command_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="u15je7"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="azjb27"
- changed files
- new model files added
- TileDelta fields and validation
- TileDelta creation/removal/replacement semantics
- TileDeltaCommand storage and uniqueness policy
- TileDeltaCommand deterministic deltas order
- confirmation that TileDeltaCommand equality/hashCode ignore insertion order
- confirmation that applyBefore/applyAfter are pure and return new BitmapSurface instances
- confirmation that no UndoService/undo stack was added
- confirmation that no brush rasterizer was added
- confirmation that no BitmapTile drawing mutation helpers were added
- confirmation that no canvas UI was added
- confirmation that no cache/save/load was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 154 is complete when:

```txt id="dqz8yt"
- TileDelta exists and is tested.
- TileDeltaCommand exists and is tested.
- TileDelta can represent creation, removal, and replacement.
- TileDelta rejects invalid/no-op deltas.
- TileDeltaCommand rejects empty command.
- TileDeltaCommand rejects duplicate coords.
- TileDeltaCommand exposes DirtyTileSet of affected coords.
- TileDeltaCommand deltas getter is deterministic.
- TileDeltaCommand equality ignores insertion order.
- TileDeltaCommand hashCode ignores insertion order.
- applyBefore/applyAfter return new BitmapSurface instances.
- applyBefore/applyAfter do not mutate original BitmapSurface.
- Existing Phase 152 BitmapSurface / BitmapTile / TileCoord tests still pass.
- Existing Phase 153 DirtyRegion / DirtyTileSet tests still pass.
- Existing canvas viewport and brush input tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No UndoService / undo stack was added.
- No brush rasterization was added.
- No drawing canvas UI was added.
- No cache / save-load behavior was added.
```

## Manual check list

This phase is model-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="ehxdkp"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
