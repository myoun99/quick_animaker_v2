# Phase 161 Codex Task

## Title

BrushDab pixel blend foundation

## Repository

```txt id="bi385r"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="hqjsy9"
master
```

## Project type

```txt id="6svd8c"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 160.

Recent bitmap canvas / brush foundation phases:

```txt id="yy4dbk"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
Phase 158: BrushDab.color snapshot / RgbaColor foundation
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab pixel coverage foundation
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="bnm0gq"
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA color and source-over blend math foundation
6. BrushDab pixel coverage foundation
7. BrushDab pixel blend foundation
8. BitmapBrushRasterizer
9. Brush stroke commit pipeline
10. Canvas UI integration
11. Undo/cache/playback integration
12. Save/load/export
```

Current local roadmap:

```txt id="mnwo6z"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> pixel blend operations
Phase 163: BitmapTile read/write helper foundation
Phase 164: BrushDabSequence -> BitmapTile update prototype
Phase 165: BitmapTile before/after -> TileDeltaCommand connection
Phase 166: Brush stroke commit pipeline draft
```

Phase 161 connects three existing foundations:

```txt id="2zk1kk"
BrushDab.color
BrushPixelCoverage.coverage
rgbaSourceOver(...)
```

This phase must remain pure math/service logic.

This phase must not add BitmapTile mutation, BitmapSurface mutation, real rasterization, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future brush rasterization should eventually flow like this:

```txt id="7yd6ki"
BrushDab
-> brushPixelCoveragesForDab(...)
-> BrushPixelCoverage
-> blendBrushDabPixelCoverage(...)
-> future BitmapBrushRasterizer
-> future BitmapTile RGBA8888 writes
```

This phase only creates one-pixel blend logic.

Meaning:

```txt id="mgl7kz"
BrushPixelCoverage
= geometry coverage for one pixel

RgbaColor destination
= current pixel color before brush application

BrushDab
= brush color / opacity / flow snapshot

blendBrushDabPixelCoverage
= output RgbaColor after applying the dab coverage over the destination pixel
```

This is not tile writing.

This is not rasterization into a bitmap.

This is pure color math using existing models.

## Required references

Before editing, read:

```txt id="9kig72"
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
```

Also inspect:

```txt id="y61q4t"
lib/src/models/brush_dab.dart
lib/src/models/brush_pixel_coverage.dart
lib/src/models/rgba_color.dart
lib/src/services/rgba_blend.dart
lib/src/services/brush_dab_coverage.dart
test/models/brush_pixel_coverage_test.dart
test/services/rgba_blend_test.dart
test/services/brush_dab_coverage_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BrushDab pixel blend foundation:

```txt id="ad1dte"
effectiveBrushPixelOpacity
blendBrushDabPixelCoverage
```

The goal is to prepare for future BitmapBrushRasterizer while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt id="uae8fh"
pure Dart service
BrushDab + BrushPixelCoverage + RgbaColor -> RgbaColor
coverage multiplier
BrushDab.color -> RgbaColor.fromArgbInt
rgbaSourceOver integration
focused service tests
```

Not allowed:

```txt id="5x2yrl"
BitmapBrushRasterizer
pixel writes
BitmapTile byte mutation
BitmapSurface mutation
BrushDabSequence rasterization
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

## Blend convention

Existing Phase 159 function:

```dart id="ubl1zo"
RgbaColor rgbaSourceOver({
  required RgbaColor source,
  required RgbaColor destination,
  required double opacity,
  required double flow,
})
```

Existing Phase 160 model:

```dart id="lx1c56"
BrushPixelCoverage(
  x: int,
  y: int,
  coverage: double,
)
```

Phase 161 should combine coverage like this:

```txt id="deflbo"
effectiveBrushPixelOpacity = dab.opacity * coverage.coverage
```

Then call:

```txt id="enpr7w"
rgbaSourceOver(
  source: RgbaColor.fromArgbInt(dab.color),
  destination: destination,
  opacity: effectiveBrushPixelOpacity,
  flow: dab.flow,
)
```

Reason:

```txt id="6br9gv"
coverage is geometric coverage.
opacity is brush setting opacity.
flow is brush setting flow.
source alpha is embedded in dab.color.
```

So final effective source alpha inside `rgbaSourceOver` becomes:

```txt id="y88gr6"
(source.a / 255.0) * dab.opacity * coverage.coverage * dab.flow
```

Do not multiply coverage into both opacity and flow.

Do not ignore coverage.

Do not ignore dab.color alpha.

## Required production file

Create:

```txt id="ls6qxr"
lib/src/services/brush_pixel_blend.dart
```

Required public functions:

```dart id="bkiybg"
double effectiveBrushPixelOpacity({
  required BrushDab dab,
  required BrushPixelCoverage coverage,
})

RgbaColor blendBrushDabPixelCoverage({
  required BrushDab dab,
  required BrushPixelCoverage coverage,
  required RgbaColor destination,
})
```

### effectiveBrushPixelOpacity

Rules:

```txt id="5ecipz"
- returns dab.opacity * coverage.coverage
- result should be between 0.0 and 1.0
- no extra clamping should be necessary because BrushDab and BrushPixelCoverage already validate their values
- do not mutate anything
```

### blendBrushDabPixelCoverage

Rules:

```txt id="2jyv46"
- source color is RgbaColor.fromArgbInt(dab.color)
- destination is passed in as RgbaColor
- opacity passed to rgbaSourceOver is effectiveBrushPixelOpacity(...)
- flow passed to rgbaSourceOver is dab.flow
- returns a new RgbaColor value from rgbaSourceOver
- does not mutate anything
```

Allowed early returns:

```txt id="9h2urr"
if coverage.coverage == 0:
  return destination
```

But this is optional.

Important:

```txt id="slf8wz"
Do not manually reimplement source-over blending here.
Use rgbaSourceOver from Phase 159.
```

Do not access BitmapTile.

Do not access BitmapSurface.

Do not call brushPixelCoveragesForDab.

Do not process BrushDabSequence.

This phase is for one dab + one pixel coverage + one destination color only.

## Required tests

Create:

```txt id="btyzo1"
test/services/brush_pixel_blend_test.dart
```

Required tests:

```txt id="7vzdp0"
effectiveBrushPixelOpacity multiplies dab opacity by coverage
effectiveBrushPixelOpacity returns 0 when dab opacity is 0
effectiveBrushPixelOpacity returns 0 when coverage is 0
effectiveBrushPixelOpacity returns 1 when dab opacity and coverage are both 1

blendBrushDabPixelCoverage uses dab.color as source color
blendBrushDabPixelCoverage respects dab color alpha
blendBrushDabPixelCoverage respects dab opacity
blendBrushDabPixelCoverage respects dab flow
blendBrushDabPixelCoverage respects pixel coverage
blendBrushDabPixelCoverage returns destination when coverage is 0
blendBrushDabPixelCoverage returns destination when dab opacity is 0
blendBrushDabPixelCoverage returns destination when dab flow is 0
blendBrushDabPixelCoverage blends over transparent destination
blendBrushDabPixelCoverage blends over opaque destination
blendBrushDabPixelCoverage does not mutate BrushDab
blendBrushDabPixelCoverage does not mutate BrushPixelCoverage
blendBrushDabPixelCoverage does not mutate destination RgbaColor
```

Suggested helper:

```dart id="kxjj8p"
BrushDab dab({
  int color = 0xFFFF0000,
  double opacity = 1,
  double flow = 1,
})
```

Use:

```txt id="3ogjlf"
center = CanvasPoint(x: 0, y: 0)
size = 1
hardness = 1
tipShape = BrushTipShape.round
pressure = 1
sequence = 0
```

Suggested coverage helper:

```dart id="hjzt2t"
BrushPixelCoverage pixelCoverage({
  int x = 0,
  int y = 0,
  double coverage = 1,
})
```

## Suggested examples

### Opaque red over transparent with full coverage

