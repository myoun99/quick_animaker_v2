# Phase 10 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 10: Frame Exposure Editing MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 9 are already complete.

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
lib/src/controllers/timeline_controller.dart
lib/src/ui/home_page.dart
lib/src/ui/canvas/
lib/src/ui/timeline/
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
* ProjectRepository
* Command-based undo/redo MVP
* JSON save/load services
* Basic canvas drawing
* Layer MVP
* Layer visibility
* Layer opacity
* Sparse timeline MVP
* Timeline frame selection
* Horizontal layer timeline grid
* Vertical X-sheet timeline grid
* Integrated timeline/layer UI
* App starts with layers but no initial frames
* Drawing creates sparse frames only as needed
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
docs/Phase_7_Codex_Task.md
docs/Phase_8_Codex_Task.md
docs/Phase_9_Codex_Task.md
```

This task implements only Phase 10.

---

## Scope

Implement only:

```text
Phase 10: Frame Exposure Editing MVP
```

The goal is to allow simple editing of sparse frame exposure duration.

This phase should allow:

1. Selecting a layer and timeline frame.
2. Detecting whether the selected timeline frame has a resolved drawing/exposure.
3. Creating a drawing frame at the selected timeline frame.
4. Increasing the selected drawing frame's exposure duration.
5. Decreasing the selected drawing frame's exposure duration.
6. Preventing duration from going below 1.
7. Visually distinguishing drawing-start cells from held exposure cells.
8. Keeping sparse timeline behavior.
9. Keeping drawing, layer controls, opacity, visibility, Undo/Redo, and X-sheet mode working.

This is an MVP exposure editing phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Frame block dragging
* Exposure handle dragging
* Frame copy/paste
* Frame delete
* Frame reorder
* Layer reorder
* Cut/clip editing
* Thumbnail rendering
* Waveforms
* Keyframe interpolation
* Advanced save/load UI
* File picker UI
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

Do not implement Phase 11 or later.

This phase must stay focused on minimal frame exposure editing.

---

## Core Sparse Timeline Rule

Do not create dense frame data for every timeline index.

Do not duplicate stroke data into held frames.

Correct direction:

```text
Frame A starts at index 0, duration 4
Frame B starts at index 4, duration 2

Timeline:
0 → Frame A drawing start
1 → Frame A held exposure
2 → Frame A held exposure
3 → Frame A held exposure
4 → Frame B drawing start
5 → Frame B held exposure
```

Wrong direction:

```text
0 → Frame A copy
1 → Frame A copy
2 → Frame A copy
3 → Frame A copy
4 → Frame B copy
5 → Frame B copy
```

Sparse frame/exposure behavior must be preserved.

---

## Current Timeline Interpretation

The project currently uses the Phase 7 MVP interpretation:

```text
Within each Layer:
- Layer.frames is an ordered list of sparse exposure blocks.
- Each Frame.duration is the exposure length.
- TimelineController.resolveFrameForLayer() walks the frame list and accumulates duration.
```

Example:

```text
Layer.frames:
  Frame A duration 4
  Frame B duration 3

resolve index 0 → Frame A
resolve index 1 → Frame A
resolve index 2 → Frame A
resolve index 3 → Frame A
resolve index 4 → Frame B
resolve index 5 → Frame B
resolve index 6 → Frame B
resolve index 7 → null
```

Keep this interpretation for Phase 10.

Do not redesign the model into a full exposure map yet.

Do not add `Frame.startFrame` yet unless absolutely necessary.

---

## Required UX

Add simple controls for selected frame exposure editing.

The UI can be plain and functional.

Suggested controls near the top debug controls or inside the timeline panel:

```text
Selected: Layer 1 / Frame 4
Drawing: yes
Duration: 3
[New Drawing] [- Exposure] [+ Exposure]
```

Required behavior:

### New Drawing

When the selected layer and timeline index has no resolved frame:

* Create one new sparse `Frame`.
* Duration should default to 1.
* Do not create frames for skipped indexes.
* Do not duplicate any previous frame's strokes.
* Select/keep the same timeline frame.

When the selected layer and timeline index already resolves to an existing frame:

* Either do nothing, or keep the button disabled.
* Prefer disabling the button if practical.

### Increase Exposure

When selected layer and timeline index resolves to a frame:

* Increase that resolved frame's `duration` by 1.
* The held exposure should visually expand by one timeline frame.
* Do not duplicate stroke data.
* Do not create a new frame.
* Do not modify other layers.

When no frame is resolved:

* Button should be disabled, or do nothing.

### Decrease Exposure

When selected layer and timeline index resolves to a frame:

* Decrease that frame's `duration` by 1.
* Do not allow duration below 1.
* If duration is already 1, do nothing or keep the button disabled.

When no frame is resolved:

* Button should be disabled, or do nothing.

---

## TimelineController Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Add minimal helper methods for exposure editing.

Suggested API:

```dart
Frame? getSelectedFrameForLayer(Layer layer);

