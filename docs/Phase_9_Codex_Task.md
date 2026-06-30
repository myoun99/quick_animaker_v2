# Phase 9 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 9: Timeline + Layer UI Integration MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 8 are already complete.

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
lib/src/ui/layers/
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
* Timeline MVP
* Sparse frame/exposure behavior
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* Timeline orientation toggle
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
```

This task implements only Phase 9.

---

## Scope

Implement only:

```text
Phase 9: Timeline + Layer UI Integration MVP
```

The goal is to integrate layer controls into the timeline UI and remove the separate right-side layer panel.

This phase should allow:

1. The app to start with layers but no drawing frames.
2. The first stroke at a selected timeline index to create the first sparse frame.
3. The timeline ruler to show plain frame numbers without a triangle text prefix.
4. Layer controls to live inside the timeline panel instead of a separate right-side layer panel.
5. Horizontal timeline mode to show layer controls at the left of each layer row.
6. Vertical X-sheet mode to show layer controls in layer headers.
7. Add layer, select layer, toggle visibility, and opacity control to remain available.
8. Canvas drawing, sparse timeline behavior, layer visibility, opacity, and undo/redo to keep working.
9. Undo should move to the target frame first if the next undoable stroke is on a different timeline frame, then undo on the next press.

This is still an MVP UI integration phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Frame block dragging
* Exposure length handles
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

Do not implement Phase 10 or later.

This phase must stay focused on timeline/layer UI integration and the minimal undo navigation behavior described below.

---

## Required UX Changes

### 1. Start with Empty Frames

Currently the sample project starts with a frame at timeline index 0.

Change the sample project used by `HomePage` so that:

```text
Project
 └ Track
    └ Cut
       └ Layer 1 with no frames
       └ Layer 2 with no frames
```

Rules:

* Initial layers should still exist.
* Initial frames should not exist.
* Timeline should show empty cells on first launch.
* Drawing at frame 0 should create one sparse frame at frame 0.
* Drawing at frame 10 should create one sparse frame at frame 10.
* Do not create dense frames for skipped indexes.

This change should be limited to the sample/demo project initialization unless broader changes are absolutely necessary.

---

### 2. Remove Triangle Text from Timeline Ruler

Currently the selected frame header may display text like:

```text
▶ 0
```

Change it to plain text:

```text
0
```

Rules:

* Current frame should still be visually highlighted by color, border, or another non-text indicator.
* Do not use a triangle character in the frame number text.
* Apply this to both horizontal timeline and vertical X-sheet frame labels if needed.

---

### 3. Remove Separate Right-Side Layer Panel

The app currently has a separate right-side `LayerPanel`.

Remove it from the main `HomePage` layout.

Layer operations should move into the timeline UI.

Do not delete the old `LayerPanel` file unless it is unused and tests can be safely updated. Prefer leaving it for now if deletion would create unnecessary churn.

The main app layout after this phase should be closer to:

```text
Top: debug controls
Center: canvas
Bottom: integrated timeline + layer controls
```

The timeline should be the main place where layer controls live.

---

## Integrated Layer Controls

### Horizontal Timeline Mode

In `LayerTimelineGrid`, the left side layer column should include simple layer controls.

For each layer row, include:

* Layer name
* Select layer behavior
* Visibility toggle
* Opacity control or compact opacity display/control
* Active layer highlight

Also include an Add Layer button near the layer header area.

Suggested horizontal layout:

```text
+ Layer
Layer 1  👁 100% | [ ][●][ ][ ][ ]
Layer 2  👁  50% | [●][ ][ ][ ][ ]
```

Implementation can be simple. It does not need to look final.

### Vertical X-sheet Mode

In `XSheetTimelineGrid`, layer controls should appear in the layer header.

For each layer column/header, include:

* Layer name
* Select layer behavior
* Visibility toggle
* Opacity control or compact opacity display/control
* Active layer highlight

Also include an Add Layer button in the header area if practical.

Suggested vertical layout:

```text
Frame | + Layer | Layer 1 👁 100% | Layer 2 👁 50%
  0   |         |       ●         |
  1   |         |                 |
