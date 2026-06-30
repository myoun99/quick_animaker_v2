# Phase 160 Codex Task

## Title

BrushDab pixel coverage foundation

## Repository

```txt id="dbz0pa"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="xnh9ur"
master
```

## Project type

```txt id="ihup2s"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 159.

Recent bitmap canvas / brush foundation phases:

```txt id="msaecr"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
Phase 158: BrushDab.color snapshot / RgbaColor foundation
Phase 159: RGBA source-over blend foundation
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="xdoyqu"
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA color and blend math foundation
6. BrushDab pixel coverage foundation
7. BitmapBrushRasterizer
8. Brush stroke commit pipeline
9. Canvas UI integration
10. Undo/cache/playback integration
11. Save/load/export
```

Current local roadmap:

```txt id="u3lxut"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: Single BrushDab -> pixel coverage foundation
Phase 161: Single BrushDab + destination pixel -> blended pixel result
Phase 162: BrushDabSequence -> affected pixel operations
Phase 163: BitmapTile write prototype
Phase 164: BitmapTile before/after -> TileDeltaCommand connection
Phase 165: Brush stroke commit pipeline draft
```

Phase 160 adds pure BrushDab pixel coverage calculation.

This phase must not add BitmapTile mutation, BitmapSurface mutation, real rasterization, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future brush rasterization should eventually flow like this:

```txt id="m2lf3u"
BrushDab
-> dirtyRegionForBrushDab(...)
-> brushPixelCoveragesForDab(...)
-> future rgbaSourceOver(...)
-> future BitmapBrushRasterizer
-> future BitmapTile RGBA8888 writes
```

This phase only creates pixel coverage planning.

Meaning:

```txt id="qx2e16"
BrushPixelCoverage
= one integer pixel coordinate plus a coverage value from 0.0 to 1.0

brushPixelCoveragesForDab
= pure function that returns which pixels a BrushDab may affect and how strongly
```

This is pure geometry/math only.

## Required references

Before editing, read:

```txt id="v53bik"
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
```

Also inspect:

```txt id="ht9nse"
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/brush_tip_shape.dart
lib/src/models/dirty_region.dart
lib/src/services/brush_dab_dirty_region.dart
lib/src/models/rgba_color.dart
lib/src/services/rgba_blend.dart
test/models/brush_dab_test.dart
test/services/brush_dab_dirty_region_test.dart
test/services/rgba_blend_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BrushDab pixel coverage foundation:

```txt id="xpa2oq"
BrushPixelCoverage
brushPixelCoveragesForDab
```

The goal is to prepare for future BitmapBrushRasterizer while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt id="pjqun7"
pure Dart model
pure Dart service
BrushDab -> pixel coverage list
round tip coverage
square tip coverage
hardness-based round tip falloff
focused model/service tests
```

Not allowed:

```txt id="xmr56p"
BitmapBrushRasterizer
pixel writes
BitmapTile byte mutation
BitmapSurface mutation
rgbaSourceOver integration
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

## Pixel coordinate convention

Use integer pixel coordinates:

```txt id="c0da26"
x: int
y: int
```

Pixel center convention:

```txt id="zfbhoj"
pixelCenterX = x + 0.5
pixelCenterY = y + 0.5
```

All pixel coordinates are non-negative in this phase.

Do not introduce negative pixel coordinates.

Do not introduce infinite canvas behavior in this phase.

## Coverage convention

Coverage is a double:

```txt id="1yx8av"
0.0 <= coverage <= 1.0
```

Meaning:

```txt id="5220zm"
coverage = 0.0 means the pixel is not affected
coverage = 1.0 means full geometric coverage
```

This phase does not combine coverage with color, opacity, flow, or source-over blending.

Future phases will combine:

```txt id="v2fz8h"
coverage
BrushDab.color
BrushDab.opacity
BrushDab.flow
rgbaSourceOver
```

## Required production files

### 1. BrushPixelCoverage

Create:

```txt id="cya8pe"
lib/src/models/brush_pixel_coverage.dart
```

Required fields:

```dart id="ng1z2a"
final int x;
final int y;
final double coverage;
```

Required validation:

```txt id="b4p7w3"
x >= 0
y >= 0
coverage is finite
0.0 <= coverage <= 1.0
invalid values throw ArgumentError
```

Required behavior:

```txt id="0l8irh"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Do not include color here.

Do not include opacity here.

Do not include flow here.

Reason:

```txt id="uk2h9b"
BrushPixelCoverage should describe geometry only.
Color and alpha blending are separate concerns.
```

### 2. BrushDab coverage service

Create:

```txt id="x42z0o"
lib/src/services/brush_dab_coverage.dart
```

Required public function:

```dart id="uebhgl"
List<BrushPixelCoverage> brushPixelCoveragesForDab(BrushDab dab)
```

Rules:

```txt id="ysjmdi"
- returns an unmodifiable list if practical
- returns an empty list for non-effective dabs
- uses dirtyRegionForBrushDab(dab) as the conservative pixel bounds
- iterates pixels row-major: y ascending, then x ascending
- does not mutate anything
- does not access BitmapTile
- does not access BitmapSurface
- does not call rgbaSourceOver
```

Non-effective dab rule:

Use the existing `dirtyRegionForBrushDab(dab)` result.

```txt id="s22vud"
if dirtyRegionForBrushDab(dab) returns null:
  return empty list
```

This means zero-size / zero-opacity / zero-flow dabs produce no pixel coverage.

## Tip shape behavior

### Square tip

For `BrushTipShape.square`:

```txt id="ijwxlk"
Every pixel inside the conservative DirtyRegion gets coverage 1.0.
```

Use row-major ordering.

### Round tip

For `BrushTipShape.round`:

Use the pixel center distance from the dab center:

```txt id="eulfy8"
dx = pixelCenterX - dab.center.x
dy = pixelCenterY - dab.center.y
distance = sqrt(dx * dx + dy * dy)
radius = dab.size / 2.0
```

If:

```txt id="hfdkpb"
distance > radius
```

then skip that pixel.

If:

```txt id="0hv3mq"
distance <= radius
```

then compute coverage using hardness.

## Hardness behavior for round tip

Use this deterministic falloff:

```txt id="rerflw"
hardRadius = radius * dab.hardness
```

If:

```txt id="i01k54"
distance <= hardRadius
```

then:

```txt id="pon2n7"
coverage = 1.0
```

Otherwise:

```txt id="u68yap"
edgeSpan = radius - hardRadius

if edgeSpan <= 0:
  coverage = 1.0
else:
  coverage = 1.0 - ((distance - hardRadius) / edgeSpan)
```

Clamp coverage to 0.0..1.0.

Skip pixels with coverage <= 0.0.

Important:

```txt id="risbr0"
dab.hardness == 1.0 gives a hard round brush.
dab.hardness == 0.0 gives a fully soft radial falloff.
```

## Important boundaries

This phase must not decide final color.

This phase must not decide final alpha.

This phase must not blend with destination pixels.

This phase must not write to BitmapTile bytes.

This phase must not create TileDeltaCommand.

This phase must not invalidate cache.

## Required tests

### 1. BrushPixelCoverage tests

Create:

```txt id="zwruyb"
test/models/brush_pixel_coverage_test.dart
```

Required tests:

```txt id="qcw44y"
creates with valid values
allows coverage 0
allows coverage 1
rejects negative x
rejects negative y
rejects negative coverage
rejects coverage above 1
rejects non-finite coverage
copyWith updates x
copyWith updates y
copyWith updates coverage
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
toString includes useful data
```

### 2. BrushDab coverage tests

Create:

```txt id="tr15mx"
test/services/brush_dab_coverage_test.dart
```

Required tests:

```txt id="dmys4t"
returns empty list for zero-size dab
returns empty list for zero-opacity dab
returns empty list for zero-flow dab
square tip covers all pixels in dirty region with coverage 1
square tip returns pixels in row-major order
round hard tip skips pixels outside radius
round hard tip gives coverage 1 inside radius
round soft tip gives lower coverage near edge
round hardness 1 produces hard coverage
round hardness 0 produces radial falloff
fractional center uses pixel center convention
coverage values are clamped to 0..1
returns unmodifiable list if practical
does not mutate BrushDab
does not access BitmapTile or BitmapSurface
```

Suggested helper:

```dart id="tqrb21"
BrushDab dab({
  double x = 10,
  double y = 10,
  double size = 4,
  double opacity = 1,
  double flow = 1,
  double hardness = 1,
  BrushTipShape tipShape = BrushTipShape.round,
  int sequence = 0,
})
```

Use:

```txt id="p7nc69"
color = 0xFF000000
pressure = 1
```

for helper-created dabs.

## Suggested examples

### Square tip example

```txt id="9s5wap"
center = (1, 1)
size = 2
radius = 1

