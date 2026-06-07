# Phase 24 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 24: Timeline Toolbar Polish & Drawing Block Color Cleanup MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 23 and related follow-up fixes are already complete.

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
* `New Frame` action
* `Blank / X` action
* `Mark ●` action
* `Rename Frame` dialog
* `Delete Cell` action
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
* Linked Frame Copy/Paste MVP
* `Copy Frame` action
* `Paste Linked Frame` action
* Linked use count display
* In-memory copied frame reference
* Same-layer linked paste using the same `FrameId`
* Linked frames share drawing material but do not share exposure duration
* Frame name conflict policy:

    * Same frame name means same material
    * Rename conflict shows Link / Cancel
    * Link merges timeline references into the existing material
* Timeline/cell action toolbar relocated into `TimelinePanel`
* Timeline/cell action toolbar icon buttons
* Tooltip labels for timeline/cell action buttons
* Compact timeline status text
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
docs/Phase_18_Codex_Task.md
docs/Phase_19_Codex_Task.md
docs/Phase_20_Codex_Task.md
docs/Phase_21_Codex_Task.md
docs/Phase_22_Codex_Task.md
docs/Phase_23_Codex_Task.md
```

This task implements only Phase 24.

---

## Scope

Implement only:

```text
Phase 24: Timeline Toolbar Polish & Drawing Block Color Cleanup MVP
```

This is a UI polish phase.

The goal is to improve TimelinePanel readability and reduce visual noise without changing timeline behavior.

This phase should implement:

1. Add light grouping/polish to the TimelinePanel action toolbar.
2. Add spacing or subtle dividers between logical action groups.
3. Keep all toolbar actions, keys, tooltips, and behavior unchanged.
4. Change active drawing exposure block styling so drawing blocks are no longer reddish/pink.
5. Use white or near-white styling for drawing exposure blocks.
6. Keep blank/X regions gray.
7. Keep drawing head/start cells distinguishable with subtle gray/border treatment.
8. Keep selected cell highlight visible.
9. Keep symbol display behavior unchanged.
10. Update tests for non-behavioral UI style where practical.

Do not add new editing features.

Do not change controller/model/JSON behavior.

---

## Important UI Direction

The long-term UI direction is:

```text
- The timeline should look like a practical production tool.
- Drawing exposure regions should not feel color-coded in a distracting way.
- Normal drawing blocks should be visually calm, preferably white or near-white.
- Blank/X regions can remain gray.
- Drawing heads can have a subtle distinction from held drawing cells.
- Toolbar actions should be visually grouped so icon-only buttons are easier to scan.
```

This phase should keep the UI simple.

Avoid over-designing.

---

## Existing Symbol Meaning

The timeline symbols mean:

```text
○ = unnamed drawing frame head
name = named drawing frame head
X = blank/null exposure head
● = timeline mark / inbetween mark / timesheet mark
```

Existing cell display priority must remain unchanged:

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

All current behavior must remain exactly the same:

```text
New Frame:
- Enabled when an active layer exists and current frame index is non-negative.
- Creates a new drawing frame.
- On X, replaces X with ○.

Blank / X:
- Enabled when an active layer exists and current frame index is non-negative.
- Creates or replaces with a blank/null exposure where controller permits it.

Mark ●:
- Enabled when an active layer exists and current frame index is non-negative.
- Toggles a mark at the current cell.
- Removes mark if mark already exists.

Copy Frame:
- Enabled when current selected cell resolves to a drawing frame.
- Stores the resolved FrameId in memory.
- Does not modify project data.
- Does not create Undo/Redo entry.

Paste Linked Frame:
- Enabled only when a copied frame exists, target layer is the copied layer,
  copied FrameId still exists, and current frame index is non-negative.
- Uses the copied FrameId.
- Does not create a new Frame.
- Does not create a new FrameId.
- Does not clone strokes.
- Preserves current cell mark.
- Is Undo/Redo-able.

Rename Frame:
- Enabled when current cell resolves to a drawing frame.
- This means drawingStart and held drawing are allowed.
- Empty/whitespace input clears frame name.
- If target name already exists on another FrameId in the same layer:
  - show Link / Cancel dialog.
  - Link merges references into existing material.
  - Cancel makes no change.

