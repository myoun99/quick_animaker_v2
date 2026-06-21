# Phase 162 Codex Task

## Title

BrushDabSequence pixel blend operation foundation

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

QuickAnimaker v2 is complete through Phase 161.

Recent bitmap canvas / brush foundation phases:

```txt
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
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt
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

```txt
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile read/write helper foundation
Phase 164: BrushDabSequence -> BitmapTile update prototype
Phase 165: BitmapTile before/after -> TileDeltaCommand connection
Phase 166: Brush stroke commit pipeline draft
```

Phase 162 connects previous foundations into ordered per-pixel operations:

```txt
BrushDabSequence
-> brushPixelCoveragesForDab(...)
-> blendBrushDabPixelCoverage(...)
-> BrushPixelBlendOperation list
```

This phase must remain pure model/service logic.

This phase must not add BitmapTile mutation, BitmapSurface mutation, real rasterization, TileDeltaCommand generation, cache generation, canvas UI, undo, renderer, save/load, or playback.

## What structure this phase should create

Future brush rasterization should eventually flow like this:

```txt
BrushDabSequence
-> brushPixelBlendOperationsForDabSequence(...)
-> future BitmapTile writer
-> future TileDeltaCommand
-> future CacheInvalidationPlan
```

This phase only creates operation planning.

Meaning:

```txt
BrushPixelBlendOperation
= one pixel coordinate plus before/after RgbaColor

DestinationPixelReader
= callback that provides the current destination color for a pixel

brushPixelBlendOperationsForDabSequence
= pure function that applies dabs in order and returns pixel before/after operations
```

This is not tile writing.

This is not bitmap rasterization.

This is not undo generation.

This is pure operation planning using existing services.

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
docs/Phase_159_Codex_Task.md
docs/Phase_160_Codex_Task.md
docs/Phase_161_Codex_Task.md
```

Also inspect:

```txt
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/brush_pixel_coverage.dart
lib/src/models/rgba_color.dart
lib/src/services/brush_dab_coverage.dart
lib/src/services/brush_pixel_blend.dart
lib/src/services/rgba_blend.dart
test/services/brush_dab_coverage_test.dart
test/services/brush_pixel_blend_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add pure BrushDabSequence pixel operation foundation:

```txt
BrushPixelBlendOperation
DestinationPixelReader
brushPixelBlendOperationsForDab
brushPixelBlendOperationsForDabSequence
```

The goal is to prepare for future BitmapTile writing while keeping this phase pure and testable.

## Strong scope rule

Allowed:

```txt
pure Dart model
pure Dart service
BrushDab -> BrushPixelBlendOperation list
BrushDabSequence -> ordered BrushPixelBlendOperation list
destination color callback
per-pixel accumulated color map
focused model/service tests
```

Not allowed:

```txt
BitmapBrushRasterizer
pixel writes
BitmapTile byte mutation
BitmapSurface mutation
BitmapTile read helpers
BitmapTile write helpers
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

## Required production files

### 1. BrushPixelBlendOperation

Create:

```txt
lib/src/models/brush_pixel_blend_operation.dart
```

Required fields:

```dart
final int x;
final int y;
final RgbaColor before;
final RgbaColor after;
```

Required validation:

```txt
x >= 0
y >= 0
before != after
invalid values throw ArgumentError
```

Reason:

```txt
BrushPixelBlendOperation represents an actual pixel change.
A no-op before == after should not become an operation.
```

Required behavior:

```txt
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Do not include `BrushDab`.

Do not include `BrushPixelCoverage`.

Do not include `TileCoord`.

Reason:

```txt
This operation should be a simple pixel-level before/after record.
Future BitmapTile writer can consume it without knowing brush geometry.
```

### 2. BrushDabSequence pixel blend service

Create:

```txt
lib/src/services/brush_dab_sequence_blend.dart
```

Required typedef:

```dart
typedef DestinationPixelReader = RgbaColor Function(int x, int y);
```

Required public functions:

```dart
List<BrushPixelBlendOperation> brushPixelBlendOperationsForDab({
  required BrushDab dab,
  required DestinationPixelReader destinationAt,
})

