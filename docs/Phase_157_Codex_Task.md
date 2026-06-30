# Phase 157 Codex Task

## Title

BrushDab dirty region / dirty tile derivation foundation

## Repository

```txt id="g3a8g7"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="yhjw7l"
master
```

## Project type

```txt id="ecx8qk"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 156.

Recent bitmap canvas / brush foundation phases:

```txt id="ciqben"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
```

Current long-term direction:

```txt id="m70u2t"
QuickAnimaker v2 is bitmap-first.
Brush input becomes BrushDabSequence.
BrushDabSequence should eventually be rasterized into BitmapTile pixel data.
Before rasterization, the engine needs to know what pixel regions and tile coords are affected.
DirtyRegion and DirtyTileSet should be derivable from BrushDabSequence.
TileDeltaCommand should eventually record before/after tile changes.
CacheInvalidationPlan should eventually describe affected cache keys.
```

Phase 157 connects BrushDabSequence to DirtyRegion / DirtyTileSet, but still does not rasterize pixels.

This phase must not add pixel rasterization, BitmapTile mutation, BitmapSurface mutation, TileDeltaCommand generation, cache invalidation generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt id="kx93ww"
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> BrushDabPlacement
-> BrushDabSequence
-> BrushDab dirty region derivation
-> future BitmapBrushRasterizer
-> future BitmapTile updates
-> future TileDeltaCommand
-> future CacheInvalidationPlan
```

This phase only creates a pure service for deriving dirty regions and dirty tiles from brush dabs.

Meaning:

```txt id="l09baf"
BrushDab dirty region
= conservative integer pixel rectangle touched by one dab

BrushDabSequence dirty region
= union of all effective dab dirty regions

BrushDabSequence dirty tile set
= set of TileCoord values touched by effective dab dirty regions
```

This is pure service logic only.

## Required references

Before editing, read:

```txt id="ah4hwc"
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
```

Also inspect:

```txt id="si5v3t"
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/services/brush_dab_placement.dart
lib/src/models/dirty_region.dart
lib/src/models/dirty_tile_set.dart
lib/src/models/tile_coord.dart
test/models/brush_dab_test.dart
test/models/brush_dab_sequence_test.dart
test/services/brush_dab_placement_test.dart
test/models/dirty_region_test.dart
test/models/dirty_tile_set_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BrushDab dirty derivation foundations:

```txt id="mj631r"
dirtyRegionForBrushDab
dirtyRegionsForBrushDabSequence
dirtyRegionForBrushDabSequence
dirtyTileSetForBrushDabSequence
```

The goal is to prepare the project for future bitmap brush rasterization without touching pixel storage yet.

## Strong scope rule

Allowed:

```txt id="b4w3xx"
pure Dart service functions
BrushDab -> conservative DirtyRegion calculation
BrushDabSequence -> DirtyRegion union calculation
BrushDabSequence -> DirtyTileSet calculation
focused service tests
dart:math floor/ceil-style integer bounds
```

Not allowed:

```txt id="xo3xlj"
BitmapBrushRasterizer
pixel rasterization
pixel blending
BitmapTile pixel mutation
BitmapSurface mutation
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

## Coordinate and bounds convention

BrushDab centers are canvas-space coordinates.

DirtyRegion uses integer pixel bounds:

```txt id="v2dfqu"
left
top
rightExclusive
bottomExclusive
```

Use exclusive-right / exclusive-bottom bounds.

For one effective BrushDab:

```txt id="wh9926"
radius = dab.size / 2.0

left = floor(dab.center.x - radius)
top = floor(dab.center.y - radius)
rightExclusive = ceil(dab.center.x + radius)
bottomExclusive = ceil(dab.center.y + radius)
```

Because `DirtyRegion` currently requires non-negative coordinates, clamp only the minimum left/top bounds to 0:

```txt id="ixl0zr"
left = max(0, floor(dab.center.x - radius))
top = max(0, floor(dab.center.y - radius))
```

If the computed region has no positive area after this, return null.

Important:

```txt id="l8m9o4"
Do not introduce negative DirtyRegion coordinates in this phase.
Do not introduce infinite canvas behavior in this phase.
Do not clip to BitmapSurface bounds in this phase.
Do not require BitmapSurface as input.
```