Delete Cell:
- Enabled only on drawingStart.
- Deletes only drawingStart cells.
- Does not delete X.
- Does not delete mark-only cells.
- If drawingStart has ●, deletes drawing frame and same-index mark together.

+ Exposure:
- Existing exposure increase behavior must remain.
- Linked frames must not share authored exposure duration.

- Exposure:
- Existing exposure decrease behavior must remain.
- Linked frames must not share authored exposure duration.

Undo/Redo:
- Existing Undo/Redo behavior must remain.
```

---

## Very Important Restrictions

Do not implement any of the following:

* New timeline editing behavior
* New toolbar actions
* Removing toolbar actions
* Removing button keys
* Removing tooltips
* Moving toolbar back to HomePage top row
* Changing symbol display priority
* Mark overlay behavior
* Duplicate Frame Paste
* Clone Frame Paste
* Stroke duplication
* New FrameId creation on paste
* System clipboard integration
* Keyboard shortcuts
* Multi-frame copy
* Exposure range copy
* Timeline range paste
* Cross-layer paste
* Cross-cut paste
* Project-level material pool
* Link/Unlink UI
* Make Independent
* Rename-only option for name conflict
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
* Frame block dragging
* Exposure handle dragging
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

Do not implement Phase 25 or later.

This phase must stay focused on TimelinePanel UI polish and drawing block color cleanup.

---

## Part A: Timeline Toolbar Polish

Update:

```text
lib/src/ui/home_page.dart
```

The current TimelinePanel toolbar action section contains compact icon buttons. They work, but they are visually dense.

Add minimal visual grouping.

Recommended action groups:

```text
Group 1: Create / mark
- New Frame
- Blank / X
- Mark ●

Group 2: Copy / paste
- Copy Frame
- Paste Linked Frame

Group 3: Edit
- Rename Frame
- Delete Cell

Group 4: Exposure
- Decrease Exposure
- Increase Exposure
```

Recommended UI treatment:

```text
- Keep all buttons in the existing Cell Actions section.
- Add small horizontal spacing between groups.
- Optionally add subtle vertical dividers between groups.
- Do not add long group labels.
- Do not make the toolbar taller than necessary.
```

Acceptable implementation:

```dart
const SizedBox(width: 8)
VerticalDivider(...)
```

or a small helper:

```dart
Widget _toolbarGroupDivider()
```

Do not introduce a new large widget architecture.

Do not change callback wiring.

Do not change enabled/disabled predicates.

---

## Toolbar Keys and Tooltips Must Remain

Keep all existing keys:

```dart
ValueKey<String>('timeline-action-toolbar')
ValueKey<String>('cell-actions-section')
ValueKey<String>('cell-action-hint')
ValueKey<String>('new-frame-button')
ValueKey<String>('blank-exposure-button')
ValueKey<String>('toggle-mark-button')
ValueKey<String>('copy-frame-button')
ValueKey<String>('paste-linked-frame-button')
ValueKey<String>('rename-frame-button')
ValueKey<String>('delete-cell-button')
ValueKey<String>('decrease-exposure-button')
ValueKey<String>('increase-exposure-button')
```

Keep action tooltips:

```text
New Frame
Blank / X
Mark ●
Copy Frame
Paste Linked Frame
Rename Frame
Delete Cell
Decrease Exposure
Increase Exposure
```

Optional new keys if useful:

```dart
ValueKey<String>('timeline-toolbar-create-group')
ValueKey<String>('timeline-toolbar-copy-group')
ValueKey<String>('timeline-toolbar-edit-group')
ValueKey<String>('timeline-toolbar-exposure-group')
```

These are optional but useful for tests.

---

## Part B: Drawing Block Color Cleanup

Update timeline grid rendering files.

Likely files:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

Current issue:

```text
Active drawing exposure blocks appear slightly red/pink.
The user wants active drawing blocks to be white instead.
```

Required color/style change:

```text
Drawing exposure held/body cells:
- should be white or near-white.
- should not be reddish/pink.

Drawing start/head cells:
- can be subtly different from held drawing cells.
- use a very light gray, subtle border, or slight emphasis.
- should not be reddish/pink.

Blank/X start cells:
- remain gray/muted.

Blank held cells:
- remain gray/muted and low-emphasis.

Empty cells:
- keep existing neutral styling.

Selected cells:
- selected highlight must remain visible.
- selected highlight may override normal background.