```

Implementation can be simple. It does not need to be final production UI.

---

## TimelinePanel API

Update `TimelinePanel` as needed to support layer operations directly.

Suggested additional fields:

```dart
final VoidCallback onAddLayer;
final ValueChanged<LayerId> onToggleLayerVisibility;
final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
```

Existing fields should remain conceptually similar:

```dart
final List<Layer> layers;
final LayerId? activeLayerId;
final int currentFrameIndex;
final int frameCount;
final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
final ValueChanged<LayerId> onSelectLayer;
final ValueChanged<int> onSelectFrame;
final TimelineOrientation orientation;
final ValueChanged<TimelineOrientation> onOrientationChanged;
```

Do not introduce Provider/Riverpod/Bloc.

Keep state in `HomePage` for now.

---

## LayerTimelineGrid Changes

Update:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
```

Responsibilities after this phase:

* Render horizontal layer timeline grid.
* Show layer names and layer controls in the left column.
* Provide Add Layer control.
* Select layers from layer row/control area.
* Toggle layer visibility from layer row.
* Change opacity from layer row.
* Select frames from cells.
* Mark cells with resolved drawing/exposure.
* Highlight current frame.
* Highlight active layer.
* Use plain frame number text, no triangle prefix.

Suggested additional constructor parameters:

```dart
final VoidCallback onAddLayer;
final ValueChanged<LayerId> onToggleLayerVisibility;
final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
```

Use testable keys such as:

```text
timeline-add-layer-button
timeline-layer-visibility-<layerId>
timeline-layer-opacity-<layerId>
timeline-layer-row-<layerId>
timeline-cell-<layerId>-<frameIndex>
timeline-frame-header-<frameIndex>
```

Do not implement drag editing.

Do not implement exposure handles.

Do not implement thumbnails.

---

## XSheetTimelineGrid Changes

Update:

```text
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

Responsibilities after this phase:

* Render vertical X-sheet grid.
* Show layer controls in layer headers.
* Provide Add Layer control if practical.
* Select layer from layer header/cell.
* Toggle layer visibility from layer header.
* Change opacity from layer header.
* Select frames from frame rows/cells.
* Mark cells with resolved drawing/exposure.
* Highlight current frame.
* Highlight active layer.
* Use plain frame number text, no triangle prefix.

Suggested additional constructor parameters:

```dart
final VoidCallback onAddLayer;
final ValueChanged<LayerId> onToggleLayerVisibility;
final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
```

Use testable keys such as:

```text
xsheet-add-layer-button
xsheet-layer-header-<layerId>
xsheet-layer-visibility-<layerId>
xsheet-layer-opacity-<layerId>
xsheet-frame-row-<frameIndex>
xsheet-cell-<layerId>-<frameIndex>
```

Do not implement final X-sheet production UI.

Do not implement drag editing.

Do not implement exposure handles.

---

## HomePage Changes

Update `HomePage` to:

* Remove the separate right-side `LayerPanel` from the visual layout.
* Keep layer list and layer operations wired through `TimelinePanel`.
* Start the sample project with layers but no frames.
* Keep `CanvasView` in the center.
* Keep debug controls at the top.
* Keep timeline orientation state.
* Keep add layer functionality.
* Keep visibility and opacity functionality.
* Keep current frame selection.
* Keep active layer selection.
* Keep undo/redo buttons.

Recommended layout:

```text
Top: debug controls
Center: canvas
Bottom: TimelinePanel with integrated layer controls
```

Do not redesign the whole app shell.

---

## Minimal Undo Navigation Behavior

Add a minimal UI-friendly undo behavior:

```text
If the next undoable drawing operation affects a different timeline frame than the current frame:
  First Undo press moves the timeline to that frame.
  It does not undo yet.
Second Undo press, while already on that frame:
  Performs the actual undo.
