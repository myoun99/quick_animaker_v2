# Phase 156 Codex Task

## Title

BrushDab / BrushDabPlacement pure model foundation

## Repository

```txt id="os7wuq"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="tgfsup"
master
```

## Project type

```txt id="a0s2x0"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 155.

Recent bitmap canvas foundation phases:

```txt id="abj6gm"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
```

Current long-term direction:

```txt id="hntl7w"
QuickAnimaker v2 is bitmap-first.
Final artwork source of truth should be bitmap tile data.
Brush input should eventually become brush dab placement.
Brush dabs should eventually be rasterized into BitmapTile pixel data.
DirtyRegion / DirtyTileSet should eventually be derived from affected dabs.
TileDeltaCommand should eventually record before/after tile changes.
CacheInvalidationPlan should eventually describe affected cache keys.
```

Phase 156 starts the brush engine pipeline, but only at the pure dab-placement model level.

This phase must not add pixel rasterization, BitmapTile mutation, DirtyRegion generation, canvas UI, undo, renderer, cache implementation, save/load, or playback.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt id="6ty4a0"
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> BrushDabPlacement
-> BrushDabSequence
-> future DirtyRegion
-> future BitmapBrushRasterizer
-> future BitmapTile updates
-> future TileDeltaCommand
-> future CacheInvalidationPlan
```

This phase only creates:

```txt id="mvhlde"
BrushDab
BrushDabSequence
BrushDabPlacement
```

Meaning:

```txt id="zgb85e"
BrushDab
= one planned brush stamp before rasterization

BrushDabSequence
= immutable ordered list of BrushDab values

BrushDabPlacement
= pure function/service that converts BrushInputSample values and BrushSettings into BrushDabSequence
```

This is model / pure service only.

## Required references

Before editing, read:

```txt id="nb4u5q"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
docs/Phase_154_Codex_Task.md
docs/Phase_155_Codex_Task.md
```

Also inspect:

```txt id="ql26du"
lib/src/models/brush_input_sample.dart
lib/src/models/brush_settings.dart
lib/src/models/brush_tip_shape.dart
lib/src/models/canvas_point.dart
lib/src/models/bitmap_tile.dart
lib/src/models/dirty_region.dart
lib/src/models/tile_delta_command.dart
test/models/brush_input_sample_test.dart
test/models/brush_settings_test.dart
```

If filenames differ, follow existing project convention.

Do not modify timeline or storyboard behavior.

## Goal

Add pure brush dab placement foundations:

```txt id="i08vej"
BrushDab
BrushDabSequence
BrushDabPlacement
```

The goal is to prepare the project for future bitmap brush rasterization without touching pixel storage yet.

## Strong scope rule

Allowed:

```txt id="xxsvm7"
pure Dart model classes
pure Dart dab placement service/function
distance-based dab spacing
pressure interpolation
copyWith / equality / hashCode / toJson / fromJson
focused model/service tests
```

Not allowed:

```txt id="n01ssc"
BitmapBrushRasterizer
pixel rasterization
BitmapTile pixel mutation
BitmapSurface mutation
DirtyRegion generation from dabs
DirtyTileSet generation from dabs
TileDeltaCommand generation from dabs
cache invalidation generation from dabs
actual canvas UI
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

## Coordinate convention

`BrushInputSample.x` and `BrushInputSample.y` should be treated as canvas-space coordinates for this phase.

`BrushDab` should store its position as `CanvasPoint`.

Do not use Flutter `Offset`.

Do not use `dart:ui`.

Do not use `Canvas`, `Paint`, `Image`, or `ui.Image`.

## Required production files

### 1. BrushDab

Create:

```txt id="fvz73a"
lib/src/models/brush_dab.dart
```

Required fields:

```dart id="k6ya1m"
final CanvasPoint center;
final double size;
final double opacity;
final double flow;
final double hardness;
final BrushTipShape tipShape;
final double pressure;
final int sequence;
```

Meaning:

```txt id="ho9mmt"
center: canvas-space dab center
size: effective dab size in pixels before rasterization
opacity: effective dab opacity
flow: brush flow
hardness: brush hardness
tipShape: brush tip shape
pressure: interpolated input pressure
sequence: increasing dab order
```

Required validation:

```txt id="cdhs5j"
center uses existing CanvasPoint validation
size >= 0
opacity >= 0 && opacity <= 1
flow >= 0 && flow <= 1
hardness >= 0 && hardness <= 1
pressure >= 0 && pressure <= 1
sequence >= 0
all double values must be finite
invalid values throw ArgumentError
```

Important:

`size >= 0` is intentional.

Reason:

```txt id="4ys37w"
When pressureSize is enabled and input pressure is 0, the effective dab size may become 0.
Do not silently clamp.
Future rasterizer can skip zero-size or zero-opacity dabs.
```

Required behavior:

```txt id="fsvaic"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Required factory:

```dart id="jejijt"
BrushDab.fromInputSample({
  required BrushInputSample sample,
  required BrushSettings settings,
  required int sequence,
})
```

Effective value rules:

```txt id="xwil5m"
center = CanvasPoint(x: sample.x, y: sample.y)

size =
  settings.pressureSize
    ? settings.size * sample.pressure
    : settings.size

opacity =
  settings.pressureOpacity
    ? settings.opacity * sample.pressure
    : settings.opacity

flow = settings.flow
hardness = settings.hardness
tipShape = settings.tipShape
pressure = sample.pressure
sequence = sequence
```

Do not use `BrushDab` to modify pixels.

Do not add rasterization helpers.

### 2. BrushDabSequence

Create:

```txt id="x4ixek"
lib/src/models/brush_dab_sequence.dart
```

Required internal data:

```dart id="exij4w"
List<BrushDab>
```

Recommended constructor:

```dart id="j43di1"
BrushDabSequence([Iterable<BrushDab> dabs = const []])
```

Required behavior:

```txt id="fdp6y0"
- immutable public API
- defensive copy input dabs
- expose unmodifiable dabs
- preserve dab order
- equality is order-sensitive
- hashCode is order-sensitive
- toJson/fromJson
- toString
```

Required getters:

```dart id="n2t84s"
List<BrushDab> get dabs
int get length
bool get isEmpty
bool get isNotEmpty
BrushDab? get firstOrNull
BrushDab? get lastOrNull
```

Required helpers:

```dart id="i7d9kt"
BrushDabSequence add(BrushDab dab)
BrushDabSequence addAll(Iterable<BrushDab> dabs)
```

Rules:

```txt id="dw7u79"
All helpers return a new BrushDabSequence.
Original sequence must not mutate.
```

Important:

Unlike `DirtyTileSet` or `CacheInvalidationPlan`, this sequence is ordered.

Reason:

```txt id="zos5u2"
Brush dab order matters for future rasterization, opacity accumulation, flow behavior, and textured brushes.
```

### 3. BrushDabPlacement

Create:

```txt id="gk2q2m"
lib/src/services/brush_dab_placement.dart
```

Required public function:

```dart id="he7ksn"
BrushDabSequence brushInputSamplesToBrushDabs({
  required Iterable<BrushInputSample> samples,
  required BrushSettings settings,
})
```

This must be pure and deterministic.

Input / output rules:

```txt id="eehbpt"
- empty samples -> empty BrushDabSequence
- one sample -> one BrushDab
- multiple samples -> distance-spaced BrushDabSequence
- preserve stroke direction
- output sequences start at sequence 0
- sequence increments by 1 for every emitted dab
```

Spacing rule:

```txt id="4o2jgx"
spacingDistance = settings.size * settings.spacing
```

Use Euclidean distance:

```txt id="108c5p"
distance = sqrt(dx * dx + dy * dy)
```

Placement rule:

```txt id="mr6o1w"
- Always emit a dab at the first sample.
- Walk through each segment between consecutive samples.
- Emit additional dabs whenever accumulated path distance reaches spacingDistance.
- Interpolate x, y, and pressure along the segment.
- Do not emit duplicate dabs for zero-length movement.
- If the final input sample is not already represented by the last emitted dab, emit one final dab at the final sample.
```

Final sample rule is intentional.

Reason:

```txt id="444kh8"
Short strokes and taps should leave a visible endpoint candidate.
Future rasterizer can still skip zero-size or zero-opacity dabs.
```

Pressure interpolation rule:

```txt id="50wnf8"
pressure = previousPressure + (nextPressure - previousPressure) * t
```

where `t` is the interpolation ratio along the current segment.

Required helper behavior:

```txt id="505hut"
- no input list mutation
- no BrushSettings mutation
- no BrushInputSample mutation
- no BitmapTile access
- no DirtyRegion access
- no TileDeltaCommand access
```

Implementation may use `dart:math` for `sqrt`.

Do not use Flutter APIs.

## Required tests

### 1. BrushDab tests

Create:

```txt id="exmfee"
test/models/brush_dab_test.dart
```

Required tests:

```txt id="kiesxd"
creates with valid values
rejects negative size
allows zero size
rejects opacity below 0
rejects opacity above 1
rejects flow below 0
rejects flow above 1
rejects hardness below 0
rejects hardness above 1
rejects pressure below 0
rejects pressure above 1
rejects negative sequence
rejects non-finite size
rejects non-finite opacity
copyWith updates center
copyWith updates size
copyWith updates opacity
copyWith updates flow
copyWith updates hardness
copyWith updates tipShape
copyWith updates pressure
copyWith updates sequence
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
fromInputSample uses sample position as CanvasPoint
fromInputSample applies pressureSize
fromInputSample applies pressureOpacity
fromInputSample preserves flow/hardness/tipShape
```

### 2. BrushDabSequence tests

Create:

```txt id="ev2u54"
test/models/brush_dab_sequence_test.dart
```

