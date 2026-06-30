# Phase 18 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 18: Cell Action UX Refinement MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 17 and related follow-up fixes are already complete.

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
* Named drawing frame heads
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
* Selected timeline cell highlight
* Selected layer highlight
* Status area showing current layer, 1-based frame, and current cell status
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
docs/Phase_17_Codex_Task.md
```

This task implements only Phase 18.

---

## Scope

Implement only:

```text
Phase 18: Cell Action UX Refinement MVP
```

The goal is to make the existing cell action toolbar easier to understand and safer to use.

This phase should implement:

1. A compact “Cell Actions” toolbar grouping.
2. Clear action labels for the current selected cell.
3. Small helper/hint text explaining what the primary cell action will do.
4. More consistent enabled/disabled button semantics.
5. Stable keys and tests for the action area.
6. Preserve all existing model/controller behavior unless a button enable state is inconsistent with existing behavior.

This phase is a UX refinement phase.

Do not add large new editing features.

---

## Important Existing Cell Meanings

The symbols mean:

```text
○ = unnamed drawing frame head
name = named drawing frame head
X = blank/null exposure head
● = timeline mark / inbetween mark / timesheet mark
```

Existing display priority must remain unchanged:

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

Do not implement mark overlay behavior in this phase.

---

## Existing Behavior That Must Remain

Current behavior must remain:

```text
New Frame:
- Enabled when an active layer exists and current frame index is non-negative.
- Creates a drawing frame.
- On X, replaces X with ○.

Blank / X:
- Enabled when an active layer exists and current frame index is non-negative.
- Creates or replaces with a blank/null exposure where controller permits it.
- Must not corrupt existing drawing frames.

Mark ●:
- Enabled when an active layer exists and current frame index is non-negative.
- Toggles a mark at the current cell.
- Removes mark if mark already exists.

Rename Frame:
- Enabled when current cell resolves to a drawing frame.
- This means drawingStart and held drawing are allowed.
- Opens Rename Frame dialog.
- Empty/whitespace input clears frame name.

Delete Cell:
- Enabled only on drawingStart.
- Deletes only drawingStart cells.
- Does not delete X.
- Does not delete mark-only cells.
- If drawingStart has ●, deletes drawing frame and same-index mark together.

+ Exposure:
- Existing exposure increase behavior must remain.

- Exposure:
- Existing exposure decrease behavior must remain.

Undo/Redo:
- Existing Undo/Redo behavior must remain.
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

Do not implement Phase 19 or later.

This phase must stay focused on cell action UX refinement.

---

## Design Direction

Currently many buttons exist in the top toolbar:

```text
New Frame
Blank / X
Mark ●
Rename Frame
Delete Cell
- Exposure
+ Exposure
Undo
Redo
```

This phase should group the cell-related actions visually and add a short hint so users understand what the selected action means.

Recommended grouping:

```text
Cell Actions:
[New Frame] [Blank / X] [Mark ●] [Rename Frame] [Delete Cell] [- Exposure] [+ Exposure]
Hint: <current selected cell action hint>
```

Undo/Redo may remain outside this group if it is already elsewhere.

Keep the UI simple. Do not create menus yet.

---

## New Cell Action Area

Update:

```text
lib/src/ui/home_page.dart
```

Add a compact cell action section near the current timeline toolbar.

Recommended section title:

```text
Cell Actions
```

Recommended key:

```dart
ValueKey<String>('cell-actions-section')
```

Recommended hint key:

```dart
ValueKey<String>('cell-action-hint')
```

Recommended hint examples:

```text
Blank start (X): New Frame will replace X with a drawing.
Drawing start: Delete Cell will delete this drawing frame.
Drawing start + Mark ●: Delete Cell will delete this drawing and its mark.
Held drawing: Rename Frame can rename the held drawing.
Blank held: New Frame can create a drawing here.
Empty: New Frame can create a drawing here.
Empty + Mark ●: Mark ● will remove the mark.
```

The hint text does not need to be perfect. It just needs to match the current cell and existing button behavior.

---

## Cell Action Hint Rules

Add a simple UI-facing helper.

Preferred location:

```text
HomePage
```

Do not add user-facing English strings to model classes.

Suggested helper:

```dart
String get _cellActionHintText;
```

Rules:

If no active layer:

```text
No active layer.
```

If current cell is drawingStart without mark:

```text
Drawing start: Delete Cell will delete this drawing frame.
```

If current cell is drawingStart with mark:

```text
Drawing start + Mark ●: Delete Cell will delete this drawing and its mark.
```

If current cell is held drawing without mark:

```text
Held drawing: Rename Frame can rename the held drawing.
```

If current cell is held drawing with mark:

```text
Held drawing + Mark ●: Mark ● will remove the mark.
```

If current cell is blankStart without mark:

```text
Blank start (X): New Frame will replace X with a drawing.
```

If current cell is blankStart with mark:

```text
Blank start (X) + Mark ●: New Frame will replace X; Mark ● will remove the mark.
```

If current cell is blankHeld without mark:

```text
Blank held: New Frame can create a drawing here.
```

If current cell is blankHeld with mark:

```text
Blank held + Mark ●: New Frame can create a drawing here; Mark ● will remove the mark.
```

If current cell is empty without mark:

```text
Empty: New Frame can create a drawing here.
```

If current cell is empty with mark:

```text
Empty + Mark ●: Mark ● will remove the mark.
```

Keep hints short enough to fit in the toolbar area.