List<BrushPixelBlendOperation> brushPixelBlendOperationsForDabSequence({
  required BrushDabSequence sequence,
  required DestinationPixelReader destinationAt,
})
```

### brushPixelBlendOperationsForDab

Rules:

```txt
- uses brushPixelCoveragesForDab(dab)
- for each coverage, read before color using destinationAt(x, y)
- calculate after using blendBrushDabPixelCoverage(...)
- skip operation if after == before
- return operations in row-major coverage order
- return an unmodifiable list if practical
- do not mutate anything
```

### brushPixelBlendOperationsForDabSequence

Rules:

```txt
- process dabs in BrushDabSequence order
- for each dab, use brushPixelCoveragesForDab(dab)
- for each coverage, calculate before color
- if this pixel was already changed by an earlier operation in this sequence, use the latest after color as before
- otherwise use destinationAt(x, y)
- calculate after using blendBrushDabPixelCoverage(...)
- skip operation if after == before
- update the in-memory current pixel color when after != before
- return operations in deterministic order:
  dab order first, then each dab's coverage row-major order
- return an unmodifiable list if practical
- do not mutate BrushDabSequence
- do not mutate BrushDab
- do not mutate destination RgbaColor
```

Important:

```txt
Do not re-read destinationAt for a pixel after it has already been changed in this sequence.
Use the accumulated after color.
```

Reason:

```txt
Multiple dabs can affect the same pixel.
Later dabs must blend over the result of earlier dabs, not over the original destination color.
```

## No-op behavior

Skip no-op operations.

Examples:

```txt
transparent dab color alpha == 0 -> no operation
coverage == 0 -> no operation
dab opacity == 0 -> no operation
dab flow == 0 -> no operation
blend result equal to destination -> no operation
```

This keeps the operation list meaningful for future tile updates and tile deltas.

## Required tests

### 1. BrushPixelBlendOperation tests

Create:

```txt
test/models/brush_pixel_blend_operation_test.dart
```

Required tests:

```txt
creates with valid values
rejects negative x
rejects negative y
rejects before equal to after
copyWith updates x
copyWith updates y
copyWith updates before
copyWith updates after
copyWith rejects no-op before == after
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
toString includes useful data
```

Suggested colors:

```txt
before = RgbaColor(r: 0, g: 0, b: 0, a: 0)
after = RgbaColor(r: 255, g: 0, b: 0, a: 255)
```

### 2. BrushDabSequence blend service tests

Create:

```txt
test/services/brush_dab_sequence_blend_test.dart
```

Required tests:

```txt
brushPixelBlendOperationsForDab returns empty list for non-effective dab
brushPixelBlendOperationsForDab returns one operation for one-pixel dab over transparent destination
brushPixelBlendOperationsForDab skips no-op transparent source alpha
brushPixelBlendOperationsForDab uses destinationAt for before color
brushPixelBlendOperationsForDab returns unmodifiable list

