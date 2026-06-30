# Phase 150 Codex Task

## Title

Canvas viewport foundation

## Repository

```txt id="cu3vmm"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="z4hv5u"
master
```

## Project type

```txt id="11wk2o"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 149.

Recent phases completed:

```txt id="q30eeo"
Phase 145: Timeline stabilization checkpoint
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
Phase 149: Brush input sampling tests
```

Phase 150 is the final recommended phase listed in the current handoff sequence:

```txt id="lgn7hk"
Canvas viewport foundation
```

This phase should create the pure coordinate/viewport foundation that future canvas zoom, pan, drawing input, and rendering can rely on.

This is not a drawing implementation phase.

This is not a brush rendering phase.

This is not a pointer-event integration phase.

This is not a CustomPainter phase.

## What structure this phase should create

Future canvas drawing will roughly flow like this:

```txt id="w8nzht"
screen / widget-local position
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> StrokePoint
-> Stroke
-> future renderer
```

Future canvas display will roughly flow like this:

```txt id="o75qk8"
CanvasPoint
-> CanvasViewport.canvasToViewport(...)
-> ViewportPoint
-> future painter / renderer
```

This phase should only build the pure model foundation for:

```txt id="7g02dp"
CanvasPoint
ViewportPoint
CanvasViewport
coordinate conversion tests
```

The purpose is to make future canvas work safer.

Later phases may connect this to Flutter pointer events, zoom gestures, panning, rendering, and brush input.

But this phase must not connect to those yet.

## Required references

Before editing, read:

```txt id="0322nq"
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Handoff_QuickAnimaker_v2_Current.md
docs/Phase_148_Codex_Task.md
docs/Phase_149_Codex_Task.md
```

Also inspect:

```txt id="mgn8qv"
lib/src/models/canvas_size.dart
lib/src/models/stroke_point.dart
lib/src/models/brush_input_sample.dart
lib/src/services/brush_input_sampling.dart
lib/src/controllers/canvas_controller.dart
lib/src/ui/canvas/stroke_painter.dart
test/models/brush_input_sample_test.dart
test/services/brush_input_sampling_test.dart
```

Do not modify timeline or storyboard behavior in this phase.

## Goal

Add a small, pure canvas viewport coordinate model and tests.

The goal is to lock down how canvas-space coordinates and viewport/screen-space coordinates are represented and converted before future zoom/pan/drawing integration begins.

This phase should protect:

```txt id="y4685p"
- canvas-space point representation
- viewport-space point representation
- zoom validation
- pan validation
- canvas-to-viewport coordinate conversion
- viewport-to-canvas coordinate conversion
- round-trip conversion stability
- JSON/copyWith/equality behavior
- no dependency on Flutter Offset
- no dependency on Canvas, Paint, CustomPainter, or renderer
- no dependency on PointerEvent
- no change to existing canvas drawing behavior
```

## Strong scope rule

This phase may add small model/helper production code only.

Preferred production files:

```txt id="9cl9mx"
lib/src/models/canvas_point.dart
lib/src/models/viewport_point.dart
lib/src/models/canvas_viewport.dart
```

Do not add UI integration.

Do not add actual drawing behavior.

Do not add pointer event integration.

Do not add gesture handling.

Do not modify `CanvasController` unless absolutely required.

Do not modify `StrokePainter`.

Do not modify timeline/storyboard files.

## Required production models

### 1. Add CanvasPoint

Preferred file:

```txt id="2fwpme"
lib/src/models/canvas_point.dart
```

Preferred fields:

```dart id="4lnchp"
final double x;
final double y;
```

Meaning:

```txt id="srlavp"
x: canvas-space x coordinate
y: canvas-space y coordinate
```

Required behavior:

```txt id="fvqbbb"
- immutable model
- const constructor if validation can still be handled consistently with project style
- copyWith
- equality/hashCode
- toJson/fromJson
- x and y must be finite numbers
- invalid values throw ArgumentError
- do not clamp silently
```

Do not use Flutter `Offset`.

Do not use `Size`.

Do not use `Canvas`.

This is a pure Dart model.

### 2. Add ViewportPoint

Preferred file:

```txt id="vii7j2"
lib/src/models/viewport_point.dart
```

Preferred fields:

```dart id="68orrm"
final double x;
final double y;
```

Meaning:

```txt id="t9geeq"
x: viewport/widget-local x coordinate
y: viewport/widget-local y coordinate
```

Required behavior:

```txt id="5yo9ln"
- immutable model
- const constructor if validation can still be handled consistently with project style
- copyWith
- equality/hashCode
- toJson/fromJson
- x and y must be finite numbers
- invalid values throw ArgumentError
- do not clamp silently
```

Do not use Flutter `Offset`.

Do not use `PointerEvent`.

This is a pure Dart model.

### 3. Add CanvasViewport

Preferred file:

```txt id="6jv7bz"
lib/src/models/canvas_viewport.dart
```

Preferred fields:

```dart id="b2ewv8"
final double zoom;
final double panX;
final double panY;
```

Recommended defaults:

```dart id="obiror"
zoom = 1.0
panX = 0.0
panY = 0.0
```

Meaning:

```txt id="ul0jq3"
zoom: scale factor between canvas-space and viewport-space
panX: viewport-space x offset
panY: viewport-space y offset
```

Coordinate convention:

```txt id="kzyp6q"
viewportX = canvasX * zoom + panX
viewportY = canvasY * zoom + panY

