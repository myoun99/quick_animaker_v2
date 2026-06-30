# Phase 167 Codex Task

## Title

Create multi-tile BitmapSurface brush commit command

## Repository

```txt id="rioav8"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="rfz0w8"
master
```

## Project type

```txt id="c12haq"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 166.

Recent bitmap canvas / brush foundation phases:

```txt id="6tw7sg"
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
```

## Existing surface model facts

`BitmapSurface` already exists.

It stores:

```txt id="sqyxmm"
canvasSize: CanvasSize
tileSize: int
tiles: Map<TileCoord, BitmapTile>
```

It is sparse:

```txt id="9uyfvs"
Missing tile means no stored tile.
For brush commit, missing tile should be treated as transparent blank tile.
```

Important existing APIs:

```txt id="6o7p4n"
surface.tiles
surface.tileColumnCount
surface.tileRowCount
surface.tileCount
surface.containsTileCoord(coord)
surface.tileAt(coord)
surface.putTile(tile)
surface.removeTile(coord)
surface.copyWith(...)
```

`BitmapSurface` itself should not be mutated in this phase.

Existing `TileDeltaCommand` can later apply changes through:

```txt id="mlh5ii"
command.applyAfter(surface)
command.applyBefore(surface)
```

But this phase should only create the command.

## Existing pipeline

The following pieces already exist:

```txt id="62q91t"
BrushDabSequence
-> brushPixelBlendOperationsForDabSequence(...)
-> List<BrushPixelBlendOperation>
```

```txt id="z8ms5r"
BitmapTile + List<BrushPixelBlendOperation>
-> tileDeltaCommandForBitmapTileOperations(...)
-> TileDeltaCommand?
```

```txt id="q4er2q"
BrushDabSequence + one BitmapTile
-> tileDeltaCommandForBrushDabSequenceOnBitmapTile(...)
-> TileDeltaCommand?
```

Phase 167 should add the multi-tile surface-level command builder:

```txt id="4y07pt"
BrushDabSequence + BitmapSurface
-> TileDeltaCommand?
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="cs3p9d"
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
14. CacheInvalidationPlan connection
15. Canvas UI integration
16. Undo/cache/playback integration
17. Save/load/export
```

Current local roadmap:

```txt id="n4kmxb"
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
Phase 168: TileDeltaCommand -> CacheInvalidationPlan connection
```

Phase 167 is the first surface-level brush command builder.

It must remain pure and deterministic.

It must not mutate BitmapSurface.

It must not apply the command automatically.

It must not add canvas UI.

It must not add undo/cache execution.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="zrvscb"
Brush input samples
-> BrushDabSequence
-> BitmapSurface-backed destinationAt
-> BrushPixelBlendOperation list
-> group operations by TileCoord
-> for each tile:
   existing tile or transparent blank tile
   -> updated tile
   -> TileDelta.replaced or TileDelta.created
-> TileDeltaCommand
-> future CacheInvalidationPlan
-> future Undo stack
-> future surface apply
```

This phase only creates:

```txt id="b8zypd"
BrushDabSequence + BitmapSurface -> TileDeltaCommand?
```

Meaning:

```txt id="yvv6bs"
tileDeltaCommandForBrushDabSequenceOnBitmapSurface
= takes an existing BitmapSurface
= takes a BrushDabSequence
= reads destination colors from existing surface tiles
= treats missing tiles as transparent
= ignores pixels outside the surface canvas bounds
= creates one TileDeltaCommand containing all changed tiles
= returns null if nothing changes
```

This is not actual surface mutation.

This is not cache invalidation.

This is not undo execution.

This is not canvas UI.

## Required references

Before editing, read:

```txt id="d3i4tw"
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
```

Also inspect:

```txt id="q0pmx0"
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
lib/src/models/rgba_color.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/brush_pixel_blend_operation.dart
lib/src/services/bitmap_tile_rgba.dart
lib/src/services/brush_dab_sequence_blend.dart
lib/src/services/bitmap_tile_operation_delta.dart
lib/src/services/bitmap_tile_brush_commit.dart
test/models/bitmap_surface_test.dart
test/models/tile_delta_test.dart
test/models/tile_delta_command_test.dart
test/services/bitmap_tile_operation_delta_test.dart
test/services/bitmap_tile_brush_commit_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure surface-level brush command service:

```dart id="rbplqc"
TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
})
```

The goal is to prepare for future actual brush commit while keeping this phase command-only and testable.

## Strong scope rule

Allowed:

```txt id="0r9s6k"
pure Dart service
BrushDabSequence + BitmapSurface -> TileDeltaCommand?
surface-backed DestinationPixelReader
missing-tile-as-transparent behavior
operation grouping by TileCoord
TileDelta.replaced for existing changed tiles
TileDelta.created for missing changed tiles
focused service tests
```

Not allowed:

```txt id="2qw9l0"
mutating BitmapSurface
automatically applying TileDeltaCommand
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

```txt id="uj7vhd"
lib/src/services/bitmap_surface_brush_commit.dart
```

Required public function:

```dart id="m5j21a"
TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
})
```

## Required behavior

The function should:

```txt id="m2nxb7"
1. Build a DestinationPixelReader backed by the BitmapSurface.
2. Generate operations using brushPixelBlendOperationsForDabSequence.
3. Ignore operations outside the surface canvas bounds.
4. Group in-bounds operations by TileCoord.
5. For each affected TileCoord:
   - if the surface has an existing tile, use it
   - if the surface has no tile, create a transparent blank BitmapTile for that coord
   - pass that tile and that tile's operations to tileDeltaCommandForBitmapTileOperations
6. Convert each per-tile result into a TileDelta:
   - existing tile changed -> use replacement delta from the returned command
   - missing tile changed -> use TileDelta.created(afterTile)
7. If no deltas are produced, return null.
8. Otherwise return TileDeltaCommand(deltas: deltas).
```

Important:

```txt id="pp5w38"
Do not mutate the BitmapSurface.
Do not call command.applyAfter inside this service.
Do not call surface.putTile inside this service.
Do not call surface.removeTile inside this service.
```

This service should create a command only.

## DestinationPixelReader behavior

For global pixel x/y:

```txt id="ichkts"
If x < 0 or y < 0:
  return transparent

If x >= surface.canvasSize.width or y >= surface.canvasSize.height:
  return transparent

Else:
  tileX = x ~/ surface.tileSize
  tileY = y ~/ surface.tileSize
  coord = TileCoord(x: tileX, y: tileY)
  localX = x - tileX * surface.tileSize
  localY = y - tileY * surface.tileSize

  if surface.tileAt(coord) exists:
    return readRgbaColorFromBitmapTile(tile: tile, x: localX, y: localY)

  if surface.tileAt(coord) is null:
    return transparent
```

Do not throw for out-of-surface destination reads.

Reason:

```txt id="q8n742"
Dabs can cross canvas edges.
Outside pixels should simply not produce surface deltas.
```

## Operation grouping behavior

After generating operations:

```txt id="z5gv71"
Ignore operations outside the surface canvas bounds.
Group remaining operations by TileCoord.
```

Use the same global-to-tile mapping:

```txt id="oed3l7"
tileX = operation.x ~/ surface.tileSize
tileY = operation.y ~/ surface.tileSize
coord = TileCoord(x: tileX, y: tileY)
```

Only do this after checking:

```txt id="dv8zkf"
0 <= operation.x < surface.canvasSize.width
0 <= operation.y < surface.canvasSize.height
```

This avoids invalid negative tile coordinates.

## Existing tile behavior

If `surface.tileAt(coord)` returns a tile:

```txt id="jfp0kw"
- pass that tile to tileDeltaCommandForBitmapTileOperations
- if command is null, no delta for that coord
- if command is non-null, take its single replacement delta
```

The resulting delta should be:

```txt id="rsyvr5"
TileDelta.replaced(before: existingTile, after: updatedTile)
```

Do not create a blank tile for existing tiles.

## Missing tile behavior

If `surface.tileAt(coord)` is null:

```txt id="3naxmy"
- create blank tile:
  BitmapTile.blank(coord: coord, size: surface.tileSize)
- pass that blank tile to tileDeltaCommandForBitmapTileOperations
- if command is null, no delta for that coord
- if command is non-null:
    take the after tile from the returned replacement delta
    create TileDelta.created(afterTile)
```

Important:

```txt id="c92i0b"
For missing tiles, do not keep TileDelta.replaced(before: blankTile, after: updatedTile).
Use TileDelta.created(afterTile).
```

Reason:

```txt id="45d3a9"
The surface did not originally store a tile.
Undo/applyBefore should remove the created tile, not leave a transparent blank tile behind.
```

## No-op behavior

Return null when:

```txt id="fqnfk6"
sequence is empty
sequence has only non-effective dabs
all affected pixels are outside the surface
all operations produce no actual tile changes
```

Reason:

```txt id="t7sviy"
TileDeltaCommand cannot be empty.
No-op command should be represented by null.
```

## Error behavior

If a downstream service throws:

```txt id="0aw9o4"
let the error propagate
```

Do not hide errors.

In normal use, before mismatch should not occur because operations are generated from the same surface-backed destinationAt.

## Determinism

For stable tests and easier debugging:

```txt id="ztllpq"
Process grouped tile coords in row-major order:
first coord.y ascending,
then coord.x ascending.
```

`TileDeltaCommand` may already sort internally, but this service should still avoid relying on map insertion order when practical.

## Required tests

Create:

```txt id="c6s4vc"
test/services/bitmap_surface_brush_commit_test.dart
```

Required tests:

```txt id="ziggf7"
returns null for empty BrushDabSequence
returns null for non-effective dab
returns null when dab affects only pixels outside surface
creates replacement delta for existing tile
creates creation delta for missing tile
does not create replacement delta with blank before for missing tile
command contains multiple deltas for multi-tile dab
respects existing destination color on existing tile
treats missing tile destination as transparent
ignores pixels outside canvas bounds
does not mutate original BitmapSurface
does not mutate existing BitmapTile
applyAfter produces expected surface
applyBefore restores original surface
preserves surface tileSize expectations through deltas
groups deltas deterministically by tile coord
does not mutate BrushDabSequence
does not mutate BrushDab
```

## Suggested helpers

Suggested colors:

```dart id="o7q2sd"
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
final purple = RgbaColor(r: 128, g: 0, b: 128, a: 255);
```

Suggested surface helper:

```dart id="xnx92z"
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

Suggested blank tile helper:

```dart id="iwhc7i"
BitmapTile blankTile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested one-pixel dab helper:

```dart id="g0lz9q"
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

```dart id="t036fd"
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

```txt id="9ipiwg"
surface = 4x4 canvas, tileSize 2
sequence = BrushDabSequence()

expected:
null
```

### Existing tile replacement

```txt id="n7r107"
surface has tile at TileCoord(0,0)
dab affects global pixel (1,0)

expected:
TileDeltaCommand length == 1
delta.isReplacement == true
delta.before == existing tile
delta.after local pixel (1,0) == red
```

### Missing tile creation

```txt id="fv9skm"
surface has no tile at TileCoord(1,0)
dab affects global pixel (2,0)

expected:
TileDeltaCommand length == 1
delta.isCreation == true
delta.before == null
delta.after.coord == TileCoord(1,0)
delta.after local pixel (0,0) == red
```

### Missing tile should not be replacement from blank

```txt id="tyh743"
surface has no tile at TileCoord(1,0)
dab affects global pixel (2,0)

expected:
delta.isCreation == true
delta.isReplacement == false
```

### Existing destination color

```txt id="ttiy42"
existing tile local pixel (0,0) = blue
dab affects global pixel (0,0)
dab color = red
dab opacity = 0.5

expected after pixel:
RgbaColor(r: 128, g: 0, b: 128, a: 255)
```

### Missing tile destination color

```txt id="uq9tn8"
missing tile treated as transparent
dab affects global pixel in missing tile
red opacity 1

expected after pixel:
red
```

### Multi-tile dab

```txt id="o7f31u"
surface 4x4, tileSize 2
square dab crosses boundary between tile (0,0) and tile (1,0)

expected:
command has deltas for both TileCoord(0,0) and TileCoord(1,0)
```