Marked cells:
- ● display priority remains unchanged.
- This phase does not add mark overlay behavior.
```

Suggested palette:

```dart
const drawingHeldColor = Colors.white;
const drawingStartColor = Color(0xFFF7F7F7);
const blankStartColor = Color(0xFFE0E0E0);
const blankHeldColor = Color(0xFFF0F0F0);
```

Exact values may differ, but do not use red/pink hues for drawing cells.

Prefer simple named helpers instead of scattering raw colors.

Recommended:

```dart
Color _backgroundColorForCell(...)
```

or update existing helper if it exists.

---

## Horizontal and X-sheet Consistency

The style change must apply to both:

```text
Horizontal timeline grid
Vertical X-sheet timeline grid
```

Keep them visually consistent.

If both files currently duplicate styling, update both.

Do not change layout dimensions unless necessary.

Do not change key names for cells.

---

## Tests

Update tests as needed.

### Widget tests

Update:

```text
test/widget_test.dart
```

Required:

1. Existing behavior tests still pass.
2. Existing action keys still exist.
3. Existing action tooltips still exist.
4. Existing compact status text remains.
5. Toolbar grouping exists if group keys are added.
6. New Frame / Blank X / Mark / Copy / Paste / Rename / Delete / Exposure still work.
7. Rename conflict Link / Cancel behavior still works.
8. Linked exposure duration hotfix still works.

Do not rely on exact color values in broad widget tests unless existing tests already do.

---

### Timeline UI tests

Update:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
```

Add or update style-focused tests where practical.

Required style coverage if feasible:

1. Drawing held cell no longer uses a red/pink background.
2. Drawing start/head cell no longer uses a red/pink background.
3. Blank start/held cells remain gray/muted.
4. Selected cell highlight remains visible.
5. `○`, `X`, `●`, and frame name display still work.
6. Horizontal and X-sheet grids are consistent.

Because Flutter style assertions can be brittle, prefer testing named constants/helper outputs if accessible. If not accessible, use minimal robust widget checks and rely on manual verification.

Do not overfit tests to exact color constants unless the project already tests exact colors.

---

### Controller tests

Controller tests should not need changes.

Do not modify controller tests unless necessary.

---

## Backward Compatibility

No model, controller, service, or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing linked frame copy/paste tests still pass.
* Existing linked exposure duration regression tests still pass.
* Existing frame name link policy tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17 through Phase 23 widget tests still pass after any minor expectation updates.

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
7. Any behavior notes about toolbar grouping and drawing block colors

---

## Completion Criteria

This task is complete only when:

* Timeline toolbar has clearer visual grouping.
* Toolbar actions still live in TimelinePanel.
* Existing action buttons remain.
* Existing action button keys remain.
* Existing action tooltips remain.
* Existing action behavior remains unchanged.
* Drawing exposure held/body cells are white or near-white.
* Drawing exposure cells are no longer red/pink.
* Drawing start/head cells remain subtly distinguishable.
* Blank/X regions remain gray/muted.
* Selected cell highlight remains visible.
* Horizontal timeline grid style is updated.
* X-sheet timeline grid style is updated.
* Existing `○` display remains.
* Existing frame name display remains.
* Existing `X` display remains.
* Existing `●` display priority remains.
* Existing selected cell highlight remains.
* Existing selected layer highlight remains.
* Existing New Frame behavior remains.
* Existing Blank / X behavior remains.
* Existing Mark ● behavior remains.
* Existing Copy/Paste Linked Frame behavior remains.
* Existing Rename Frame behavior remains.
* Existing frame name Link / Cancel behavior remains.
* Existing Delete Cell behavior remains.
* Existing + / - Exposure behavior remains.
* Existing linked exposure duration hotfix remains.
* Undo/Redo remains.
* No model/controller/JSON migration is introduced.
* No duplicate paste is introduced.
* No cross-layer paste is introduced.
* No cross-cut paste is introduced.
* No project-level material pool is introduced.
* No Make Independent is introduced.
* No Unlink is introduced.
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

Do not implement Phase 25.

Do not implement new timeline editing behavior, duplicate paste, make independent, unlink, cross-layer linking, cross-cut linking, project-level material pool, linked layer, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Timeline Toolbar Polish & Drawing Block Color Cleanup MVP.