canvasX = (viewportX - panX) / zoom
canvasY = (viewportY - panY) / zoom
```

Required behavior:

```txt id="poh9fl"
- immutable model
- copyWith
- equality/hashCode
- toJson/fromJson
- zoom must be greater than 0
- zoom must be finite
- panX and panY must be finite
- invalid values throw ArgumentError
- do not clamp silently
```

Required methods:

```dart id="nf85m0"
ViewportPoint canvasToViewport(CanvasPoint point)
CanvasPoint viewportToCanvas(ViewportPoint point)
```

Optional but useful:

```dart id="4ifsg9"
CanvasViewport translatedBy({required double dx, required double dy})
CanvasViewport zoomedBy(double factor)
```

If adding optional methods, keep them pure and well-tested.

Do not add minZoom/maxZoom yet unless needed.

Do not clamp zoom silently.

Do not introduce UI gesture semantics.

## Required tests

### 1. CanvasPoint tests

Create:

```txt id="gnfx24"
test/models/canvas_point_test.dart
```

Required tests:

```txt id="wlbn5s"
creates with finite x and y
copyWith updates x
copyWith updates y
equality includes x and y
toJson/fromJson round-trips
NaN x throws
NaN y throws
infinite x throws
infinite y throws
```

### 2. ViewportPoint tests

Create:

```txt id="r9ri51"
test/models/viewport_point_test.dart
```

Required tests:

```txt id="6ycrrh"
creates with finite x and y
copyWith updates x
copyWith updates y
equality includes x and y
toJson/fromJson round-trips
NaN x throws
NaN y throws
infinite x throws
infinite y throws
```

### 3. CanvasViewport tests

Create:

```txt id="bh98wf"
test/models/canvas_viewport_test.dart
```

Required tests:

```txt id="6y1glv"
default viewport is identity transform
copyWith updates zoom
copyWith updates panX
copyWith updates panY
equality includes zoom, panX, and panY
toJson/fromJson round-trips
canvasToViewport applies zoom only
canvasToViewport applies pan only
canvasToViewport applies zoom and pan together
viewportToCanvas applies inverse zoom only
viewportToCanvas applies inverse pan only
viewportToCanvas applies inverse zoom and pan together
canvasToViewport then viewportToCanvas returns original point
viewportToCanvas then canvasToViewport returns original point
zero zoom throws
negative zoom throws
NaN zoom throws
infinite zoom throws
NaN panX throws
NaN panY throws
infinite panX throws
infinite panY throws
```

Use exact expectations for simple values.

For round-trip tests involving decimal values, use close-to expectations if necessary.

### 4. Brush input compatibility test

Add or update a small focused test only if useful.

Possible file:

```txt id="c9tlz4"
test/services/brush_input_sampling_test.dart
```

Optional test:

```txt id="l0ffq0"
viewport-converted CanvasPoint can be used to create BrushInputSample and then StrokePoint
```

If added, keep it pure.

Do not import Flutter UI types.

Do not use PointerEvent.

Do not modify production sampling helper unless necessary.

## Architecture rules

Canvas viewport architecture rules:

```txt id="t9zf08"
- CanvasPoint represents canvas-space coordinates.
- ViewportPoint represents viewport/widget-local coordinates.
- CanvasViewport owns pure coordinate conversion only.
- CanvasViewport does not know about Flutter widgets.
- CanvasViewport does not know about PointerEvent.
- CanvasViewport does not know about StrokePainter.
- CanvasViewport does not render anything.
- CanvasViewport does not mutate Project, Cut, Layer, Frame, Stroke, or BrushSettings.
```

Brush architecture compatibility rules:

```txt id="4od75b"
- BrushInputSample remains pre-stroke input data.
- StrokePoint remains the stored point type inside Stroke.
- Stroke continues to store StrokePoint list and BrushSettings directly.
- Stroke must not store CanvasPoint directly in this phase.
- Stroke must not store ViewportPoint directly in this phase.
- Stroke must not reference BrushPreset.
```

Phase boundary:

```txt id="9dpj9j"
- This phase may add pure model code.
- This phase may add model tests.
- This phase must not add actual canvas drawing.
- This phase must not add zoom/pan gesture handling.
- This phase must not change existing canvas behavior.
```

## Out of scope

Do not add:

```txt id="1awxkv"
new canvas UI
drawing canvas
new pointer event handling
tablet event handling
gesture detector
zoom gesture integration
pan gesture integration
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
CustomPainter changes
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