If exact wording differs slightly, tests should use key text presence or important substrings, not brittle full strings.

---

## Button Labels

Keep the existing button labels unless a small wording change makes the action clearer.

Required existing labels:

```text
New Frame
Blank / X
Mark ●
Rename Frame
Delete Cell
```

Do not rename `New Frame` back to `New Drawing`.

Do not introduce new action buttons except optional static section title/hint.

Do not add a separate `Delete Mark` button in this phase.

---

## Button Enable / Disable Policy

Ensure UI enablement matches the behavior.

Expected:

```text
New Frame:
- Enabled when active layer exists and current frame index >= 0.

Blank / X:
- Enabled when active layer exists and current frame index >= 0.
- Handler should still call controller guard and no-op if controller rejects.

Mark ●:
- Enabled when active layer exists and current frame index >= 0.

Rename Frame:
- Enabled when current selected cell resolves to a drawing frame.
- This includes held drawing.

Delete Cell:
- Enabled only on drawingStart.
- Disabled on X.
- Disabled on blankHeld.
- Disabled on held drawing.
- Disabled on empty.
- Disabled on mark-only cell.
```

Do not broaden Delete Cell behavior.

---

## Status Area Relationship

Phase 17 added:

```text
Layer: ...
Frame: ...
Cell: ...
```

Keep this status area.

Phase 18 should add action hinting without removing Phase 17 status.

Recommended layout:

```text
Layer: Sample Layer 1   Frame: 1   Cell: Blank start (X)
Cell Actions: [New Frame] [Blank / X] [Mark ●] [Rename Frame] [Delete Cell] [- Exposure] [+ Exposure]
Hint: Blank start (X): New Frame will replace X with a drawing.
```

Exact layout can differ if compact and readable.

---

## Timeline UI

Do not change:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

unless needed for tests or minor styling.

This phase is primarily in `HomePage`.

Do not change timeline cell marker priority.

Do not change selected cell highlight behavior from Phase 17.

---

## Controller Changes

Avoid controller changes.

Update:

```text
lib/src/controllers/timeline_controller.dart
```

only if a UI enable rule cannot be implemented with existing methods.

This phase should not change model behavior, timeline behavior, or JSON.

---

## Tests

Add/update tests.

### Widget tests

Update:

```text
test/widget_test.dart
```

Required tests:

1. Cell Actions section is visible.
2. Cell Actions section has key `cell-actions-section`.
3. Cell action hint is visible.
4. Cell action hint has key `cell-action-hint`.
5. Initial X state hint mentions New Frame replacing X.
6. After New Frame on X, hint mentions Delete Cell will delete drawing frame.
7. After Mark ● on drawingStart, hint mentions drawing and mark.
8. Held drawing hint mentions Rename Frame or held drawing.
9. Empty cell hint mentions New Frame can create a drawing.
10. Mark-only empty cell hint mentions Mark ● will remove the mark.
11. Delete Cell is disabled on X.
12. Delete Cell is enabled on drawingStart.
13. Delete Cell is disabled on held drawing.
14. Rename Frame is enabled on held drawing.
15. Existing Phase 17 status texts remain visible.
16. Existing New Frame / Blank X / Mark / Rename / Delete / Exposure buttons still work.

Use `ensureVisible + pumpAndSettle` before tapping toolbar buttons if they are in a horizontal scroll view.

Prefer substring checks for hints, for example:

```dart
expect(find.textContaining('New Frame'), findsWidgets);
expect(find.textContaining('replace X'), findsWidgets);
```

Do not make tests brittle on exact full hint strings unless necessary.

---

### UI tests

Update:

```text
test/ui/timeline_panel_test.dart
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
```

only if needed.

If no timeline widgets change, avoid unnecessary test churn.

---

### Controller tests

Controller tests should not be required.

Do not add controller tests unless controller behavior changes.

---

## Backward Compatibility

No model or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17 selection/status tests still pass.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/ui test/ui test/widget_test.dart lib/main.dart
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
7. Any behavior notes about the Cell Actions section and hint text

---

## Completion Criteria

This task is complete only when:

* Cell Actions section exists.
* Cell Actions section has stable key `cell-actions-section`.
* Cell action hint exists.
* Cell action hint has stable key `cell-action-hint`.
* Hint text changes based on selected cell.
* Initial X state explains New Frame can replace X.
* DrawingStart state explains Delete Cell deletes drawing frame.
* DrawingStart + Mark ● state explains Delete Cell deletes drawing and mark.
* Held drawing state explains Rename Frame can rename the held drawing.
* Empty state explains New Frame can create a drawing.
* Empty + Mark ● state explains Mark ● can remove the mark.
* Existing Layer / Frame / Cell status area remains.
* Existing selected cell highlight remains.
* Existing selected layer highlight remains.
* Existing `○` display remains.
* Existing frame name display remains.
* Existing `X` display remains.
* Existing `●` display priority remains.
* Existing New Frame behavior remains.
* Existing Blank / X behavior remains.
* Existing Mark ● behavior remains.
* Existing Rename Frame behavior remains.
* Existing Delete Cell behavior remains.
* Existing + / - Exposure behavior remains.
* Undo/Redo remains.
* No model/JSON migration is introduced.
* No playback is introduced.
* No layer types are introduced.
* No camera/audio/storyboard layers are introduced.
* No double-click behavior is introduced.
* No long-press behavior is introduced.
* No right-click menu is introduced.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 19.

Do not implement layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Cell Action UX Refinement MVP.
