# Phase 7 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 7: Timeline MVP with Sparse Frame Exposure.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 6 are already complete.

Current completed foundation:

```text
lib/main.dart
lib/src/models/
lib/src/services/project_repository.dart
lib/src/services/command.dart
lib/src/services/history_manager.dart
lib/src/services/commands/
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
lib/src/controllers/canvas_controller.dart
lib/src/controllers/layer_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/
lib/src/ui/layers/
test/models/
test/services/
test/controllers/
test/ui/
docs/
```

The project already has:

* Immutable domain models
* Typed IDs
* JSON support
* `copyWith` support
* `ProjectRepository`
* Command-based undo/redo MVP
* JSON save/load services
* Basic visible canvas
* Basic stroke drawing
* Layer MVP
* Layer selection
* Layer visibility
* Layer opacity
* Passing `flutter analyze`
* Passing `flutter test`

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Phase_0_1_Codex_Task.md
docs/Phase_2_Codex_Task.md
docs/Phase_3_Codex_Task.md
docs/Phase_4_Codex_Task.md
docs/Phase_5_Codex_Task.md
docs/Phase_6_Codex_Task.md
```

This task implements only Phase 7.

---

## Scope

Implement only:

```text
Phase 7: Timeline MVP with Sparse Frame Exposure
```

The goal is to introduce a minimal timeline system that can select the current timeline frame index and resolve which drawing frame should be displayed for each layer.

This phase should allow:

1. A current timeline frame index
2. A simple timeline UI
3. Selecting a timeline frame index
4. Drawing into the active layer at the selected timeline frame
5. Sparse frame storage
6. Exposure / held-frame behavior
7. Displaying the correct layer frame based on the selected timeline frame
8. Creating a new drawing frame at the selected timeline frame
9. Keeping existing Layer MVP behavior working

This is a minimal timeline MVP.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Timeline scrubbing with real-time playback
* Multi-cut editing
* Complex exposure editing UI
* Dragging frame blocks
* Reordering frames
* Reordering layers
* Copy/paste frames
* File picker UI
* Advanced save/load UI
* Bitmap raster engine
* Advanced brush engine
* Pressure/tilt/speed dynamics
* Layer groups
* Layer masks
* Blend modes
* Infinite canvas
* Tile system
* Disk cache
* Playback cache
* Provider
* Riverpod
* Bloc
* Complex app-wide state management

Do not implement Phase 8 or later.

This phase must stay focused on a simple sparse timeline MVP.

---

## Core Timeline Principle

The timeline must use sparse frame/exposure behavior.

Do not store dense drawing data for every timeline index.

Wrong direction:

```text
Frame 13 → Drawing A
Frame 14 → duplicated Drawing A
Frame 15 → duplicated Drawing A
Frame 16 → duplicated Drawing A
Frame 17 → Drawing B
```

Correct direction:

```text
Frame 13 → Drawing A, duration 4
Frame 17 → Drawing B, duration 3
```

Then:

```text
Timeline index 13, 14, 15, 16 → displays Drawing A
Timeline index 17, 18, 19 → displays Drawing B
```

A drawing should exist only where a new drawing starts.

Held frames should be represented by `Frame.duration` / exposure, not by duplicating stroke data.

---

## Current Model Notes

The existing `Frame` model already has:

```dart
FrameId id;
int duration;
List<Stroke> strokes;
```

For Phase 7, avoid major model rewrites if possible.

Recommended minimal approach:

* Keep `Layer.frames` as `List<Frame>` for now.
* Treat each `Frame` in the list as a sparse drawing/exposure block.
* Add timeline start-frame information outside the existing `Frame` model if needed, or introduce a minimal value object that links a timeline index to a `FrameId`.

However, if the current code already assumes each layer has a list of frames, the simplest viable MVP is:

```text
Layer.frames[0] starts at timeline index 0
Each frame's duration determines how long it is held
The next frame starts after the previous frame's duration
```

Example:

```text
Layer.frames:
  Frame A duration 4
  Frame B duration 3

Timeline:
  index 0,1,2,3 → Frame A
  index 4,5,6 → Frame B
