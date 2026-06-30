# Phase 22 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 22: Minimal Timeline Status Cleanup MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 21 and related follow-up fixes are already complete.

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
* Status area showing current layer, 1-based frame, and current cell status
* Linked Frame Copy/Paste MVP
* `Copy Frame` action
* `Paste Linked Frame` action
* Linked use count display
* In-memory copied frame reference
* Same-layer linked paste using the same `FrameId`
* Linked frames share drawing material but do not share exposure duration
* Timeline/cell action toolbar relocated into `TimelinePanel`
* Timeline/cell action toolbar icon buttons
* Tooltip labels for timeline/cell action buttons
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
```

This task implements only Phase 22.

---

## Scope

Implement only:

```text
Phase 22: Minimal Timeline Status Cleanup MVP
```

The goal is to reduce visible explanatory text around the TimelinePanel toolbar.

This is a UI cleanup phase.

This phase should implement:

1. Replace the long visible Cell action hint sentence with a short compact hint/status line.
2. Shorten linked use count display.
3. Shorten copied frame display.
4. Keep essential Layer / Frame / Cell status visible.
5. Keep tooltips on action buttons.
6. Keep all existing action behavior.
7. Keep all existing action keys.
8. Update tests to avoid relying on long hint text.

Do not add new editing features.

Do not remove the status area entirely.

---

## Important UI Direction

The long-term UI direction is:

```text
- The app should feel like a professional animation tool.
- The UI should not feel like a tutorial.
- Long visible explanatory text should be minimized.
- Action meaning should come from icons, tooltips, and consistent behavior.
- Essential state should remain visible.
```

Phase 22 should make the TimelinePanel toolbar less visually noisy without removing useful state entirely.

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

* Removing Layer / Frame / Cell status
* Removing action tooltips
* Removing action buttons
* Moving toolbar back to HomePage top row
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
* Rename conflict dialog
* Automatic name-based linking
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

Do not implement Phase 23 or later.

This phase must stay focused on minimal timeline status cleanup.

---

## Current Problem

The current TimelinePanel toolbar still has too much visible explanatory text.

Examples of currently verbose text:

```text
Hint: Drawing start + Mark ●: Copy Frame can copy this material; Delete Cell will delete this drawing and its mark.
Linked uses: 2
Copied: A1
```

This was useful during implementation, but it makes the UI feel too explanatory and visually noisy.

Phase 22 should reduce this.

---

## Required UI Changes

Update:

```text
lib/src/ui/home_page.dart
```

### 1. Replace long hint with compact status

Keep the existing key:

```dart
ValueKey<String>('cell-action-hint')
```

But change the displayed text to a short compact line.

Recommended label:

```text
Action: <short action state>
```

or simply:

```text
<short action state>
```

Suggested compact hint outputs:

```text
X: New Frame
Drawing: Copy / Rename / Delete
Drawing + ●: Copy / Rename / Delete
Held: Copy / Rename
Held + ●: Copy / Rename / Mark
Blank held: New Frame
Empty: New Frame
Empty + ●: Mark
X + ●: New Frame / Mark
```

If a copied frame is available and paste is enabled, include paste compactly:

```text
X: Paste / New Frame
Held: Paste / Copy / Rename
Blank held: Paste / New Frame
Empty: Paste / New Frame
Empty + ●: Paste / Mark
```

Important:

* Do not use long explanatory sentences.
* Do not explain full consequences in visible UI.
* Tooltips and behavior should carry action meaning.
* Keep the hint short enough to feel like a status label.

The helper may be renamed internally, but keep the external key.

Recommended helper name:

```dart
String get _compactCellActionText;
```

Current `_cellActionHintText` can be replaced or simplified.

---

### 2. Shorten linked use count

Keep the existing key:

```dart
ValueKey<String>('linked-frame-uses-status')
```

Change display from:

```text
Linked uses: 2
```

to a shorter form:

```text
Links: 2
```

If no drawing frame is selected:

```text
Links: -
```

Do not remove it yet.

Do not add link icon in this phase unless extremely simple.

---

### 3. Shorten copied frame status

Keep the existing key:

```dart
ValueKey<String>('copied-frame-status')
```

Change display from:

```text
Copied: A1
```

to a shorter form:

```text
Copy: A1
```

If nothing is copied:

```text
Copy: -
```

Do not remove it yet.

---

### 4. Keep essential selected state

Keep visible:

```text
Layer: ...
Frame: ...
Cell: ...
Duration: ...
Links: ...
Copy: ...
```

Do not remove these yet.

Future phases may compress them further.

---

## Required Keys to Preserve

The following keys must remain available:

```dart
ValueKey<String>('timeline-action-toolbar')
ValueKey<String>('current-layer-status')
ValueKey<String>('current-frame-status')
ValueKey<String>('current-cell-status')
ValueKey<String>('linked-frame-uses-status')
ValueKey<String>('copied-frame-status')
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

