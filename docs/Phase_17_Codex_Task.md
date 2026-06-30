# Phase 17 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 17: Timeline Selection UX MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 16 and related follow-up fixes are already complete.

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
* Command-based Undo/Redo MVP
* JSON save/load services
* Basic canvas drawing
* Layer MVP
* Layer visibility
* Layer opacity
* Integrated timeline/layer UI
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* SplayTreeMap-based timeline exposure map
* `TimelineExposure`
* `TimelineExposureType`
* Drawing exposure entries
* Blank/null exposure entries
* Drawing frame heads displayed as `○`
* Blank/null heads displayed as `X`
* Blank/null held regions displayed with subtle low-emphasis styling
* `TimelineMark`
* `TimelineMarkType`
* Sparse per-layer marks map
* `●` inbetween/timesheet mark
* Mark toggle Undo/Redo
* Mark JSON save/load
* `New Frame` button
* `Blank / X` button
* `Mark ●` button
* `Rename Frame` button and dialog
* `Delete Cell` button
* Frame names
* `+ Exposure` and `- Exposure`
* Timeline map edit Undo/Redo
* New layers start with `0 -> blank`
* Initial sample layers start with `0 -> blank`
* Delete Cell deletes only drawingStart cells
* Delete Cell does not delete X
* Delete Cell does not delete mark-only cells
* Mark `●` is removed by the Mark button
* DrawingStart with `●` is deleted together by Delete Cell
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
docs/Phase_10_Codex_Task.md
docs/Phase_11_Codex_Task.md
docs/Phase_12_Codex_Task.md
docs/Phase_13_Codex_Task.md
docs/Phase_14_Codex_Task.md
docs/Phase_15_Codex_Task.md
docs/Phase_16_Codex_Task.md
```

This task implements only Phase 17.

---

## Scope

Implement only:

```text
Phase 17: Timeline Selection UX MVP
```

The goal is to make timeline selection clearer and safer now that the timeline supports:

```text
○ drawing frame head
named drawing frame head
X blank/null exposure head
● inbetween/timesheet mark
held drawing exposure
blank/null held exposure
empty cells
```

This phase should implement:

1. Clear selected cell visual highlight.
2. Clear selected layer row highlight.
3. Current cell status text in the toolbar/status area.
4. Current selected layer name text.
5. Current frame number display.
6. Consistent selection display in horizontal timeline and vertical X-sheet.
7. Button enable/disable behavior consistent with current cell state.
8. Tests for selection/status display and existing behavior preservation.

This is a UX clarity phase.

Do not introduce large new editing features.

---

## Important UX Meaning

The timeline symbols mean:

```text
○ = unnamed drawing frame head
name = named drawing frame head
X = blank/null exposure head
● = timeline mark / inbetween mark / timesheet mark
```

Important:

```text
○ / name changes drawing exposure.
X changes drawing exposure and makes the layer blank/null.
● does not change drawing exposure.
```

Existing rules must remain:

```text
New Frame:
- Creates or replaces with a drawing frame.
- On X, replaces X with ○.

Mark ●:
- Toggles a mark at the current cell.
- Removes mark if mark already exists.

Delete Cell:
- Deletes only drawingStart cells.
- Does not delete X.
- Does not delete mark-only cells.
- If drawingStart has ●, deletes the drawing frame and same-index mark together.

Rename Frame:
- Renames the resolved drawing frame.
```

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Camera layer
* Storyboard layer
* Layer type enum
* Layer sections
* Collapsible timeline sections
* Onion skin
* Double-click behavior
* Long-press behavior
* Right-click menus
* Keyboard shortcuts
* Frame block dragging
* Exposure handle dragging
* Frame copy/paste
* Frame reorder UI
* Layer reorder
* Cut/clip editing
* Thumbnail rendering
* Waveforms
* Keyframe interpolation
* Timesheet export
* PDF export
* CSV export
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

Do not implement Phase 18 or later.

This phase must stay focused on timeline selection/status UX.

---

## Design Direction

The timeline already has current layer and current frame selection internally.

This phase should make those selections visible and understandable.

Add a compact selection/status area near the existing timeline toolbar.

Recommended display:

```text
Layer: Sample Layer 1
Frame: 1
Cell: Blank start (X)
```

When a cell has a mark:

```text
Layer: Sample Layer 1
Frame: 3
Cell: Held drawing + Mark ●
```

When a named drawing frame is selected:

```text
Layer: Sample Layer 1
Frame: 1
Cell: Drawing start: A1
```

Keep it simple. This is not a full inspector panel yet.

---

## Cell Status Definitions

Add a simple UI-facing cell status resolver.

Recommended statuses:

```text
Drawing start
Named drawing start
Held drawing
Blank start
Blank held
Empty
Mark
```

Since marks can coexist with exposure states, the status text should combine them.

Suggested user-facing labels:

```text
Drawing start
Drawing start: A1
Held drawing
Blank start (X)
Blank held
Empty
Drawing start + Mark ●
Drawing start: A1 + Mark ●
Held drawing + Mark ●
Blank start (X) + Mark ●
Blank held + Mark ●
Empty + Mark ●
```

Rules:

* If current cell has mark, append ` + Mark ●`.
* If drawingStart has frame name, show `Drawing start: <name>`.
* If drawingStart has no name, show `Drawing start`.
* If held drawing, show `Held drawing`.
* If blankStart, show `Blank start (X)`.
* If blankHeld, show `Blank held`.
* If empty, show `Empty`.

Keep this resolver simple and testable.

It may live in `HomePage` for MVP, or in `TimelineController` if cleaner.

Preferred MVP:

```text
Keep UI label generation in HomePage or a small UI helper.
Do not add new model concepts.
```

---

## Selected Cell Visual Highlight

Update:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
lib/src/ui/timeline/timeline_panel.dart
```