## Effective dab rule

A dab should be considered non-effective if it cannot change pixels later.

A BrushDab should produce no dirty region when:

```txt id="gq1lvb"
dab.size == 0
dab.opacity == 0
dab.flow == 0
```

Return `null` for non-effective dabs.

Do not skip based on `pressure` alone.

Reason:

```txt id="b66c1d"
BrushDab already stores effective size and effective opacity.
If pressure is 0 but pressureSize/pressureOpacity were not enabled, the dab may still have non-zero size/opacity.
```

## Conservative bounds rule

For this phase, both round and square tips may use the same conservative bounding rectangle.

Do not try to calculate exact round-pixel coverage yet.

Reason:

```txt id="ndyx6q"
Dirty region derivation should be safe and conservative.
Exact coverage belongs to the future BitmapBrushRasterizer.
```

## Required production file

Create:

```txt id="a9wtbi"
lib/src/services/brush_dab_dirty_region.dart
```

Required public functions:

```dart id="rm6hmy"
DirtyRegion? dirtyRegionForBrushDab(BrushDab dab)

List<DirtyRegion> dirtyRegionsForBrushDabSequence(
  BrushDabSequence sequence,
)

DirtyRegion? dirtyRegionForBrushDabSequence(
  BrushDabSequence sequence,
)

DirtyTileSet dirtyTileSetForBrushDabSequence({
  required BrushDabSequence sequence,
  required int tileSize,
})
```

### `dirtyRegionForBrushDab`

Rules:

```txt id="w3l776"
- returns null for zero-size dab
- returns null for zero-opacity dab
- returns null for zero-flow dab
- otherwise returns conservative DirtyRegion using floor/ceil bounds
- clamps left/top to 0 because DirtyRegion is non-negative in current architecture
- does not use BitmapSurface
- does not mutate anything
```

### `dirtyRegionsForBrushDabSequence`

Rules:

```txt id="x7s8e5"
- returns one DirtyRegion per effective dab
- skips non-effective dabs
- preserves dab order in the returned list
- returns an unmodifiable list if practical
- does not union regions
```

### `dirtyRegionForBrushDabSequence`

Rules:

```txt id="o4v2m7"
- returns null for empty sequence
- returns null when all dabs are non-effective
- otherwise returns union of effective dab regions
- uses DirtyRegion.union
```

### `dirtyTileSetForBrushDabSequence`

Rules:

```txt id="c9ln5u"
- tileSize > 0
- throws ArgumentError for tileSize <= 0
- returns DirtyTileSet.empty() for empty sequence
- returns DirtyTileSet.empty() when all dabs are non-effective
- derives tile coords from each effective dab region
- merges tile coords into DirtyTileSet
```

Important precision rule:

```txt id="rsz35l"
Do not derive dirty tiles only from the single union DirtyRegion.
Instead, derive tile coords per dab region and merge them.
```

Reason:

```txt id="d674j9"
Using only one large union region can over-invalidate many tiles between separated dabs.
Per-dab tile derivation is more precise and better for future performance.
```

## Required tests

Create:

```txt id="xrg9ix"
test/services/brush_dab_dirty_region_test.dart
```

Required tests:

```txt id="uvvalf"
dirtyRegionForBrushDab returns null for zero size
dirtyRegionForBrushDab returns null for zero opacity
dirtyRegionForBrushDab returns null for zero flow
dirtyRegionForBrushDab creates conservative bounds for integer center and even size
dirtyRegionForBrushDab creates conservative bounds for fractional center
dirtyRegionForBrushDab clamps left/top to zero
dirtyRegionForBrushDab uses same conservative bounds for round and square tips
dirtyRegionsForBrushDabSequence returns one region per effective dab
dirtyRegionsForBrushDabSequence skips non-effective dabs
dirtyRegionsForBrushDabSequence preserves dab order
dirtyRegionForBrushDabSequence returns null for empty sequence
dirtyRegionForBrushDabSequence returns null when all dabs are non-effective
dirtyRegionForBrushDabSequence returns one dab region for one effective dab
dirtyRegionForBrushDabSequence unions multiple effective dab regions
dirtyTileSetForBrushDabSequence returns empty set for empty sequence
dirtyTileSetForBrushDabSequence returns empty set when all dabs are non-effective
dirtyTileSetForBrushDabSequence derives tile coords per dab region
dirtyTileSetForBrushDabSequence merges duplicate tile coords
dirtyTileSetForBrushDabSequence rejects zero tileSize
dirtyTileSetForBrushDabSequence rejects negative tileSize
service does not mutate BrushDabSequence
```