DirtyRegion:
left = 0
top = 0
rightExclusive = 2
bottomExclusive = 2

Square tip coverage should include:
(0,0)
(1,0)
(0,1)
(1,1)

all coverage = 1.0
```

### Row-major example

```txt id="bnwcbg"
Expected order:
(0,0)
(1,0)
(0,1)
(1,1)
```

### Round hard tip example

```txt id="a5l9xx"
center = (1, 1)
size = 2
radius = 1
hardness = 1

Pixel centers:
(0,0) -> center (0.5,0.5), distance ~0.707 -> covered
(1,0) -> center (1.5,0.5), distance ~0.707 -> covered
(0,1) -> center (0.5,1.5), distance ~0.707 -> covered
(1,1) -> center (1.5,1.5), distance ~0.707 -> covered

all coverage = 1.0
```

### Round skip outside example

```txt id="n3fqc3"
center = (1, 1)
size = 1
radius = 0.5

Pixel center (0.5,0.5) distance ~0.707
This is outside radius, so it should be skipped.
```

### Soft edge example

```txt id="pjokcl"
center = (10, 10)
size = 4
radius = 2
hardness = 0.5
hardRadius = 1

Pixel center near center should have coverage 1.0.
Pixel center near outer radius should have coverage between 0.0 and 1.0.
```

Do not assert fragile floating-point values unless using `closeTo`.

## Architecture rules

Brush coverage rules:

```txt id="367w4t"
BrushPixelCoverage is geometry only.
brush_dab_coverage.dart does not know about BitmapTile.
brush_dab_coverage.dart does not know about BitmapSurface.
brush_dab_coverage.dart does not call rgbaSourceOver.
brush_dab_coverage.dart does not create TileDeltaCommand.
brush_dab_coverage.dart does not invalidate cache.
```

Bitmap storage boundary:

```txt id="aq4lcv"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
RgbaColor remains RGBA component value object.
rgba_blend.dart remains pure source-over color math.
```

Timeline/storyboard boundary:

```txt id="rrdic0"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="cotdfh"
BitmapBrushRasterizer
pixel rasterization into BitmapTile
pixel blending into BitmapTile bytes
BitmapTile mutation helpers for drawing
BitmapSurface drawing helpers
DirtyRegion generation changes
DirtyTileSet generation changes
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

```txt id="yua6b1"
lib/src/models/brush_pixel_coverage.dart
lib/src/services/brush_dab_coverage.dart
test/models/brush_pixel_coverage_test.dart
test/services/brush_dab_coverage_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="wubwrw"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="n5ezg8"
- changed files
- BrushPixelCoverage fields and validation
- square tip coverage behavior
- round tip coverage behavior
- hardness falloff behavior
- row-major ordering behavior
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no rgbaSourceOver integration was added
- confirmation that no DirtyRegion logic changes were added
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

Phase 160 is complete when:

```txt id="oe6xun"
- BrushPixelCoverage exists and is tested.
- brushPixelCoveragesForDab exists and is tested.
- zero-size / zero-opacity / zero-flow dabs return empty coverage.
- square tips cover every pixel inside DirtyRegion with coverage 1.0.
- round tips skip pixels outside radius.
- round hard tips return coverage 1.0 inside radius.
- round soft tips return falloff coverage near edges.
- pixel output is row-major.
- coverage values stay in 0.0..1.0.
- Existing BrushDab / BrushDabPlacement tests still pass.
- Existing BrushDab dirty region tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No pixel writes were added.
- No drawing canvas UI was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
```

## Manual check list

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="ao85k3"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