```

This is acceptable for Phase 7.

Do not implement a full map-based or graph-based timeline model unless necessary.

Do not migrate all model files unless absolutely necessary.

---

## Important Design Decision for Phase 7

Use the following MVP timeline interpretation:

```text
Within each Layer:
- frames are ordered exposure blocks
- each Frame.duration is the number of timeline frames it is held
- timeline frame index is resolved by walking layer.frames and accumulating duration
```

Example:

```text
Layer.frames = [
  Frame(id: A, duration: 4),
  Frame(id: B, duration: 3),
]

resolveLayerFrameAt(index: 0) → A
resolveLayerFrameAt(index: 1) → A
resolveLayerFrameAt(index: 2) → A
resolveLayerFrameAt(index: 3) → A
resolveLayerFrameAt(index: 4) → B
resolveLayerFrameAt(index: 5) → B
resolveLayerFrameAt(index: 6) → B
resolveLayerFrameAt(index: 7) → null or last frame depending policy
```

For this MVP, prefer:

```text
If timeline index is beyond all exposures, return null.
```

Do not auto-extend frames unless the user explicitly creates a new drawing frame.

---

## Required Folder Structure

Use existing folders:

```text
lib/src/controllers/
lib/src/ui/
lib/src/ui/canvas/
lib/src/ui/layers/
```

Create timeline UI folder:

```text
lib/src/ui/timeline/
```

Expected relevant structure after this phase:

```text
lib/
  src/
    controllers/
      canvas_controller.dart
      layer_controller.dart
      timeline_controller.dart
    ui/
      home_page.dart
      canvas/
        canvas_view.dart
        stroke_painter.dart
      layers/
        layer_panel.dart
      timeline/
        timeline_panel.dart

test/
  controllers/
    timeline_controller_test.dart
    canvas_controller_test.dart
    layer_controller_test.dart
  ui/
    timeline_panel_test.dart
    canvas_view_test.dart
```

You may adjust exact file names if there is a strong reason, but keep responsibilities separated.

---

## Required Files to Create or Modify

You may create:

```text
lib/src/controllers/timeline_controller.dart
lib/src/ui/timeline/timeline_panel.dart
test/controllers/timeline_controller_test.dart
test/ui/timeline_panel_test.dart
```

You may modify:

```text
lib/src/controllers/canvas_controller.dart
lib/src/controllers/layer_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/canvas_view.dart
lib/src/ui/canvas/stroke_painter.dart
test/controllers/canvas_controller_test.dart
test/controllers/layer_controller_test.dart
test/ui/canvas_view_test.dart
```

You may modify:

```text
lib/src/services/project_repository.dart
test/services/project_repository_test.dart
```

only if minimal repository methods are required for frame insertion/update.

Do not modify model files unless absolutely necessary.

Do not modify save/load, command/history, or existing model JSON unless absolutely necessary.

Do not modify docs other than this task document.

---

## TimelineController

Create:

```text
lib/src/controllers/timeline_controller.dart
```

Responsibilities:

* Hold current timeline frame index
* Expose current frame index
* Select timeline frame index
* Resolve which `Frame` is visible for a given `Layer` at the current timeline frame
* Resolve which `FrameId` should receive drawing strokes for the active layer
* Create a new drawing frame/exposure block at the current timeline frame when needed
* Provide a simple total timeline length

Suggested constructor:

```dart
class TimelineController {
  TimelineController({
    required ProjectRepository repository,
    required CutId cutId,
    int initialFrameIndex = 0,
  });
}
```

Suggested API:

```dart
int get currentFrameIndex;

void selectFrameIndex(int frameIndex);

int get totalFrameCount;

Frame? resolveFrameForLayer({
  required Layer layer,
  int? frameIndex,
});

FrameId? resolveFrameIdForLayer({
  required Layer layer,
  int? frameIndex,
});

bool hasDrawingAtCurrentFrame({
  required Layer layer,
});

void createDrawingFrameForLayer({
  required LayerId layerId,
  required FrameId frameId,
  int duration = 1,
});
```

Implementation notes:

* `selectFrameIndex` should reject negative indexes.
* `totalFrameCount` can be the maximum exposure length across all layers in the current cut.
* `resolveFrameForLayer` should walk `layer.frames` in order and use `Frame.duration`.
* If `frameIndex` is omitted, use `currentFrameIndex`.
* If a layer has no frames, return null.
* If the index is outside all exposure ranges, return null.
* Keep this controller plain Dart.
* Do not use Provider/Riverpod/Bloc.

---

## Sparse Exposure Resolution

Implement exposure resolution like this:

```text
currentStart = 0
for frame in layer.frames:
  endExclusive = currentStart + frame.duration
  if frameIndex >= currentStart && frameIndex < endExclusive:
    return frame
  currentStart = endExclusive