### Outside canvas ignored

```txt id="3g3vja"
surface width = 2, height = 2, tileSize = 2
dab affects global pixel (3,0)

expected:
null
```

### Apply/undo round trip

```txt id="isf5ik"
command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(...)
afterSurface = command.applyAfter(surface)
restoredSurface = command.applyBefore(afterSurface)

expected:
restoredSurface == surface
```

## Architecture rules

Surface brush commit rules:

```txt id="lmrbjz"
bitmap_surface_brush_commit.dart may know about BitmapSurface.
bitmap_surface_brush_commit.dart may know about BitmapTile.
bitmap_surface_brush_commit.dart may know about TileCoord.
bitmap_surface_brush_commit.dart may know about TileDelta.
bitmap_surface_brush_commit.dart may know about TileDeltaCommand.
bitmap_surface_brush_commit.dart may know about BrushDabSequence.
bitmap_surface_brush_commit.dart may call readRgbaColorFromBitmapTile.
bitmap_surface_brush_commit.dart may call brushPixelBlendOperationsForDabSequence.
bitmap_surface_brush_commit.dart may call tileDeltaCommandForBitmapTileOperations.
bitmap_surface_brush_commit.dart may create BitmapTile.blank for missing affected tiles.
bitmap_surface_brush_commit.dart may create TileDelta.created for missing changed tiles.
bitmap_surface_brush_commit.dart may create TileDeltaCommand from collected deltas.
bitmap_surface_brush_commit.dart must not mutate BitmapSurface.
bitmap_surface_brush_commit.dart must not call surface.putTile.
bitmap_surface_brush_commit.dart must not call surface.removeTile.
bitmap_surface_brush_commit.dart must not call command.applyAfter.
bitmap_surface_brush_commit.dart must not call command.applyBefore.
bitmap_surface_brush_commit.dart must not generate CacheInvalidationPlan.
bitmap_surface_brush_commit.dart must not implement undo.
bitmap_surface_brush_commit.dart must not add UI.
```

Bitmap storage boundary:

```txt id="060f82"
BitmapSurface remains sparse bitmap storage.
Missing BitmapTile means transparent empty tile.
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

```txt id="hyl0d1"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="mmu3x2"
actual surface mutation
automatic command application
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
timeline changes
storyboard changes
```

## Expected changed files

Likely:

```txt id="shvc9l"
lib/src/services/bitmap_surface_brush_commit.dart
test/services/bitmap_surface_brush_commit_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="j4fc7f"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="37nr07"
- changed files
- tileDeltaCommandForBrushDabSequenceOnBitmapSurface behavior
- surface-backed destinationAt behavior
- missing tile as transparent behavior
- existing tile replacement behavior
- missing tile creation behavior
- multi-tile delta behavior
- outside canvas ignore behavior
- command applyAfter/applyBefore compatibility
- original surface immutability behavior
- existing tile immutability behavior
- confirmation that no BitmapSurface mutation was added
- confirmation that no automatic command application was added
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

Phase 167 is complete when:

```txt id="cedlxo"
- bitmap_surface_brush_commit.dart exists and is tested.
- tileDeltaCommandForBrushDabSequenceOnBitmapSurface returns null for empty sequence.
- returns null for non-effective dab.
- returns null when all affected pixels are outside the surface.
- creates replacement delta for an existing changed tile.
- creates creation delta for a missing changed tile.
- missing changed tile is not represented as replacement from blank tile.
- command can contain multiple deltas for a multi-tile dab.
- existing tile destination color is respected.
- missing tile destination is treated as transparent.
- pixels outside canvas bounds are ignored.
- original BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- command.applyAfter(surface) produces expected updated surface.
- command.applyBefore(updatedSurface) restores the original surface.
- deltas are deterministic by tile coord.
- BrushDabSequence is not mutated.
- BrushDab is not mutated.
- Existing one-tile brush commit tests still pass.
- Existing BitmapTile operation delta tests still pass.
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
- No automatic BitmapSurface mutation was added.
- No cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="h6lszw"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