```

Example:

```text
Current timeline frame: 5
Last stroke was drawn on frame 2
User presses Undo
→ timeline moves to frame 2
→ stroke is still visible
User presses Undo again
→ stroke is removed
```

Purpose:

* Avoid surprising deletion of strokes on frames the user is not currently viewing.
* Make Undo behavior clearer for animation timeline editing.

### Implementation Guidance

Keep this minimal.

Do not rewrite the entire command/history system unless necessary.

Preferred approach:

* Track the timeline frame index associated with stroke drawing commands at UI/controller level.
* Add a way for `CanvasController` or `HomePage` to know the timeline frame index of the next undoable drawing command.
* When Undo is pressed:

    1. Ask for the target timeline frame index of the next undoable stroke operation.
    2. If it exists and differs from `TimelineController.currentFrameIndex`, only move the timeline to that index.
    3. If it is the same as current frame, perform undo.

This behavior only needs to cover stroke drawing commands for now.

It is acceptable if non-stroke commands still undo immediately.

### Acceptable MVP Implementation

It is acceptable to add a small undo metadata stack in `CanvasController`, for example:

```dart
final List<int> _strokeUndoFrameIndices = <int>[];
final List<int> _strokeRedoFrameIndices = <int>[];
```

When a stroke is successfully added:

```text
push current timeline frame index to undo metadata stack
clear redo metadata stack
```

When undo actually runs:

```text
pop from undo metadata stack
push to redo metadata stack
call HistoryManager.undo()
```

When redo actually runs:

```text
pop from redo metadata stack
push to undo metadata stack
move to that frame if needed or redo immediately depending existing behavior
call HistoryManager.redo()
```

But keep this simple and tested.

If implementing redo navigation would complicate the phase too much, only implement undo navigation and preserve existing redo behavior.

### Required Undo Tests

Add tests for:

1. Undo on same frame removes stroke immediately.

Steps:

```text
select frame 0
draw stroke
press undo through new controller/UI method
verify stroke removed
```

2. Undo on different frame moves first.

Steps:

```text
select frame 0
draw stroke
select frame 5
press undo through new controller/UI method
verify current frame becomes 0
verify stroke still exists
press undo again
verify stroke removed
```

3. Existing basic undo/redo tests still pass.

Keep tests simple.

---

## Tests

Update and add tests under:

```text
test/ui/
test/controllers/
```

---

## HomePage / Widget Tests

If there are existing HomePage tests, update them.

Otherwise, widget tests can focus on timeline widgets.

Required behavior should be covered somewhere:

* Right-side `LayerPanel` is no longer required in HomePage.
* Integrated timeline has Add Layer control.
* Integrated timeline has visibility toggle.
* Integrated timeline has opacity control.
* Timeline cell can select layer and frame.
* Orientation toggle still works.
* Frame headers do not include triangle text.

---

## layer_timeline_grid_test.dart Updates

Required test cases:

1. Renders integrated layer controls.
2. Add Layer button calls `onAddLayer`.
3. Visibility button calls `onToggleLayerVisibility`.
4. Opacity control calls `onLayerOpacityChanged`.
5. Selecting a cell still selects layer and frame.
6. Current frame header uses plain text, not triangle-prefixed text.
7. Drawing/exposure marker still appears.

---

## xsheet_timeline_grid_test.dart Updates

Required test cases:

1. Renders integrated layer controls in headers.
2. Add Layer button calls `onAddLayer`.
3. Visibility button calls `onToggleLayerVisibility`.
4. Opacity control calls `onLayerOpacityChanged`.
5. Selecting a cell still selects layer and frame.
6. Current frame row uses plain text, not triangle-prefixed text.
7. Drawing/exposure marker still appears.

---

## timeline_panel_test.dart Updates

Required test cases:

1. Horizontal mode renders integrated layer timeline.
2. Vertical mode renders integrated X-sheet timeline.
3. Orientation toggle still works.
4. Add layer callback is forwarded.
5. Visibility callback is forwarded.
6. Opacity callback is forwarded.

---

## canvas_controller_test.dart Updates

Add tests for undo navigation behavior if implemented in `CanvasController`.

If implemented in `HomePage`, add widget-level test instead.

Required behavior:

* Undo on a different timeline frame moves first and does not delete.
* Second undo on that frame deletes.

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

* App starts with layers but no initial frames.
* Drawing creates sparse frames as needed.
* Timeline frame ruler/header no longer uses triangle text.
* Separate right-side LayerPanel is removed from HomePage layout.
* Layer selection is available in the timeline UI.
* Add layer is available in the timeline UI.
* Visibility toggle is available in the timeline UI.
* Opacity control is available in the timeline UI.
* Horizontal timeline mode works.
* Vertical X-sheet mode works.
* Existing sparse exposure behavior is preserved.
* Existing drawing still works.
* Existing layer visibility/opacity still works.
* Existing undo/redo still works.
* Undo on a stroke from a different timeline frame moves to that frame first.
* Second undo removes the stroke.
* No playback is added.
* No exposure handles are added.
* No drag frame editing is added.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 10.

Do not implement playback, onion skin, exposure handles, frame dragging, frame copy/paste, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only timeline/layer UI integration plus minimal undo navigation behavior.