Do not rename keys.

---

## Required Tooltip Labels to Preserve

The action button tooltips must remain:

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

Do not remove tooltips.

---

## Button Enable / Disable Policy

The enabled/disabled behavior must remain:

```text
New Frame:
- enabled when active layer exists and current frame index >= 0

Blank / X:
- enabled when active layer exists and current frame index >= 0

Mark ●:
- enabled when active layer exists and current frame index >= 0

Copy Frame:
- enabled when current selected cell resolves to a drawing frame

Paste Linked Frame:
- enabled when copied frame exists, copied frame is in current layer, copied FrameId still exists, current frame index >= 0

Rename Frame:
- enabled when current selected cell resolves to a drawing frame

Delete Cell:
- enabled only on drawingStart

- Exposure:
- enabled according to existing canDecreaseExposure

+ Exposure:
- enabled according to existing canIncreaseExposure
```

Do not change the predicates.

---

## Tests

Update tests.

### Widget tests

Update:

```text
test/widget_test.dart
```

Required:

1. Existing behavior tests still pass.
2. Existing button keys still exist.
3. Existing action tooltips still exist.
4. `cell-action-hint` still exists.
5. `cell-action-hint` no longer expects long explanatory sentences.
6. Compact hint/state text updates by cell state.
7. Initial X state should show a compact New Frame action.
8. Drawing state should show compact Copy / Rename / Delete actions.
9. Held drawing state should show compact Copy / Rename actions.
10. Empty state should show compact New Frame action.
11. Empty + Mark state should show compact Mark action.
12. If copied frame exists and paste is available, compact hint should include Paste.
13. Linked uses text should be `Links: N` instead of `Linked uses: N`.
14. No selected drawing should show `Links: -`.
15. Copied frame text should be `Copy: <name>` or `Copy: -`.
16. Existing linked frame copy/paste tests still pass.
17. Existing linked exposure duration regression tests still pass.
18. Existing Phase 20/21 toolbar tests still pass.

Avoid checking long exact full hint strings.

Prefer substring checks:

```dart
expect(_compactActionText(tester), contains('New Frame'));
expect(_compactActionText(tester), contains('Paste'));
expect(_compactActionText(tester), isNot(contains('will delete')));
```

---

### Controller tests

Controller tests should not need changes.

Do not modify controller tests unless necessary.

---

### UI grid tests

Do not modify these unless necessary:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
test/ui/timeline_panel_test.dart
```

No timeline grid behavior should change.

---

## Backward Compatibility

No model, controller, or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing linked frame copy/paste tests still pass.
* Existing linked exposure duration regression tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17, 18, 19, 20, and 21 widget tests still pass after expectation updates.

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
7. Any behavior notes about compact status cleanup

---

## Completion Criteria

This task is complete only when:

* Long visible cell action hint sentences are removed or replaced with compact action text.
* `cell-action-hint` key remains.
* Linked use count is shortened to `Links: N`.
* No drawing selection shows `Links: -`.
* Copied frame status is shortened to `Copy: <name>` or `Copy: -`.
* Essential Layer / Frame / Cell / Duration status remains visible.
* Action tooltips remain.
* Timeline toolbar remains in TimelinePanel.
* Existing button keys remain unchanged.
* Existing action behavior remains unchanged.
* Existing button enable/disable behavior remains unchanged.
* Existing Copy/Paste Linked Frame behavior remains unchanged.
* Existing linked exposure duration bugfix behavior remains unchanged.
* Existing `○` display remains.
* Existing frame name display remains.
* Existing `X` display remains.
* Existing `●` display priority remains.
* Existing selected cell highlight remains.
* Existing selected layer highlight remains.
* Existing New Frame behavior remains.
* Existing Blank / X behavior remains.
* Existing Mark ● behavior remains.
* Existing Rename Frame behavior remains.
* Existing Delete Cell behavior remains.
* Existing + / - Exposure behavior remains.
* Undo/Redo remains.
* No model/controller/JSON migration is introduced.
* No duplicate paste is introduced.
* No cross-layer paste is introduced.
* No cross-cut paste is introduced.
* No project-level material pool is introduced.
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

Do not implement Phase 23.

Do not remove essential selected state, remove action tooltips, implement duplicate paste, make independent, unlink, rename conflict dialog, automatic name-based linking, cross-layer paste, cross-cut paste, project-level material pool, linked layer, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Minimal Timeline Status Cleanup MVP.