```txt id="yhv105"
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
BrushSettings semantics
BrushPreset semantics
BrushInputSample semantics
```

Do not weaken existing tests.

Do not remove Phase 146, 147, 148, or 149 tests.

## Expected changed files

Likely:

```txt id="hs0ys2"
lib/src/models/canvas_point.dart
lib/src/models/viewport_point.dart
lib/src/models/canvas_viewport.dart
test/models/canvas_point_test.dart
test/models/viewport_point_test.dart
test/models/canvas_viewport_test.dart
```

Possibly:

```txt id="wkpgx5"
test/services/brush_input_sampling_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="2w4xfa"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="wcscuq"
- changed files
- new model files added
- CanvasPoint fields
- ViewportPoint fields
- CanvasViewport fields
- coordinate conversion convention used
- confirmation that CanvasViewport uses plain Dart values, not Flutter Offset or PointerEvent
- confirmation that CanvasViewport validates zoom and pan
- confirmation that canvasToViewport preserves the declared formula
- confirmation that viewportToCanvas preserves the declared inverse formula
- confirmation that round-trip conversion is tested
- confirmation that no canvas drawing behavior was added
- confirmation that no pointer/gesture integration was added
- confirmation that no CustomPainter changes were added
- confirmation that no Provider/Riverpod/ChangeNotifier was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 150 is complete when:

```txt id="q9oubh"
- CanvasPoint exists and is tested.
- ViewportPoint exists and is tested.
- CanvasViewport exists and is tested.
- CanvasViewport validates zoom and pan explicitly.
- Coordinate conversion formula is stable and tested.
- Inverse coordinate conversion is stable and tested.
- Round-trip conversion is tested.
- Existing brush input sampling tests still pass.
- Existing brush model tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No canvas drawing/pointer-event/gesture/rendering work was added.
- No undo/redo/save/load/state-management framework work was added.
```

## Manual check list

This phase is model-only, so there is no required app UI manual check.

If you run the app anyway, only confirm the changed-risk areas:

```txt id="kk7te2"
- The app still launches.
- Existing canvas screen still appears as before.
- Existing drawing behavior, if any, does not visibly change.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