The selected cell should be clearly visible.

Requirements:

* Horizontal timeline selected cell should have a visible border or highlight.
* X-sheet selected cell should have a visible border or highlight.
* Selected layer row should also be visually distinct.
* Keep existing drawing/blank/held styling visible.
* Do not hide `○`, `X`, `●`, or frame names.
* Do not use overly bright or disruptive colors.
* Keep theme-compatible styling.

Recommended approach:

* Add `selectedLayerId` and `selectedFrameIndex` props if not already present.
* Each cell determines if selected:

```dart
final isSelected =
    layer.id == selectedLayerId && frameIndex == selectedFrameIndex;
```

* Apply a clear border or overlay.

Example:

```text
selected cell:
- thicker border
- slightly stronger background overlay
```

Do not depend on exact color tests unless already used. Prefer widget structure, keys, or semantics tests.

---

## Selected Layer Row Highlight

The selected layer row/header should be clear.

Requirements:

* Horizontal timeline layer header/row for active layer should be visually distinct.
* X-sheet layer row/column equivalent should be visually distinct if applicable.
* Keep existing layer visibility/opacity controls working.
* Do not introduce layer reorder.

Recommended:

* Add subtle background highlight to active layer label area.
* Add semantics label if practical.

Suggested semantics:

```text
selected layer
```

or:

```text
active layer
```

---

## Status Area UI

Update:

```text
lib/src/ui/home_page.dart
```

Add compact current selection/status text near the timeline controls.

Recommended keys:

```dart
ValueKey<String>('current-layer-status')
ValueKey<String>('current-frame-status')
ValueKey<String>('current-cell-status')
```

Suggested UI text:

```text
Layer: Sample Layer 1
Frame: 1
Cell: Blank start (X)
```

Important:

* Frame displayed to user should be 1-based.
* Internal frame index remains 0-based.
* If no active layer:

```text
Layer: None
Frame: 1
Cell: No layer
```

But normally the app should have active layers.

---

## Button Enable / Disable Consistency

Review current toolbar buttons and make sure enabled state matches the current cell state.

Do not change core behavior unless it is clearly inconsistent.

Expected behavior after Phase 16:

```text
New Frame:
- enabled when active layer exists and current frame index is non-negative.

Blank / X:
- enabled when active layer exists and current frame index is non-negative.

Mark ●:
- enabled when active layer exists and current frame index is non-negative.

Rename Frame:
- enabled when current cell resolves to a drawing frame.
- This means drawingStart and held drawing are allowed.

Delete Cell:
- enabled only on drawingStart.
- disabled on X, blankHeld, held drawing, empty, mark-only.
```

If current code already follows this, preserve it and add tests.

If not, adjust only the enable/disable logic to match this policy.

Do not alter the underlying controller behavior beyond what is necessary for consistency.

---

## Semantics / Testability

Add semantics or stable keys where useful.

Recommended:

```dart
ValueKey<String>('timeline-selected-cell')
```

This may be hard if cells already use per-cell keys. Alternative:

* Keep existing cell keys.
* Add semantics label to selected cell:

```text
selected timeline cell
```

* Add semantics label to selected active layer header:

```text
selected layer
```

Avoid brittle color tests.

Tests should prefer:

* keys
* semantics
* text labels
* controller state
* existing per-cell keys

---

## Controller Changes

Minimal controller changes only.

Update:

```text
lib/src/controllers/timeline_controller.dart
```

only if necessary.

Possible additions:

```dart
String cellStatusLabelForLayer({
  required Layer layer,
  required int frameIndex,
});
```

However, because this is UI-facing English text, it may be better to keep labels in `HomePage`.

Recommended:

* Do not add localization/user-facing text to models.
* Avoid adding app UI strings to core controller unless existing pattern already does that.
* Use existing controller methods:

    * `isDrawingStartForLayer`
    * `isHeldExposureForLayer`
    * `isBlankStartForLayer`
    * `isBlankHeldForLayer`
    * `hasMarkAt`
    * `resolveFrameForLayer`

This phase should not change timeline data behavior.

---

## UI Display Rules

Timeline cell symbol display must remain unchanged from previous phases:

```text
If cell has ● mark:
  display ●
Else if drawingStart frame has name:
  display name
Else if drawingStart:
  display ○
Else if blankStart:
  display X
Else:
  display empty text
```

Do not change this priority.

The new selection highlight must wrap around this display, not replace it.

---

## Tests

Add/update tests.

### UI grid tests

Update:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
test/ui/timeline_panel_test.dart
```

Required tests:

1. Horizontal timeline marks selected cell.
2. X-sheet timeline marks selected cell.
3. Selected cell still displays `○`.
4. Selected cell still displays `X`.
5. Selected cell still displays `●`.
6. Selected named drawing cell still displays the name.
7. Selected layer row/header is distinguishable.
8. Non-selected cells are not marked as selected.
9. Existing timeline cell display priority remains unchanged.

Prefer semantics/key assertions over color assertions.

---

### Widget tests

Update:

```text
test/widget_test.dart
```

Required tests:

1. Current layer status text is visible.
2. Current frame status text is visible.
3. Current cell status text is visible.
4. Initial app state shows:

    * Layer: Sample Layer 1 or current default layer
    * Frame: 1
    * Cell: Blank start (X)
5. After New Frame on X:

    * Cell status changes to Drawing start
6. After Rename Frame to `A1`:

    * Cell status shows `Drawing start: A1`
7. After Mark ●:

    * Cell status includes `Mark ●`
8. After selecting held drawing:

    * Cell status shows `Held drawing`
9. After selecting blankHeld:

    * Cell status shows `Blank held`
10. Delete Cell button disabled on X.
11. Delete Cell button enabled on drawingStart.
12. Delete Cell button disabled on held drawing.
13. Rename Frame button enabled on held drawing.
14. Existing New Frame / Blank X / Mark / Rename / Delete / Exposure buttons still work.

Use `ensureVisible + pumpAndSettle` before tapping toolbar buttons if they are in a horizontal scroll view.

---

### Controller tests

Controller tests are optional for this phase unless controller behavior changes.

If button enable logic or cell status logic moves into `TimelineController`, add focused controller tests.

Otherwise, prefer widget/UI tests.

---

## Backward Compatibility

No model or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing save/load tests still pass.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/controllers lib/src/ui test/controllers test/ui test/widget_test.dart lib/main.dart
flutter analyze
flutter test
```

All must pass.

If any fail, fix the code until all pass.

Do not run broad `dart format lib test` unless necessary.

---

## Expected Final Report

At the end of the task, report:

1. Files created
2. Files modified
3. Whether `dart format` passed
4. Whether `flutter analyze` passed
5. Whether `flutter test` passed
6. Any important implementation notes
7. Any behavior notes about selected cell/status display

---

## Completion Criteria

This task is complete only when:

* Current selected cell is visibly highlighted in horizontal timeline.
* Current selected cell is visibly highlighted in X-sheet timeline.
* Current selected layer row/header is visually distinct.
* Current selected layer name is shown in status area.
* Current frame number is shown as 1-based in status area.
* Current cell status is shown in status area.
* Cell status distinguishes drawingStart, named drawingStart, held drawing, blankStart, blankHeld, empty, and mark.
* Existing `○` display remains.
* Existing frame name display remains.
* Existing `X` display remains.
* Existing `●` display remains.
* Existing selected cell display does not hide symbols or frame names.
* New Frame behavior remains.
* Blank / X behavior remains.
* Mark ● behavior remains.
* Rename Frame behavior remains.
* Delete Cell behavior remains.
* * / - Exposure behavior remains.
* Undo/Redo remains.
* No model/JSON migration is introduced.
* No playback is introduced.
* No layer types are introduced.
* No camera/audio/storyboard layers are introduced.
* No double-click behavior is introduced.
* No long-press behavior is introduced.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 18.

Do not implement layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Timeline Selection UX MVP.