```txt id="k9b1u7"
dab.color = 0xFFFF0000
dab.opacity = 1
dab.flow = 1
coverage.coverage = 1
destination = RgbaColor(r: 0, g: 0, b: 0, a: 0)

expected = RgbaColor(r: 255, g: 0, b: 0, a: 255)
```

### Opaque red over transparent with half coverage

```txt id="3hbw16"
dab.color = 0xFFFF0000
dab.opacity = 1
dab.flow = 1
coverage.coverage = 0.5
destination = RgbaColor(r: 0, g: 0, b: 0, a: 0)

effective alpha = 1.0 * 1.0 * 0.5 * 1.0
expected = RgbaColor(r: 255, g: 0, b: 0, a: 128)
```

### Half-alpha red over transparent with full coverage

```txt id="6ojs4x"
dab.color = 0x80FF0000
dab.opacity = 1
dab.flow = 1
coverage.coverage = 1
destination = RgbaColor(r: 0, g: 0, b: 0, a: 0)

expected = RgbaColor(r: 255, g: 0, b: 0, a: 128)
```

### Opaque red with opacity 0.5 over transparent

```txt id="ueo8r6"
dab.color = 0xFFFF0000
dab.opacity = 0.5
dab.flow = 1
coverage.coverage = 1

expected = RgbaColor(r: 255, g: 0, b: 0, a: 128)
```

### Opaque red with flow 0.5 over transparent

```txt id="7htykh"
dab.color = 0xFFFF0000
dab.opacity = 1
dab.flow = 0.5
coverage.coverage = 1

expected = RgbaColor(r: 255, g: 0, b: 0, a: 128)
```

### Half coverage over opaque blue

```txt id="qbjdjy"
dab.color = 0xFFFF0000
dab.opacity = 1
dab.flow = 1
coverage.coverage = 0.5
destination = RgbaColor(r: 0, g: 0, b: 255, a: 255)

expected = RgbaColor(r: 128, g: 0, b: 127, a: 255)
```

## Architecture rules

Brush pixel blend rules:

```txt id="ztsb37"
brush_pixel_blend.dart may know about BrushDab.
brush_pixel_blend.dart may know about BrushPixelCoverage.
brush_pixel_blend.dart may know about RgbaColor.
brush_pixel_blend.dart may call rgbaSourceOver.
brush_pixel_blend.dart must not know about BitmapTile.
brush_pixel_blend.dart must not know about BitmapSurface.
brush_pixel_blend.dart must not create TileDeltaCommand.
brush_pixel_blend.dart must not invalidate cache.
```

Bitmap storage boundary:

```txt id="hdyy5d"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
BrushPixelCoverage remains geometry coverage data.
RgbaColor remains RGBA component value object.
rgba_blend.dart remains pure source-over color math.
```

Timeline/storyboard boundary:

```txt id="w1tkyj"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="azbvau"
BitmapBrushRasterizer
pixel rasterization into BitmapTile
pixel blending into BitmapTile bytes
BitmapTile mutation helpers for drawing
BitmapSurface drawing helpers
BrushDabSequence processing
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

```txt id="zkkq3j"
lib/src/services/brush_pixel_blend.dart
test/services/brush_pixel_blend_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="rds4xf"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="s5so2i"
- changed files
- effectiveBrushPixelOpacity behavior
- blendBrushDabPixelCoverage behavior
- dab.color -> RgbaColor.fromArgbInt behavior
- coverage multiplier behavior
- opacity / flow behavior
- confirmation that rgbaSourceOver is reused instead of reimplementing blend math
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no BrushDabSequence processing was added
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

Phase 161 is complete when:

```txt id="yxl4ax"
- brush_pixel_blend.dart exists and is tested.
- effectiveBrushPixelOpacity returns dab.opacity * coverage.coverage.
- blendBrushDabPixelCoverage converts dab.color through RgbaColor.fromArgbInt.
- blendBrushDabPixelCoverage combines dab opacity, pixel coverage, dab flow, source color alpha, and destination color through rgbaSourceOver.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing BrushDab / BrushDabPlacement tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No pixel writes were added.
- No BitmapTile / BitmapSurface mutation was added.
- No TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="ti0d46"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