FrameId? getSelectedFrameIdForLayer(Layer layer);

bool hasSelectedFrameForLayer(Layer layer);

bool isDrawingStartForLayer({
  required Layer layer,
  required int frameIndex,
});

bool isHeldExposureForLayer({
  required Layer layer,
  required int frameIndex,
});

int? exposureStartIndexForLayer({
  required Layer layer,
  required FrameId frameId,
});

void createDrawingFrameForLayer({
  required LayerId layerId,
  required FrameId frameId,
  int duration = 1,
});

void increaseExposure({
  required LayerId layerId,
  required FrameId frameId,
});

void decreaseExposure({
  required LayerId layerId,
  required FrameId frameId,
});
```

You may adjust exact method names if clearer.

Important implementation notes:

* `increaseExposure` should update only the target frame's duration.
* `decreaseExposure` should clamp duration to a minimum of 1.
* Missing layer/frame should throw a clear `StateError`.
* Duration must remain >= 1.
* Keep controller plain Dart.
* Do not use Provider/Riverpod/Bloc.

---

## ProjectRepository Support

If existing repository methods are enough, use them.

If needed, add minimal frame update support:

```dart
void updateFrame({
  required FrameId frameId,
  required Frame Function(Frame frame) update,
});
```

Rules:

* Preserve immutability.
* Rebuild the parent chain.
* Throw clear errors if the target frame is missing.
* Do not implement unrelated repository features.
* Add tests if repository methods are added or changed.

Do not modify save/load services unless absolutely necessary.

---

## Frame Start vs Held Exposure Display

Update timeline grid display so cells can distinguish:

```text
Drawing start cell
Held exposure cell
Empty cell
```

Use a simple visual representation.

Suggested symbols:

```text
● = drawing start
─ = held exposure
blank = empty
```

Example:

```text
Layer 1 | [●][─][─][ ][●][─][ ]
```

For X-sheet:

```text
Frame | Layer 1
  0   | ●
  1   | ─
  2   | ─
  3   |
  4   | ●
  5   | ─
```

Implementation guidance:

* Use `TimelineController.isDrawingStartForLayer(...)` or equivalent helper.
* Use `TimelineController.isHeldExposureForLayer(...)` or equivalent helper.
* If no helper is added, the UI may compute it through a resolver callback.
* Keep UI simple.

Do not add thumbnails.

Do not render mini stroke previews.

---

## TimelinePanel / Grid Changes

Update:

```text
lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

The grids should receive enough information to display cell state.

Suggested enum:

```dart
enum TimelineCellExposureState {
  empty,
  drawingStart,
  heldExposure,
}
```

This can be created under:

```text
lib/src/ui/timeline/timeline_cell_exposure_state.dart
```

or implemented privately if simpler.

Suggested callback:

```dart
TimelineCellExposureState Function(Layer layer, int frameIndex) exposureStateForLayer;
```

Then:

* Horizontal grid uses this to show `●`, `─`, or blank.
* X-sheet grid uses this to show `●`, `─`, or blank.
* Existing marker tests should be updated.

Keep the old `resolveFrameForLayer` callback only if still needed.

---

## HomePage Changes

Update `HomePage` to wire exposure editing.

Responsibilities:

* Identify active layer.
* Identify selected/resolved frame at current timeline index.
* Show selected frame duration if one exists.
* Provide New Drawing, Increase Exposure, Decrease Exposure controls.
* Update UI using `setState`.
* Keep Undo/Redo buttons working.
* Keep layer integrated timeline controls working.
* Keep timeline orientation toggle working.
* Keep drawing behavior working.

Suggested helper methods in HomePage:

```dart
Layer? get _activeLayer;
Frame? get _selectedFrame;

void _createDrawingAtCurrentFrame();
void _increaseSelectedExposure();
void _decreaseSelectedExposure();
```