return null
```

If `duration <= 0`, treat it safely.

Preferred behavior:

```text
duration <= 0 should be treated as 1 for resolution, or rejected when creating frames.
```

For newly created frames, require duration >= 1.

Add tests for this.

---

## Creating a New Drawing at the Selected Timeline Frame

For this MVP, when the active layer has no drawing frame at the current timeline frame, drawing should create a new frame/exposure block at that point.

Keep this simple.

Allowed MVP behavior:

1. If active layer has a frame resolving at current timeline index:

    * Draw into that frame.
2. If no frame resolves at current timeline index:

    * Create a new `Frame` with duration 1.
    * Append it to the active layer's `frames`.
    * Draw into the new frame.

This append behavior is acceptable for Phase 7 even though it does not yet support precise insertion gaps.

Do not implement complex splitting or insertion of exposure blocks yet.

Do not duplicate previous frame data.

Do not create frames for every missing index.

---

## CanvasController Changes

Update `CanvasController` to use timeline-aware frame resolution.

Current Phase 6 uses active layer frame id. Phase 7 should instead use:

```text
active layer + current timeline index → resolved frame
```

Suggested approach:

* `CanvasController` receives `LayerController` and `TimelineController`, or callbacks.
* On `endStroke()`:

    1. Ask active layer from `LayerController`.
    2. Ask `TimelineController` to resolve frame for that layer.
    3. If no frame exists at the current timeline index, create a new drawing frame for that layer.
    4. Add stroke to the resolved/new frame.

Important:

* Do not add the stroke to the wrong layer.
* Do not use only a global `FrameId` if multiple layers may have frames with similar ids.
* Keep tests verifying that drawing targets the active layer and current timeline frame.

If the existing `AddStrokeCommand` still targets only `FrameId`, ensure frame ids are unique enough to avoid wrong-layer writes.

---

## LayerController Changes

LayerController may need small changes to cooperate with TimelineController.

Allowed changes:

* Expose active layer
* Expose active layer id
* Add default frame creation helpers if needed
* Avoid assuming `layer.frames.first` is always the current frame

Important:

After Phase 7, `LayerController.frameId` should not be the main source of truth for drawing.

The current timeline frame index should decide the displayed/drawn frame.

---

## Repository Support

If needed, add minimal repository methods.

Allowed additions:

```dart
void addFrameToLayer({
  required LayerId layerId,
  required Frame frame,
});

void updateFrame({
  required FrameId frameId,
  required Frame Function(Frame frame) update,
});
```

But avoid duplicating existing methods if they already exist.

Existing methods may already include:

```dart
addFrame({
  required LayerId layerId,
  required Frame frame,
})