Suggested helper in tests:

```dart id="suahg5"
BrushDab dab({
  double x = 10,
  double y = 10,
  double size = 4,
  double opacity = 1,
  double flow = 1,
  BrushTipShape tipShape = BrushTipShape.round,
  int sequence = 0,
})
```

Suggested bounds examples:

```txt id="gm5b68"
center = (10, 10), size = 4
radius = 2
DirtyRegion(left: 8, top: 8, rightExclusive: 12, bottomExclusive: 12)

center = (10.5, 10.5), size = 3
radius = 1.5
left = floor(9.0) = 9
top = floor(9.0) = 9
rightExclusive = ceil(12.0) = 12
bottomExclusive = ceil(12.0) = 12

center = (1, 1), size = 4
radius = 2
raw left/top = -1
clamped left/top = 0
rightExclusive = 3
bottomExclusive = 3
```

Suggested per-dab tile precision test:

```txt id="d3jg3c"
tileSize = 10

dab A:
center = (1, 1), size = 2
touches tile (0, 0)

dab B:
center = (101, 1), size = 2
touches tile (10, 0)

dirtyTileSetForBrushDabSequence should contain:
TileCoord(0, 0)
TileCoord(10, 0)

It should not include all tiles between them.
```

This verifies that dirty tile derivation is per-dab, not from one huge union region.

## Architecture rules

Brush dirty derivation rules:

```txt id="r5a9hn"
BrushDab dirty region derivation is not rasterization.
DirtyRegion is conservative affected bounds.
DirtyTileSet is affected tile coords.
This service must not inspect or modify BitmapTile pixels.
This service must not inspect or modify BitmapSurface.
This service must not create TileDeltaCommand.
This service must not create CacheInvalidationPlan.
This service must not know about UI.
```

Bitmap storage boundary:

```txt id="ks8iya"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
```

Timeline/storyboard boundary:

```txt id="o2u0x4"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="sp0jrg"
BitmapBrushRasterizer
pixel rasterization
pixel blending
BitmapTile mutation helpers for drawing
BitmapSurface drawing helpers
TileDeltaCommand generation from dabs
CacheInvalidationPlan generation from dabs
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

```txt id="my2sd6"
lib/src/services/brush_dab_dirty_region.dart
test/services/brush_dab_dirty_region_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="uo8sj2"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="lhmtvv"
- changed files
- new service file added
- dirtyRegionForBrushDab effective dab rules
- conservative bounds formula
- left/top non-negative clamp behavior
- dirtyRegionForBrushDabSequence union behavior
- dirtyTileSetForBrushDabSequence per-dab tile derivation behavior
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
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

Phase 157 is complete when:

```txt id="vxnj2z"
- brush_dab_dirty_region.dart exists and is tested.
- dirtyRegionForBrushDab returns conservative DirtyRegion for effective dabs.
- dirtyRegionForBrushDab returns null for zero-size / zero-opacity / zero-flow dabs.
- dirtyRegionsForBrushDabSequence preserves effective dab order.
- dirtyRegionForBrushDabSequence unions effective dab regions.
- dirtyTileSetForBrushDabSequence derives tile coords per dab region.
- dirtyTileSetForBrushDabSequence avoids unnecessary over-invalidation from one huge union region.
- Existing Phase 152 BitmapSurface / BitmapTile / TileCoord tests still pass.
- Existing Phase 153 DirtyRegion / DirtyTileSet tests still pass.
- Existing Phase 154 TileDelta / TileDeltaCommand tests still pass.
- Existing Phase 155 CacheInvalidationPlan/key tests still pass.
- Existing Phase 156 BrushDab / BrushDabPlacement tests still pass.
- Existing canvas viewport and brush input tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No pixel rasterization was added.
- No drawing canvas UI was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="a5z490"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