For new drawing frame ID, use a simple unique ID similar to current drawing frame creation logic.

Do not redesign the whole app shell.

Do not introduce app-wide state management.

---

## Undo/Redo

For this phase, exposure editing does not need full undo/redo support unless it is already easy.

Required:

* Existing stroke Undo/Redo must continue working.
* Existing "move to target frame first, then undo" behavior must continue working.

Acceptable for Phase 10:

* New Drawing / Increase Exposure / Decrease Exposure may update repository directly without undo/redo.
* Full command support for exposure editing can be added in a later phase.

Do not break existing HistoryManager tests.

---

## Tests

Create and update tests under:

```text
test/controllers/
test/ui/
test/services/
```

Only add service tests if repository methods are added.

---

## timeline_controller_test.dart

Add tests for:

### 1. Drawing start detection

Layer:

```text
Frame A duration 3
Frame B duration 2
```

Verify:

```text
index 0 → drawing start
index 1 → held exposure
index 2 → held exposure
index 3 → drawing start
index 4 → held exposure
index 5 → empty
```

### 2. Held exposure detection

Verify held exposure returns true only for indexes inside a frame's duration but not at the frame start.

### 3. Increase exposure

* Frame duration starts at 1.
* Increase exposure.
* Verify duration becomes 2.
* Verify no new frame is created.

### 4. Decrease exposure

* Frame duration starts at 3.
* Decrease exposure.
* Verify duration becomes 2.

### 5. Decrease exposure does not go below 1

* Frame duration starts at 1.
* Decrease exposure.
* Verify duration remains 1.

### 6. Missing frame/layer errors

* Updating missing frame/layer should throw clear `StateError`.

### 7. Sparse behavior preserved

* Select timeline index 10.
* Create drawing frame.
* Verify exactly one frame exists.
* Verify no frames were created for indexes 0 through 9.

---

## project_repository_test.dart

Only update if repository methods are added.

If `updateFrame` is added, test:

* Updates only the target frame.
* Keeps other frames unchanged.
* Throws for missing frame.
* Preserves immutable replacement behavior.

---

## layer_timeline_grid_test.dart

Update tests for exposure display.

Required:

### 1. Shows drawing start marker

* Provide exposure state callback returning `drawingStart`.
* Verify `●` is shown.

### 2. Shows held exposure marker

* Provide exposure state callback returning `heldExposure`.
* Verify `─` is shown.

### 3. Empty cell stays empty

* Provide exposure state callback returning `empty`.
* Verify no marker.

### 4. Existing layer controls still work

* Add layer button
* Visibility button
* Opacity control
* Layer name selection
* Cell frame selection

---

## xsheet_timeline_grid_test.dart

Same as horizontal grid:

* Drawing start marker
* Held exposure marker
* Empty cell
* Add layer button
* Visibility button
* Opacity control
* Layer name selection
* Cell frame selection

---

## timeline_panel_test.dart

Update tests to verify callback forwarding.

Required:

* Exposure state callback is used in horizontal mode.
* Exposure state callback is used in vertical mode.
* Orientation toggle still works.
* Add layer callback still works.
* Visibility callback still works.
* Opacity callback still works.
* Layer selection callback still works.
* Frame selection callback still works.

---

## HomePage / Widget Tests

If practical, add a simple widget test that verifies exposure controls render.

Do not overcomplicate this.

Required behavior should be covered by controller and grid tests at minimum.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/services lib/src/ui test/controllers test/services test/ui lib/main.dart
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

* Selected layer/current timeline frame can be inspected.
* New drawing frame can be created at selected empty timeline frame.
* New drawing creation remains sparse.
* Selected frame exposure duration can be increased.
* Selected frame exposure duration can be decreased.
* Duration never goes below 1.
* Drawing-start cells are visually distinct.
* Held exposure cells are visually distinct.
* Empty cells remain visually distinct.
* Horizontal timeline still works.
* Vertical X-sheet still works.
* Integrated layer controls still work.
* Existing drawing still works.
* Existing layer visibility/opacity still works.
* Existing stroke Undo/Redo still works.
* No dense frame duplication is introduced.
* No playback is added.
* No exposure dragging is added.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 11.

Do not implement playback, onion skin, exposure handle dragging, frame block dragging, copy/paste, delete, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only minimal frame exposure editing.
