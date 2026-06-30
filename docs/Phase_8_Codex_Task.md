# Phase 8 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 8: Timeline UI Layout MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 7 are already complete.

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
* Basic visible canvas
* Basic stroke drawing
* Layer MVP
* Layer selection
* Layer visibility
* Layer opacity
* Timeline MVP
* Sparse frame/exposure behavior
* Current timeline frame selection
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
```

This task implements only Phase 8.

---

## Scope

Implement only:

```text
Phase 8: Timeline UI Layout MVP
```

The goal is to improve the timeline UI layout, not to add advanced timeline editing.

The current timeline is a simple horizontal list of frame buttons.

Phase 8 should replace or evolve it into a proper animation timeline grid.

This phase should allow:

1. A timeline panel that visually connects layers and frame cells
2. A horizontal timeline grid by default
3. A vertical X-sheet style timeline mode
4. Switching between horizontal and vertical timeline orientation
5. Selecting the active layer from the timeline row/column
6. Selecting the current timeline frame index from the grid
7. Displaying which cells contain drawings/exposures
8. Showing the current frame/playhead clearly
9. Keeping existing Layer MVP behavior working
10. Keeping existing sparse timeline behavior working

This is a UI layout MVP.

---

## Visual Direction

Use the following references as design inspiration:

* Krita animation timeline: layer list on the left, frames extending horizontally to the right
* Clip Studio Paint animation timeline: layer/track rows with frame cells
* OpenToonz / TVPaint X-sheet: frame numbers vertically, columns for layers
* Traditional Japanese animation exposure sheets: vertical frame rows with columns for layers
* Storyboard/clip timeline tools only as long-term inspiration, not for this phase

The default should be:

```text
Horizontal timeline grid

Layer 1 | [●][ ][ ][ ][●][ ][ ]
Layer 2 | [ ][ ][●][ ][ ][ ][ ]
Layer 3 | [●][ ][ ][ ][ ][●][ ]
```

The optional view mode should be:

```text
Vertical X-sheet grid

Frame | Layer 1 | Layer 2 | Layer 3
  0   |   ●     |         |   ●
  1   |   |     |         |   |
  2   |   |     |   ●     |   |
  3   |         |   |     |
```

For this phase, the visual design can be simple and functional.

Do not try to make final production UI.

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

Do not implement Phase 9 or later.

This phase must stay focused on timeline UI layout only.

---

## Core Rule

Do not change the sparse frame/exposure model behavior from Phase 7 unless absolutely necessary.

Phase 8 is primarily UI.

The timeline should still use:

```text
Layer.frames as sparse exposure blocks
Frame.duration as exposure length
TimelineController.resolveFrameForLayer()
```

Do not create dense frame data for every timeline index.

Do not duplicate stroke data into held frames.

Do not add new model fields unless absolutely necessary.

---

## Required Folder Structure

Use the existing timeline UI folder:

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
        timeline_orientation.dart
        layer_timeline_grid.dart
        xsheet_timeline_grid.dart

test/
  ui/
    timeline_panel_test.dart
    layer_timeline_grid_test.dart
    xsheet_timeline_grid_test.dart
```

You may adjust exact file names if there is a strong reason, but keep responsibilities separated.

---

## Required Files to Create or Modify

You may create:

```text
lib/src/ui/timeline/timeline_orientation.dart
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
```

You may modify:

```text
lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/home_page.dart
test/ui/timeline_panel_test.dart
```

You may modify controller files only if a small read-only helper is needed:

```text
lib/src/controllers/timeline_controller.dart
lib/src/controllers/layer_controller.dart
```

Do not modify model files unless absolutely necessary.

Do not modify repository, command, history, persistence, or existing service files unless absolutely necessary.

---

## TimelineOrientation

Create:

```text
lib/src/ui/timeline/timeline_orientation.dart
```

Define a simple enum:

```dart
enum TimelineOrientation {
  horizontal,
  vertical,
}
```

This is UI-only.

Do not confuse it with device orientation.

---

## TimelinePanel

Update:

```text
lib/src/ui/timeline/timeline_panel.dart
```

Responsibilities:

* Own the timeline orientation toggle UI
* Show current frame index
* Display either horizontal layer timeline grid or vertical X-sheet grid
* Pass layer/frame selection callbacks to child widgets
* Keep API simple

Suggested constructor:

```dart
class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.resolveFrameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    required this.orientation,
    required this.onOrientationChanged,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int frameCount;
  final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;
}
```

You may keep backwards compatibility with the old simpler API only if useful for tests, but prefer updating tests to the new layout.

---

## Horizontal Layer Timeline Grid

Create:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
```

Responsibilities:

* Render a Krita/Clip Studio style horizontal timeline
* Show layers as rows
* Show frame indices as columns
* Select active layer by tapping a layer row/header
* Select current frame by tapping a frame cell
* Show drawing/exposure presence in cells
* Show current frame/playhead visually
* Keep layout scrollable horizontally if needed

Suggested constructor:

```dart
class LayerTimelineGrid extends StatelessWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.resolveFrameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int frameCount;
  final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
}
```

Suggested visual behavior:

* Left fixed-ish column: layer names
* Right scrollable grid: frame cells
* Frame header row: 0, 1, 2, 3...
* Each layer row has cells
* Cell with resolved frame: show a dot, small mark, or short text
* Current frame cell: highlighted background or border
* Active layer row: highlighted background
* Use keys for testability:

    * `timeline-layer-row-<layerId>`
    * `timeline-cell-<layerId>-<frameIndex>`
    * `timeline-frame-header-<frameIndex>`

Do not implement drag editing.

Do not implement exposure handles.

Do not implement thumbnails.

---

## Vertical X-sheet Timeline Grid

Create:

```text
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