Required tests:

```txt id="evybsx"
empty sequence has length 0
constructor stores dabs in order
constructor defensively copies input dabs
dabs getter is unmodifiable
isEmpty is true for empty sequence
isNotEmpty is true for non-empty sequence
firstOrNull returns null for empty sequence
lastOrNull returns null for empty sequence
firstOrNull returns first dab
lastOrNull returns last dab
add returns new sequence with dab appended
add does not mutate original
addAll returns new sequence with dabs appended
equality is order-sensitive
hashCode is order-sensitive
toJson/fromJson round-trips
```

Important order test:

```txt id="ipkp22"
BrushDabSequence([a, b]) != BrushDabSequence([b, a])
```

### 3. BrushDabPlacement tests

Create:

```txt id="y75zqq"
test/services/brush_dab_placement_test.dart
```

Required tests:

```txt id="k4vjmc"
empty samples returns empty sequence
one sample returns one dab
two samples shorter than spacing returns first and final dabs
two samples exactly one spacing apart returns first and final dabs without duplicate endpoint
two samples crossing multiple spacing intervals emits interpolated dabs
zero-length repeated sample does not emit duplicate dabs
multiple segments preserve direction
pressure is interpolated between samples
pressureSize affects emitted dab size
pressureOpacity affects emitted dab opacity
sequence numbers start at 0 and increase by 1
final sample is emitted when not already represented
function does not mutate input sample list
```

Example spacing test:

```txt id="y05ger"
settings.size = 10
settings.spacing = 0.5
spacingDistance = 5

samples:
(0, 0) -> (12, 0)

expected dab centers:
(0, 0)
(5, 0)
(10, 0)
(12, 0) final endpoint
```

Example exact endpoint test:

```txt id="c7cqly"
settings.size = 10
settings.spacing = 0.5
spacingDistance = 5

samples:
(0, 0) -> (10, 0)

expected dab centers:
(0, 0)
(5, 0)
(10, 0)

Do not duplicate (10, 0).
```

Example short stroke test:

```txt id="n16nqf"
settings.size = 10
settings.spacing = 0.5
spacingDistance = 5

samples:
(0, 0) -> (3, 0)

expected dab centers:
(0, 0)
(3, 0)
```

## Architecture rules

Brush dab rules:

```txt id="5dthqr"
BrushDab is not a pixel.
BrushDab is not a BitmapTile.
BrushDabSequence is not a raster image.
BrushDabPlacement is not a rasterizer.
BrushDabPlacement must not modify BitmapSurface.
BrushDabPlacement must not create DirtyRegion.
BrushDabPlacement must not create TileDeltaCommand.
BrushDabPlacement must not invalidate cache.
```

Bitmap storage boundary:

```txt id="7pxhpl"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan remains cache invalidation descriptor data.
```

Timeline/storyboard boundary:

```txt id="54e49z"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="ghs5fi"
BitmapBrushRasterizer
pixel rasterization
pixel blending
BitmapTile mutation helpers for drawing
BitmapSurface drawing helpers
DirtyRegion generation from dabs
DirtyTileSet generation from dabs
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

```txt id="x0hbfn"
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/services/brush_dab_placement.dart
test/models/brush_dab_test.dart
test/models/brush_dab_sequence_test.dart
test/services/brush_dab_placement_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="cp401b"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="tx2mbh"
- changed files
- new model/service files added
- BrushDab fields and validation
- BrushDabSequence immutability and order-sensitive equality policy
- BrushDabPlacement spacing algorithm
- pressure interpolation behavior
- final endpoint emission behavior
- confirmation that no BitmapBrushRasterizer was added
- confirmation that no BitmapTile pixel mutation was added
- confirmation that no DirtyRegion generation was added
- confirmation that no TileDeltaCommand generation was added
- confirmation that no cache implementation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 156 is complete when:

```txt id="r0gobg"
- BrushDab exists and is tested.
- BrushDabSequence exists and is tested.
- brushInputSamplesToBrushDabs exists and is tested.
- BrushDab supports pressure-adjusted size and opacity.
- BrushDabSequence preserves dab order.
- BrushDabSequence equality is order-sensitive.
- BrushDabPlacement emits dabs based on settings.size * settings.spacing.
- BrushDabPlacement interpolates x, y, and pressure.
- BrushDabPlacement emits final endpoint when needed.
- Existing Phase 152 BitmapSurface / BitmapTile / TileCoord tests still pass.
- Existing Phase 153 DirtyRegion / DirtyTileSet tests still pass.
- Existing Phase 154 TileDelta / TileDeltaCommand tests still pass.
- Existing Phase 155 CacheInvalidationPlan/key tests still pass.
- Existing canvas viewport and brush input tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No pixel rasterization was added.
- No drawing canvas UI was added.
- No DirtyRegion / TileDelta / cache generation behavior was added.
- No UndoService / undo stack was added.
```

## Manual check list

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="d8vuqx"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