brushPixelBlendOperationsForDabSequence returns empty list for empty sequence
brushPixelBlendOperationsForDabSequence processes dabs in sequence order
brushPixelBlendOperationsForDabSequence preserves row-major order inside each dab
brushPixelBlendOperationsForDabSequence accumulates before color from earlier operations on the same pixel
brushPixelBlendOperationsForDabSequence does not re-read destinationAt after a pixel was changed
brushPixelBlendOperationsForDabSequence skips no-op operations
brushPixelBlendOperationsForDabSequence returns unmodifiable list
brushPixelBlendOperationsForDabSequence does not mutate BrushDabSequence
brushPixelBlendOperationsForDabSequence does not mutate BrushDab
brushPixelBlendOperationsForDabSequence does not mutate destination RgbaColor values
```

## Suggested helpers

### One-pixel dab helper

Use a one-pixel round dab:

```dart
BrushDab onePixelDab({
  int color = 0xFFFF0000,
  double opacity = 1,
  double flow = 1,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: 10.5, y: 10.5),
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

This should affect pixel:

```txt
x = 10
y = 10
```

### Transparent destination

```dart
final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
```

### Opaque blue destination

```dart
final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
```

## Suggested examples

### One dab over transparent destination

```txt
dab.color = 0xFFFF0000
destinationAt(10, 10) = transparent

expected operation:
x = 10
y = 10
before = transparent
after = RgbaColor(r: 255, g: 0, b: 0, a: 255)
```

### Transparent source alpha should be skipped

```txt
dab.color = 0x00FF0000
destinationAt(10, 10) = transparent

blend result == destination
expected operations = []
```

### Two dabs on same pixel should accumulate

```txt
first dab:
color = 0xFFFF0000
opacity = 1
flow = 1

second dab:
color = 0xFF0000FF
opacity = 0.5
flow = 1

destinationAt(10, 10) = transparent

expected operations:
1. before transparent -> after red
2. before red -> after purple-ish result from rgbaSourceOver
```

Do not expect the second operation to use transparent as before.

### Destination reader should not be re-read after pixel changed

Use a counting destinationAt callback.

Expected:

```txt
For two dabs affecting the same pixel:
destinationAt(10, 10) should be called once.
```

The second operation should use the accumulated in-memory color.

## Architecture rules

Brush operation rules:

```txt
BrushPixelBlendOperation is pixel-level before/after data.
brush_dab_sequence_blend.dart may know about BrushDab.
brush_dab_sequence_blend.dart may know about BrushDabSequence.
brush_dab_sequence_blend.dart may know about BrushPixelCoverage.
brush_dab_sequence_blend.dart may know about RgbaColor.
brush_dab_sequence_blend.dart may call brushPixelCoveragesForDab.
brush_dab_sequence_blend.dart may call blendBrushDabPixelCoverage.
brush_dab_sequence_blend.dart must not know about BitmapTile.
brush_dab_sequence_blend.dart must not know about BitmapSurface.
brush_dab_sequence_blend.dart must not create TileDeltaCommand.
brush_dab_sequence_blend.dart must not invalidate cache.
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
BrushPixelCoverage remains geometry coverage data.
BrushPixelBlendOperation remains pixel before/after operation data.
RgbaColor remains RGBA component value object.
rgba_blend.dart remains pure source-over color math.
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
pixel rasterization into BitmapTile
pixel blending into BitmapTile bytes
BitmapTile mutation helpers for drawing
BitmapTile read helpers
BitmapTile write helpers
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
lib/src/models/brush_pixel_blend_operation.dart
lib/src/services/brush_dab_sequence_blend.dart
test/models/brush_pixel_blend_operation_test.dart
test/services/brush_dab_sequence_blend_test.dart
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
- BrushPixelBlendOperation fields and validation
- brushPixelBlendOperationsForDab behavior
- brushPixelBlendOperationsForDabSequence behavior
- destinationAt callback behavior
- accumulated per-pixel before color behavior
- no-op skipping behavior
- operation ordering behavior
- confirmation that blendBrushDabPixelCoverage is reused
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

Phase 162 is complete when:

```txt
- BrushPixelBlendOperation exists and is tested.
- BrushPixelBlendOperation rejects no-op before == after.
- brushPixelBlendOperationsForDab exists and is tested.
- brushPixelBlendOperationsForDabSequence exists and is tested.
- Single-dab operations use destinationAt for before color.
- Sequence operations process dabs in sequence order.
- Sequence operations preserve row-major coverage order for each dab.
- Repeated same-pixel operations use the previous operation's after color as the next before color.
- destinationAt is not re-read for pixels already changed in the same sequence.
- No-op blend results are skipped.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
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

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