Responsibilities:

* Render an OpenToonz / TVPaint style vertical X-sheet
* Show frame indices as rows
* Show layers as columns
* Select current frame by tapping a frame row/cell
* Select active layer by tapping a layer column/header/cell
* Show drawing/exposure presence in cells
* Show current frame/playhead visually
* Keep layout scrollable vertically if needed

Suggested constructor:

```dart
class XSheetTimelineGrid extends StatelessWidget {
  const XSheetTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.resolveFrameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int frameCount;
  final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
}
```

Suggested visual behavior:

* Top header row: layer names
* Left column: frame indices
* Main grid: frame/layer cells
* Cell with resolved frame: show a dot, small mark, or text
* Current frame row: highlighted
* Active layer column/cells: highlighted
* Use keys for testability:

    * `xsheet-layer-header-<layerId>`
    * `xsheet-frame-row-<frameIndex>`
    * `xsheet-cell-<layerId>-<frameIndex>`

Do not implement final X-sheet production UI.

Do not implement drag editing.

Do not implement exposure handles.

---

## Drawing / Exposure Cell Display

For each layer and frame index:

Use:

```dart
resolveFrameForLayer(layer, frameIndex)
```

If it returns a frame:

* Show a small marker
* The marker can be:

    * `●`
    * `•`
    * `K`
    * frame id short text
* Keep it simple.

For this phase, it is okay if the UI cannot visually distinguish:

* start of exposure
* held exposure

But if practical, show:

* stronger marker for the first frame of a drawing block
* lighter marker for held frames

This is optional.

Do not add model changes just for this.

---

## HomePage Changes

Update `HomePage` to:

* Hold a local `TimelineOrientation` state
* Pass layers, active layer id, current frame index, frame count, and resolver into `TimelinePanel`
* Keep canvas, layer panel, and debug controls working
* Keep timeline selection updating the canvas
* Keep layer selection updating the active layer
* Keep Undo/Redo working

Suggested layout:

```text
Top: debug controls
Center: canvas + layer panel
Bottom: timeline panel
```

For vertical X-sheet mode, it is acceptable to keep the same bottom panel area and show the X-sheet grid inside it.

Do not redesign the whole app shell yet.

---

## Tests

Create and update tests under:

```text
test/ui/
```

---

## timeline_panel_test.dart

Update tests to cover:

### 1. Renders horizontal mode

* Pump `TimelinePanel` with `TimelineOrientation.horizontal`
* Verify `LayerTimelineGrid` or a known horizontal cell key exists

### 2. Renders vertical mode

* Pump `TimelinePanel` with `TimelineOrientation.vertical`
* Verify `XSheetTimelineGrid` or a known X-sheet cell key exists

### 3. Orientation toggle callback

* Tap the orientation toggle
* Verify callback receives the other orientation

### 4. Select frame callback still works

* Tap a frame cell
* Verify callback receives correct frame index

### 5. Select layer callback still works

* Tap a layer row/header/cell
* Verify callback receives correct `LayerId`

---

## layer_timeline_grid_test.dart

Required test cases:

### 1. Renders layer names

* Pump grid with two layers
* Verify both layer names are visible

### 2. Renders frame cells

* Verify cells exist by key, for example:

    * `timeline-cell-layer-1-0`
    * `timeline-cell-layer-2-0`

### 3. Selects frame

* Tap a cell at frame index 3
* Verify `onSelectFrame(3)` is called

### 4. Selects layer

* Tap a layer row/header
* Verify correct `LayerId` is sent

### 5. Shows drawing marker

* Provide `resolveFrameForLayer` that returns a frame for a certain cell
* Verify the marker is shown

### 6. Highlights current frame

* Use keys or text to verify current frame cell/header is present and testable

---

## xsheet_timeline_grid_test.dart

Required test cases:

### 1. Renders layer headers

* Pump grid with two layers
* Verify layer names are visible

### 2. Renders frame rows/cells

* Verify cells exist by key, for example:

    * `xsheet-cell-layer-1-0`
    * `xsheet-cell-layer-2-0`

### 3. Selects frame

* Tap a cell or frame row at frame index 3
* Verify `onSelectFrame(3)` is called

### 4. Selects layer

* Tap a layer header or cell
* Verify correct `LayerId` is sent

### 5. Shows drawing marker

* Provide `resolveFrameForLayer` that returns a frame for a certain cell
* Verify marker is shown

### 6. Highlights current frame

* Use keys or text to verify current frame row/cell is present and testable

---

## Existing Tests

Update existing tests if the `TimelinePanel` API changes.

The full test suite must still pass.

Do not remove existing tests unless they are obsolete and replaced by better coverage.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/ui/timeline lib/src/ui/home_page.dart test/ui
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

* `TimelineOrientation` exists
* Horizontal layer timeline grid exists
* Vertical X-sheet timeline grid exists
* TimelinePanel can switch between horizontal and vertical mode
* HomePage wires orientation switching
* Layer names are visually connected to frame cells
* Current frame index is visually indicated
* Active layer is visually indicated
* Cells with resolved drawing/exposure are marked
* Selecting a frame cell updates the current timeline frame
* Selecting a layer row/column updates the active layer
* Existing canvas drawing still works
* Existing layer visibility/opacity still works
* Existing sparse frame/exposure behavior is not broken
* No playback is added
* No advanced frame editing is added
* No dense frame duplication is added
* No state management package is added
* `flutter analyze` passes
* `flutter test` passes

---

## Reminder

Do not implement Phase 9.

Do not implement playback, onion skin, exposure handles, frame dragging, frame copy/paste, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only the timeline UI layout MVP.
