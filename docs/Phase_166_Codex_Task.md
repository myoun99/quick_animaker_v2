# Phase 166 Codex Task

## Title

Create one-tile brush dab sequence commit pipeline

## Repository

```txt id="dthar1"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="xxkm1l"
master
```

## Project type

```txt id="mbtcwy"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 165.

Recent bitmap canvas / brush foundation phases:

```txt id="opjyal"
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
```

## Existing pipeline

The following pieces already exist:

```txt id="9mg8go"
BrushDabSequence
-> brushPixelBlendOperationsForDabSequence(...)
-> List<BrushPixelBlendOperation>
```

```txt id="myml50"
BitmapTile + List<BrushPixelBlendOperation>
-> applyBrushPixelBlendOperationsToBitmapTile(...)
-> updated BitmapTile
```

```txt id="e08qvl"
BitmapTile + List<BrushPixelBlendOperation>
-> tileDeltaCommandForBitmapTileOperations(...)
-> TileDeltaCommand?
```

Phase 166 should connect these pieces into one one-tile brush commit pipeline:

```txt id="1ui7l8"
BrushDabSequence + BitmapTile
-> BrushPixelBlendOperation list
-> TileDeltaCommand?
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="kpf5os"
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
14. BitmapBrushRasterizer
15. Canvas UI integration
16. Undo/cache/playback integration
17. Save/load/export
```

Current local roadmap:

```txt id="vkvskc"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: BrushPixelBlendOperation list -> BitmapTile updated copy
Phase 165: BitmapTile + BrushPixelBlendOperation list -> TileDeltaCommand?
Phase 166: BrushDabSequence + BitmapTile -> TileDeltaCommand?
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
```

Phase 166 is a one-tile commit pipeline draft.

It must stay pure and deterministic.

It must not mutate BitmapSurface.

It must not add multi-tile surface processing.

It must not add actual canvas UI.

It must not add undo/cache execution.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="hm5me5"
Brush input samples
-> BrushDabSequence
-> dirty tiles
-> for each BitmapTile:
   BrushDabSequence + BitmapTile
   -> TileDeltaCommand?
-> merge tile deltas
-> BitmapSurface apply
-> CacheInvalidationPlan
-> Undo stack
```

This phase only creates the **single BitmapTile** part:

```txt id="czykrw"
BrushDabSequence + one BitmapTile -> TileDeltaCommand?
```

Meaning:

```txt id="bo8nvn"
tileDeltaCommandForBrushDabSequenceOnBitmapTile
= takes an existing BitmapTile
= takes a BrushDabSequence
= reads destination colors from that tile for pixels inside that tile
= generates BrushPixelBlendOperation list using existing Phase 162 service
= wraps result using existing Phase 165 service
= returns null if this tile does not change
```

This is not full brush rasterization.

This is not BitmapSurface mutation.

This is not multi-tile commit.

This is not undo/cache integration.

## Required references

Before editing, read:

```txt id="qdt6te"
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
```

Also inspect:

```txt id="76llsp"
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
lib/src/models/rgba_color.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/brush_pixel_blend_operation.dart
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
lib/src/services/bitmap_tile_rgba.dart
lib/src/services/brush_dab_sequence_blend.dart
lib/src/services/bitmap_tile_operation_apply.dart
lib/src/services/bitmap_tile_operation_delta.dart
test/services/brush_dab_sequence_blend_test.dart
test/services/bitmap_tile_rgba_test.dart
test/services/bitmap_tile_operation_apply_test.dart
test/services/bitmap_tile_operation_delta_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure one-tile brush commit service:

```dart id="ba01as"
TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapTile({
  required BitmapTile tile,
  required BrushDabSequence sequence,
})
```

The goal is to prepare for future multi-tile surface commit while keeping this phase one-tile-only and testable.

## Strong scope rule

Allowed:

```txt id="h0gdp1"
pure Dart service
BrushDabSequence + BitmapTile -> TileDeltaCommand?
destinationAt callback backed by one BitmapTile
reuse brushPixelBlendOperationsForDabSequence
reuse readRgbaColorFromBitmapTile
reuse tileDeltaCommandForBitmapTileOperations
focused service tests
```

Not allowed:

```txt id="fbo15m"
BitmapBrushRasterizer
BitmapSurface mutation
BitmapSurface helper
multi-tile surface commit
DirtyTileSet traversal
TileDeltaCommand merging
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

```txt id="p21gi7"
lib/src/services/bitmap_tile_brush_commit.dart
```

Required public function:

```dart id="kzef69"
TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapTile({
  required BitmapTile tile,
  required BrushDabSequence sequence,
})
```

## Required behavior

The function should:

```txt id="6i1zmx"
1. Build a DestinationPixelReader backed by the given BitmapTile.
2. Use brushPixelBlendOperationsForDabSequence(
     sequence: sequence,
     destinationAt: destinationAt,
   )
3. Pass those operations to tileDeltaCommandForBitmapTileOperations(
     tile: tile,
     operations: operations,
   )
4. Return the resulting TileDeltaCommand?
```

