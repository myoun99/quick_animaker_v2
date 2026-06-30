# Phase 149 Codex Task

## Title

Brush input sampling tests

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

QuickAnimaker v2 is complete through Phase 148.

Recent phases completed:

```txt
Phase 145: Timeline stabilization checkpoint
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
```

Phase 148 added a model-only brush foundation:

```txt
BrushSettings
BrushTipShape
BrushPresetId
BrushPreset
```

Phase 149 should add the next safe foundation for future drawing work:

```txt
Brush input sampling tests
```

This phase should define and test how raw brush input samples are represented before they become StrokePoint data.

This is still not a canvas phase.

This is still not a brush rendering phase.

This is still not a pointer-event integration phase.

## What structure this phase should create

Future drawing will roughly flow like this:

```txt
Pointer / tablet event
-> BrushInputSample
-> pure sampling policy / helper
-> StrokePoint list
-> Stroke(BrushSettings snapshot + StrokePoint list)
-> future renderer
```

This phase should only build the model/test foundation for the first middle part:

```txt
BrushInputSample
-> sampling helper / policy
-> StrokePoint list
```

The purpose is to make future canvas work safer.

Later, the UI can feed pointer events into this model.

But this phase must not connect to Flutter pointer events yet.

## Required references

Before editing, read:

```txt
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Phase_148_Codex_Task.md
```

Also inspect:

```txt
lib/src/models/brush_settings.dart
lib/src/models/brush_tip_shape.dart
lib/src/models/brush_preset.dart
lib/src/models/stroke.dart
lib/src/models/stroke_point.dart
lib/src/controllers/canvas_controller.dart
lib/src/ui/canvas/stroke_painter.dart
test/models/brush_settings_test.dart
test/models/stroke_brush_settings_compatibility_test.dart
```

Do not modify timeline or storyboard behavior in this phase.

## Goal

Add a small, pure brush input sampling foundation and tests.

The goal is to lock down how brush input samples are represented and converted into `StrokePoint` data before future brush engine/canvas work begins.

This phase should protect:

```txt
- raw brush input sample identity and values
- pressure validation
- coordinate validation
- stable conversion from sample coordinates to StrokePoint coordinates
- immutable outputs
- no mutation of input lists
- no dependency on Flutter PointerEvent
- no dependency on Canvas, Paint, CustomPainter, or renderer
- no change to Stroke storing BrushSettings directly
```

## Strong scope rule

This phase may add small model/helper production code only if needed for tests.

Preferred production files:

```txt
lib/src/models/brush_input_sample.dart
lib/src/services/brush_input_sampling.dart
```

If the project has a better existing folder convention for pure model helpers, follow the existing convention.

Do not add UI integration.

Do not add actual drawing behavior.

Do not add brush engine behavior.

Do not modify `CanvasController` unless absolutely required.

Do not modify `StrokePainter`.

## Required production model

### 1. Add BrushInputSample

Preferred file:

```txt
lib/src/models/brush_input_sample.dart
```

Preferred fields:

```dart
final double x;
final double y;
final double pressure;
final int sequence;
```

Recommended defaults:

```dart
pressure = 1.0
sequence = 0
```

Meaning:

```txt
x: canvas-space x coordinate
y: canvas-space y coordinate
pressure: normalized pressure, 0.0 to 1.0 inclusive
sequence: monotonically increasing sample order value supplied by caller
```

Required behavior:

```txt
- immutable model
- copyWith
- equality/hashCode
- toJson/fromJson
- pressure must be between 0.0 and 1.0 inclusive
- x and y must be finite numbers
- sequence must be >= 0
- invalid values throw ArgumentError
- do not clamp silently
```

Do not include Flutter types.

Do not store `Offset`.

Do not store `PointerEvent`.

Do not store `DateTime`.

Use plain Dart values only.

Reason:

This model should remain testable and independent of Flutter UI input.

### 2. Add pure brush input sampling helper

Preferred file:

```txt
lib/src/services/brush_input_sampling.dart
```

Preferred API:

```dart
List<StrokePoint> brushInputSamplesToStrokePoints(
  Iterable<BrushInputSample> samples,
)
```

Required behavior:

```txt
- Converts each BrushInputSample to StrokePoint(x: sample.x, y: sample.y)
- Preserves input order
- Does not mutate the input iterable/list
- Returns an unmodifiable List<StrokePoint>
- Allows empty input and returns an empty unmodifiable list
```

Also add a helper if useful:

```dart
List<BrushInputSample> collapseConsecutiveDuplicatePositions(
  Iterable<BrushInputSample> samples,
)
```

Required behavior for duplicate collapse, if implemented:

```txt
- Removes only consecutive samples with the same x and y
- Keeps the first sample in a duplicate run
- Does not remove non-consecutive duplicates
- Preserves pressure and sequence of kept samples
- Does not mutate input
- Returns an unmodifiable list
```

Keep this helper simple.

Do not implement smoothing.

Do not implement interpolation.

Do not implement stabilization.

Do not implement pressure curves.

Do not implement brush dab spacing.

Do not implement velocity.

## Required tests

### 1. BrushInputSample tests

Create:

```txt
test/models/brush_input_sample_test.dart
```

Required tests:

```txt
default pressure and sequence are stable
copyWith updates x
copyWith updates y
copyWith updates pressure
copyWith updates sequence
equality includes x, y, pressure, and sequence
toJson/fromJson round-trips
invalid pressure below 0 throws
invalid pressure above 1 throws
NaN x throws
NaN y throws
infinite x throws
infinite y throws
negative sequence throws
```

Use `throwsArgumentError`.

Do not use Flutter `Offset`.

### 2. Brush input sampling helper tests

Create:

```txt
test/services/brush_input_sampling_test.dart
```

Required tests for `brushInputSamplesToStrokePoints`:

```txt
empty input returns empty list
single sample converts to one StrokePoint
multiple samples preserve order
pressure is not discarded from source object mutation because source samples remain unchanged
output list is unmodifiable
input list is not mutated
```

Required tests for duplicate collapse if implemented:

```txt
empty input returns empty list
single sample is kept
consecutive duplicate positions collapse to first sample
non-consecutive duplicate positions are kept
pressure and sequence of kept sample are preserved
output list is unmodifiable
input list is not mutated
```

### 3. Stroke compatibility test

Update or add focused tests if needed:

```txt
test/models/stroke_brush_settings_compatibility_test.dart
```

Required assertion:

```txt
Stroke still stores BrushSettings directly and does not reference BrushPreset.
```

Do not change `Stroke` to use `BrushInputSample`.

`BrushInputSample` is pre-stroke input data.

`StrokePoint` remains the coordinate data stored in `Stroke`.

## Architecture rules

Brush input architecture rules:

```txt
- BrushInputSample represents raw normalized input sample data.
- BrushInputSample is not a rendered point.
- BrushInputSample is not a Flutter PointerEvent.
- StrokePoint remains the stored point type inside Stroke.
- BrushSettings remains the frozen brush settings snapshot stored inside Stroke.
- BrushPreset remains reusable preset metadata.
- Stroke must not reference BrushPreset.
- Stroke must not store BrushInputSample directly in this phase.
```

Phase boundary:

```txt
- This phase may add pure model/helper code.
- This phase may add unit tests.
- This phase must not add actual brush rendering.
- This phase must not add actual pointer event integration.
- This phase must not change canvas behavior.
```

## Out of scope

Do not add:

```txt
canvas
drawing canvas
new pointer event handling
tablet event handling
brush engine
brush rendering
stroke rendering changes
dab generation
spacing-based dab placement
pressure curves
velocity calculation
smoothing
stabilization
interpolation
onion skin
undo/redo
save/load service changes
Provider
Riverpod
Bloc
ChangeNotifier
CustomPainter
renderer changes
tile engine changes
cache changes
persistence service changes
brush preset UI
selected brush UI
toolbar UI
metadata side panel
storyboard drawing
storyboard thumbnail rendering
storyboard export
```

Do not change:

```txt
TimelinePanel
LayerTimelineGrid
TimelineController
StoryboardPanel
StoryboardPanel tests
Timeline range semantics
Cut.duration semantics
authoredTimelineExtentFrameCount semantics
selected exposure range semantics
visible frame range semantics
CanvasController behavior
StrokePainter behavior
```

Do not weaken existing tests.

Do not remove Phase 146, 147, or 148 tests.

## Expected changed files

Likely:

```txt
lib/src/models/brush_input_sample.dart
lib/src/services/brush_input_sampling.dart
test/models/brush_input_sample_test.dart
test/services/brush_input_sampling_test.dart
```

Possibly:

```txt
test/models/stroke_brush_settings_compatibility_test.dart
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
- new model/helper files added
- BrushInputSample fields
- confirmation that BrushInputSample uses plain Dart values, not Flutter Offset or PointerEvent
- confirmation that BrushInputSample validates pressure and coordinates
- confirmation that brushInputSamplesToStrokePoints preserves sample order
- confirmation that output lists are unmodifiable
- confirmation that input lists are not mutated
- confirmation that Stroke still stores StrokePoint list and BrushSettings directly
- confirmation that Stroke does not reference BrushPreset
- confirmation that Stroke does not store BrushInputSample directly
- confirmation that no brush engine/rendering/input integration was added
- confirmation that no canvas/drawing/CustomPainter code was added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 149 is complete when:

```txt
- BrushInputSample exists and is tested.
- BrushInputSample validation is explicit and does not silently clamp invalid values.
- BrushInputSample JSON round-trip works.
- Pure sample-to-StrokePoint conversion exists and is tested.
- Conversion preserves order.
- Conversion does not mutate inputs.
- Conversion returns unmodifiable output.
- Stroke remains unchanged in architecture.
- Stroke stores StrokePoint and BrushSettings directly.
- Stroke does not reference BrushPreset.
- Stroke does not store BrushInputSample directly.
- Existing brush model tests pass.
- Existing timeline/storyboard stabilization tests pass.
- No canvas/drawing/brush rendering/pointer-event integration was added.
- No undo/redo/save/load/state-management framework work was added.
```

## Manual check list

This phase is model/helper/test-only, so there is no required app UI manual check.

If you run the app anyway, only confirm:

```txt
- The app still launches.
- Existing canvas behavior does not visibly change.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