addStroke({
  required FrameId frameId,
  required Stroke stroke,
})
```

Use existing methods if sufficient.

If frame insertion/update methods are added or changed:

* Preserve immutability
* Rebuild parent chain
* Throw clear errors for missing targets
* Add tests

Do not implement full timeline editing repository methods yet.

---

## TimelinePanel

Create:

```text
lib/src/ui/timeline/timeline_panel.dart
```

Responsibilities:

* Display a simple row of timeline frame index buttons/cells
* Show selected timeline frame index
* Allow selecting a frame index
* Show a small fixed number of cells, such as 24 or 48
* It may show whether any visible layer has a drawing at that timeline index

Suggested constructor:

```dart
class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.onSelectFrame,
  });

  final int currentFrameIndex;
  final int frameCount;
  final ValueChanged<int> onSelectFrame;
}
```

Keep it simple.

A horizontal `ListView` or `Wrap` of buttons is enough.

Do not implement:

* Dragging frame blocks
* Exposure length handles
* Playback cursor
* Keyframe icons beyond simple debug indicators
* Full production timeline UI

---

## HomePage Changes

Update `HomePage` to:

* Create `TimelineController`
* Connect CanvasController to active layer + timeline
* Show `TimelinePanel`
* Keep `LayerPanel`
* Keep `CanvasView`
* Keep Undo/Redo debug buttons
* Show current frame index

Simple layout is fine:

```text
Top: debug controls
Center: canvas + layer panel
Bottom: timeline panel
```

No final production UI required.

---

## StrokePainter / CanvasView Changes

The canvas should paint the correct frame for each visible layer at the current timeline index.

Possible approach:

* `CanvasView` receives paintable layer/frame pairs from controller or HomePage.
* `TimelineController.resolveFrameForLayer()` is used to select the frame for each layer.
* Hidden layers are still skipped.
* Layer opacity still applies.
* Active stroke preview still appears while drawing.

Do not paint every frame in a layer.

Only paint the resolved frame for each visible layer at the current timeline frame index.

---

## Tests

Create and update tests under:

```text
test/controllers/
test/ui/
```

---

## timeline_controller_test.dart

Required test cases:

### 1. Starts at initial frame index

* Create controller with default initial index
* Verify `currentFrameIndex == 0`

### 2. Select frame index

* Select frame index 10
* Verify current index is 10

### 3. Reject negative frame index

* Selecting -1 should throw

### 4. Resolves sparse exposure frames

Create a layer:

```text
Frame A duration 4
Frame B duration 3
```

Verify:

```text
index 0 → A
index 1 → A
index 2 → A
index 3 → A
index 4 → B
index 5 → B
index 6 → B
index 7 → null
```

### 5. Empty layer resolves null

* Layer with no frames
* Any frame index resolves null

### 6. Total frame count

* Multiple layers with different exposure lengths
* Verify totalFrameCount is max exposure length

### 7. Create drawing frame

* Select a timeline frame with no resolved frame
* Create a new drawing frame for a layer
* Verify the layer now has a new frame
* Verify no dense frames were created for skipped indexes

---

## canvas_controller_test.dart Updates

Add or update tests to verify:

### 1. Drawing uses current timeline frame

* Create layer with Frame A duration 1 and Frame B duration 1
* Select timeline index 0
* Draw
* Verify stroke added to Frame A
* Select timeline index 1
* Draw
* Verify stroke added to Frame B

### 2. Drawing creates sparse frame when no frame exists

* Select timeline index 10
* Draw
* Verify exactly one new frame is created
* Verify no frames were created for indexes 2 through 9
* Verify new frame contains the stroke

### 3. Drawing still targets active layer

* Create two layers
* Select layer 2
* Select timeline index 0
* Draw
* Verify stroke is added to layer 2's resolved frame
* Verify layer 1's frame is unchanged

### 4. Undo / redo still works

* Draw at a timeline frame
* Undo
* Verify stroke removed
* Redo
* Verify stroke restored

---

## timeline_panel_test.dart

Required test cases:

### 1. Renders timeline cells

* Pump `TimelinePanel`
* Verify frame cells are visible

### 2. Select frame callback

* Tap a frame cell
* Verify callback receives the correct frame index

### 3. Highlights current frame

* Pump with currentFrameIndex = 3
* Verify selected/highlighted frame is visually represented in a testable way if practical
* For example, use text like `Frame 3` or a key

Keep widget tests simple.

No golden tests.

---

## canvas_view_test.dart Updates

If `CanvasView` API changes, update tests.

Required behavior still:

* CanvasView renders
* Drag gesture creates a stroke in the active layer at the current timeline frame

---

## layer_controller_test.dart Updates

Update only if `LayerController` behavior changes.

Layer tests from Phase 6 should still pass.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/ui test/controllers test/ui lib/main.dart
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run `dart format lib test` unless necessary, because that may reformat unrelated files.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes

---

## Completion Criteria

This task is complete only when:

* `TimelineController` exists
* `TimelinePanel` exists
* UI can select current timeline frame index
* Sparse frame/exposure resolution works
* Frame duration is used as exposure length
* Drawing uses active layer + current timeline frame
* Drawing creates a new sparse frame only when no frame exists at the current timeline index
* Drawing does not create dense empty frames for skipped indexes
* Canvas paints only the resolved frame for each visible layer
* Hidden layers still do not paint
* Layer opacity still affects strokes
* Existing Layer MVP still works
* Existing Undo/Redo for drawing still works
* Timeline tests pass
* Canvas controller tests pass
* Timeline panel widget tests pass
* No playback is added
* No onion skin is added
* No advanced timeline editing is added
* No bitmap engine is added
* No advanced brush engine is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 8.

Do not implement playback, onion skin, audio, frame block dragging, exposure handles, layer masks, blend modes, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only the minimal sparse timeline MVP.