Important:

```txt id="o5tcla"
Do not manually blend BrushDab pixels in this service.
Do not manually apply BrushPixelBlendOperation items to BitmapTile in this service.
Do not manually create TileDelta or TileDeltaCommand in this service.
Reuse the existing Phase 162 and Phase 165 services.
```

Reason:

```txt id="piqpd9"
Phase 162 owns BrushDabSequence -> BrushPixelBlendOperation.
Phase 164 owns applying operations to BitmapTile.
Phase 165 owns wrapping updated tile into TileDeltaCommand.
Phase 166 should only connect these stages.
```

## DestinationPixelReader behavior

`BrushDabSequence` uses global canvas pixel coordinates.

`BitmapTile` has tile coordinates:

```txt id="qmtaac"
tile.coord.x
tile.coord.y
tile.size
```

For a tile:

```txt id="yk8znp"
tileGlobalLeft = tile.coord.x * tile.size
tileGlobalTop = tile.coord.y * tile.size
tileGlobalRightExclusive = tileGlobalLeft + tile.size
tileGlobalBottomExclusive = tileGlobalTop + tile.size
```

For destinationAt(x, y):

```txt id="v832rd"
If x/y are inside this tile:
  localX = x - tileGlobalLeft
  localY = y - tileGlobalTop
  return readRgbaColorFromBitmapTile(tile: tile, x: localX, y: localY)

If x/y are outside this tile:
  return transparent RgbaColor(r: 0, g: 0, b: 0, a: 0)
```

Why outside returns transparent:

```txt id="0thnkk"
This phase processes one tile only.
Operations outside this tile will be ignored by Phase 165.
Returning transparent lets BrushDabSequence operation generation remain total and non-throwing for dabs that cross tile boundaries.
The later multi-tile BitmapSurface phase will provide real tile-backed destination colors across all affected tiles.
```

Do not throw for outside-tile destinationAt reads in this phase.

## No-op behavior

Return `null` when:

```txt id="retqdg"
sequence is empty
sequence has only non-effective dabs
all generated operations are outside this tile
all generated operations result in no tile change
```

Reason:

```txt id="z5hwno"
TileDeltaCommand cannot be empty.
Phase 165 represents no-op as null.
```

## Error behavior

If a downstream service throws:

```txt id="kkkan1"
let the error propagate
```

Do not hide errors.

In normal use, before mismatch should not occur because operations are generated from this same tile's destination colors.

## Required tests

Create:

```txt id="4gwiwy"
test/services/bitmap_tile_brush_commit_test.dart
```

Required tests:

```txt id="ttfsoh"
returns null for empty BrushDabSequence
returns null for non-effective dab
returns null when dab affects only pixels outside tile
returns TileDeltaCommand for one-pixel dab over transparent tile
command contains exactly one replacement delta
delta before is original tile
delta after contains brushed pixel
does not mutate original tile
respects existing destination color inside tile
maps global dab coordinates to local tile pixels
does not treat global dab coordinates as local tile coordinates
handles repeated same-pixel dabs using accumulated operation colors
handles dab crossing tile boundary by applying only in-tile pixel changes
preserves updated tile coord
preserves updated tile size
does not mutate BrushDabSequence
does not mutate BrushDab
```

## Suggested helpers

Suggested colors:

```dart id="bi6ql6"
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
final purple = RgbaColor(r: 128, g: 0, b: 128, a: 255);
```

Suggested tile helper:

```dart id="azr38j"
BitmapTile blankTile({
  int tileX = 0,
  int tileY = 0,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested one-pixel dab helper:

```dart id="ksr4mm"
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

This dab should affect pixel:

```txt id="43miw1"
x = globalX
y = globalY
```

Suggested square dab helper for boundary tests:

```dart id="v0akkg"
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

```txt id="cmsye8"
tile = blank 2x2 tile
sequence = BrushDabSequence()

expected:
null
```

### One pixel over transparent tile

```txt id="5qu5a1"
tile.coord = TileCoord(x: 0, y: 0)
tile.size = 2
dab affects global pixel (1, 0)
destination pixel = transparent
dab color = opaque red

expected:
TileDeltaCommand
delta.isReplacement == true
delta.before == original tile
delta.after local pixel (1,0) == red
```

### Existing destination color is respected

```txt id="kvu7gs"
tile local pixel (0,0) = blue
dab affects global pixel (0,0)
dab color = opaque red
dab opacity = 0.5

expected after pixel:
RgbaColor(r: 128, g: 0, b: 128, a: 255)
```

This confirms that destinationAt reads from the tile, not from transparent.

### Global to local mapping

```txt id="5bgere"
tile.coord = TileCoord(x: 2, y: 3)
tile.size = 4

tile global origin:
x = 8
y = 12

