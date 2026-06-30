# Phase 159 Codex Task

## Title

RGBA source-over blend foundation

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

QuickAnimaker v2 is complete through Phase 158.

Recent bitmap canvas / brush foundation phases:

```txt
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
Phase 158: BrushDab.color snapshot / RgbaColor foundation
```

## Long-term roadmap

The project is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA pixel math foundation
6. BitmapBrushRasterizer
7. Brush stroke commit pipeline
8. Canvas UI integration
9. Undo/cache/playback integration
10. Save/load/export
```

Current local roadmap:

```txt
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: Single BrushDab raster coverage foundation
Phase 161: BrushDabSequence -> BitmapTile update prototype
Phase 162: BitmapTile before/after -> TileDeltaCommand connection
Phase 163: Brush stroke commit pipeline draft
```

Phase 159 adds pure RGBA source-over blending logic.

This phase must not add pixel rasterization, BitmapTile mutation, BitmapSurface mutation, brush rasterizer, DirtyRegion logic changes, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future brush rasterization should eventually flow like this:

```txt
BrushDab.color
-> RgbaColor.fromArgbInt(...)
-> effective source alpha from BrushDab opacity / flow
-> source-over blend against destination pixel
-> future BitmapBrushRasterizer writes RGBA8888 bytes
```

This phase only creates pure color blending logic.

Meaning:

```txt
RgbaColor
= RGBA component value object

RgbaBlend
= pure source-over blend logic for combining source and destination RgbaColor values
```

This is service-only / pure math only.

## Required references

Before editing, read:

```txt
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
```

Also inspect:

```txt
lib/src/models/rgba_color.dart
lib/src/models/brush_dab.dart
lib/src/models/bitmap_tile.dart
test/models/rgba_color_test.dart
test/models/brush_dab_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure RGBA source-over blend foundation:

```txt
rgbaSourceOver
effectiveSourceAlpha
```

The goal is to prepare the project for future bitmap brush rasterization while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt
pure Dart color blending service
straight-alpha source-over math
opacity / flow effective alpha calculation
RgbaColor input/output
focused service tests
```

Not allowed:

```txt
BitmapBrushRasterizer
pixel rasterization
pixel blending into BitmapTile bytes
BitmapTile pixel mutation
BitmapSurface mutation
DirtyRegion logic changes
DirtyTileSet logic changes
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

## Alpha convention

`RgbaColor` stores straight RGBA components:

```txt
r: 0..255
g: 0..255
b: 0..255
a: 0..255
```

`BrushDab.opacity` and `BrushDab.flow` are separate multipliers:

```txt
0.0 <= opacity <= 1.0
0.0 <= flow <= 1.0
```

Effective source alpha:

```txt
effectiveSourceAlpha = (source.a / 255.0) * opacity * flow
```

Destination alpha:

```txt
destinationAlpha = destination.a / 255.0
```

Source-over output alpha:

```txt
outAlpha = effectiveSourceAlpha + destinationAlpha * (1.0 - effectiveSourceAlpha)
```

Source-over output RGB:

```txt
if outAlpha == 0:
  outR = 0
  outG = 0
  outB = 0
else:
  outR = (source.r * effectiveSourceAlpha
          + destination.r * destinationAlpha * (1.0 - effectiveSourceAlpha))
         / outAlpha

  outG = (source.g * effectiveSourceAlpha
          + destination.g * destinationAlpha * (1.0 - effectiveSourceAlpha))
         / outAlpha

  outB = (source.b * effectiveSourceAlpha
          + destination.b * destinationAlpha * (1.0 - effectiveSourceAlpha))
         / outAlpha
```

Convert output alpha back to byte:

```txt
outA = round(outAlpha * 255)
```

Convert output RGB back to byte:

```txt
outR = round(outR)
outG = round(outG)
outB = round(outB)
```

Clamp every output component to 0..255.

## Required production file

Create:

```txt
lib/src/services/rgba_blend.dart
```

Required public functions:

```dart
double effectiveSourceAlpha({
  required RgbaColor source,
  required double opacity,
  required double flow,
})

RgbaColor rgbaSourceOver({
  required RgbaColor source,
  required RgbaColor destination,
  required double opacity,
  required double flow,
})
```

### `effectiveSourceAlpha`

Rules:

```txt
- source is required
- opacity must be finite and 0..1
- flow must be finite and 0..1
- invalid opacity / flow throws ArgumentError
- returns (source.a / 255.0) * opacity * flow
```

### `rgbaSourceOver`

Rules:

```txt
- source is required
- destination is required
- opacity must be finite and 0..1
- flow must be finite and 0..1
- invalid opacity / flow throws ArgumentError
- uses straight-alpha source-over formula
- returns a new RgbaColor
- does not mutate anything
```

Optimization rules are allowed but not required.

Allowed early returns:

```txt
if source.a == 0:
  return destination

if opacity == 0:
  return destination

if flow == 0:
  return destination
```

Important:

```txt
Even with early returns, still validate opacity and flow first.
```

Do not add blend modes yet.

Do not add multiply/screen/additive modes yet.

Do not add brush hardness behavior here.

Do not add tip shape behavior here.

Do not access BitmapTile.

Do not access BrushDab directly in this phase.

Reason:

```txt
This phase should keep color blending independent from brush geometry.
Future rasterizer will combine BrushDab geometry with this RGBA blend service.
```

## Required tests

Create:

```txt
test/services/rgba_blend_test.dart
```

Required tests:

```txt
effectiveSourceAlpha returns source alpha multiplied by opacity and flow
effectiveSourceAlpha returns 0 for transparent source
effectiveSourceAlpha returns 0 when opacity is 0
effectiveSourceAlpha returns 0 when flow is 0
effectiveSourceAlpha rejects negative opacity
effectiveSourceAlpha rejects opacity above 1
effectiveSourceAlpha rejects non-finite opacity
effectiveSourceAlpha rejects negative flow
effectiveSourceAlpha rejects flow above 1
effectiveSourceAlpha rejects non-finite flow

rgbaSourceOver returns destination when source alpha is 0
rgbaSourceOver returns destination when opacity is 0
rgbaSourceOver returns destination when flow is 0
rgbaSourceOver blends opaque source over transparent destination
rgbaSourceOver blends half-alpha source over transparent destination
rgbaSourceOver blends half-alpha source over opaque destination
rgbaSourceOver preserves fully transparent result as 0,0,0,0
rgbaSourceOver rejects invalid opacity
rgbaSourceOver rejects invalid flow
rgbaSourceOver clamps rounded component values to 0..255
rgbaSourceOver returns a new RgbaColor value
```

Suggested examples:

### Opaque red over transparent

```txt
source = RgbaColor(r: 255, g: 0, b: 0, a: 255)
destination = RgbaColor(r: 0, g: 0, b: 0, a: 0)
opacity = 1
flow = 1

expected = RgbaColor(r: 255, g: 0, b: 0, a: 255)
```

### Half-alpha red over transparent

```txt
source = RgbaColor(r: 255, g: 0, b: 0, a: 128)
destination = RgbaColor(r: 0, g: 0, b: 0, a: 0)
opacity = 1
flow = 1

effectiveSourceAlpha = 128 / 255
outAlpha = 128 / 255
outRgb = source rgb

expected = RgbaColor(r: 255, g: 0, b: 0, a: 128)
```

### Half-alpha red over opaque blue

```txt
source = RgbaColor(r: 255, g: 0, b: 0, a: 128)
destination = RgbaColor(r: 0, g: 0, b: 255, a: 255)
opacity = 1
flow = 1

expected approximate:
RgbaColor(r: 128, g: 0, b: 127, a: 255)
```

Exact expected may depend on rounding. Use the formula in this task and assert exact values produced by that formula.

### Opacity multiplier

```txt
source.a = 255
opacity = 0.5
flow = 1

effectiveSourceAlpha = 0.5
```

### Flow multiplier

```txt
source.a = 255
opacity = 1
flow = 0.5

effectiveSourceAlpha = 0.5
```

## Architecture rules

Color blend rules:

```txt
rgba_blend.dart is pure math.
rgba_blend.dart does not know about BitmapTile.
rgba_blend.dart does not know about BitmapSurface.
rgba_blend.dart does not know about BrushDab geometry.
rgba_blend.dart does not know about DirtyRegion.
rgba_blend.dart does not create TileDeltaCommand.
rgba_blend.dart does not invalidate cache.
```

Bitmap storage boundary:

```txt
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
BrushDabSequence remains ordered planned brush stamp data.
RgbaColor remains RGBA component value object.
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
BitmapBrushRasterizer
pixel rasterization
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

```txt
lib/src/services/rgba_blend.dart
test/services/rgba_blend_test.dart
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
- new service file added
- effectiveSourceAlpha validation and formula
- rgbaSourceOver validation and formula
- source-over alpha behavior
- opacity / flow multiplier behavior
- rounding and clamping behavior
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
- confirmation that no BitmapSurface mutation was added
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

Phase 159 is complete when:

```txt
- rgba_blend.dart exists and is tested.
- effectiveSourceAlpha correctly applies source alpha, opacity, and flow.
- effectiveSourceAlpha rejects invalid opacity / flow.
- rgbaSourceOver performs straight-alpha source-over blending.
- rgbaSourceOver rejects invalid opacity / flow.
- rgbaSourceOver returns RgbaColor values.
- Existing RgbaColor tests still pass.
- Existing BrushDab / BrushDabPlacement tests still pass.
- Existing BrushDab dirty region tests still pass.
- Existing bitmap / dirty region / tile delta / cache invalidation tests still pass.
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

```txt
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