dab affects global pixel (8, 12)

expected:
updated tile local pixel (0,0) changed
```

### Global coordinates are not local coordinates

```txt id="j8r7l5"
tile.coord = TileCoord(x: 2, y: 3)
tile.size = 4
dab affects global pixel (8, 12)

This should be valid because it maps to local (0,0).
It must not be rejected as x >= tile.size.
```

### Repeated same-pixel dabs

```txt id="avq7x3"
dab 1:
global pixel (0,0)
color red
opacity 1

dab 2:
global pixel (0,0)
color blue
opacity 0.5

expected final pixel:
purple RgbaColor(r: 128, g: 0, b: 128, a: 255)
```

This confirms Phase 162 accumulation is used.

### Boundary crossing dab

```txt id="wcipll"
tile.coord = TileCoord(x: 0, y: 0)
tile.size = 2

square dab centered near right boundary so it covers:
inside pixels: x=1
outside pixels: x=2

expected:
only inside tile pixels are changed in returned delta.after
outside pixels are ignored by tile delta logic
```

## Architecture rules

One-tile brush commit rules:

```txt id="v4kira"
bitmap_tile_brush_commit.dart may know about BitmapTile.
bitmap_tile_brush_commit.dart may know about BrushDabSequence.
bitmap_tile_brush_commit.dart may know about RgbaColor.
bitmap_tile_brush_commit.dart may know about TileDeltaCommand.
bitmap_tile_brush_commit.dart may call readRgbaColorFromBitmapTile.
bitmap_tile_brush_commit.dart may call brushPixelBlendOperationsForDabSequence.
bitmap_tile_brush_commit.dart may call tileDeltaCommandForBitmapTileOperations.
bitmap_tile_brush_commit.dart must not know about BitmapSurface.
bitmap_tile_brush_commit.dart must not create TileDelta directly.
bitmap_tile_brush_commit.dart must not manually apply BrushPixelBlendOperation items.
bitmap_tile_brush_commit.dart must not manually blend pixels.
bitmap_tile_brush_commit.dart must not manually write BitmapTile bytes.
bitmap_tile_brush_commit.dart must not generate CacheInvalidationPlan.
bitmap_tile_brush_commit.dart must not implement undo.
bitmap_tile_brush_commit.dart must not add UI.
```

Bitmap storage boundary:

```txt id="1n1b73"
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

```txt id="kikvay"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="2m4fui"
BitmapSurface commit
multi-tile processing
DirtyTileSet traversal
TileDeltaCommand merging
BitmapBrushRasterizer
actual drawing canvas
pointer event handling
tablet input
gesture handling
CustomPainter changes
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
save/load
persistence service
tile upload
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

```txt id="6pjcqq"
lib/src/services/bitmap_tile_brush_commit.dart
test/services/bitmap_tile_brush_commit_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="tj2h4i"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="ltoh20"
- changed files
- tileDeltaCommandForBrushDabSequenceOnBitmapTile behavior
- destinationAt behavior for in-tile pixels
- destinationAt behavior for outside-tile pixels
- BrushDabSequence -> operation list reuse behavior
- operation list -> TileDeltaCommand reuse behavior
- no-op null behavior
- existing destination color behavior
- repeated same-pixel dab accumulation behavior
- boundary crossing behavior
- original tile immutability behavior
- updated tile coord/size preservation
- confirmation that no BitmapSurface mutation was added
- confirmation that no multi-tile processing was added
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no manual pixel blending was added
- confirmation that no manual BitmapTile byte writing was added
- confirmation that no TileDelta was manually created
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

Phase 166 is complete when:

```txt id="jdgd9l"
- bitmap_tile_brush_commit.dart exists and is tested.
- tileDeltaCommandForBrushDabSequenceOnBitmapTile returns null for empty sequence.
- tileDeltaCommandForBrushDabSequenceOnBitmapTile returns null for non-effective dab.
- tileDeltaCommandForBrushDabSequenceOnBitmapTile returns null when dab affects only pixels outside the tile.
- A one-pixel dab over a transparent tile returns a TileDeltaCommand.
- The command contains exactly one replacement delta.
- The delta.before is the original tile.
- The delta.after contains the brushed pixel.
- The original BitmapTile is not mutated.
- Existing destination colors inside the tile are respected.
- Global dab coordinates are mapped to local tile pixels.
- Global dab coordinates are not treated as local tile coordinates.
- Repeated same-pixel dabs use accumulated operation colors.
- Dabs crossing tile boundaries apply only in-tile changes.
- Updated tile coord is preserved.
- Updated tile size is preserved.
- BrushDabSequence is not mutated.
- BrushDab is not mutated.
- brushPixelBlendOperationsForDabSequence is reused.
- tileDeltaCommandForBitmapTileOperations is reused.
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
- No BitmapSurface mutation was added.
- No multi-tile processing was added.
- No cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="okagvs"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
