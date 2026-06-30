# Phase 20 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 20: Timeline Toolbar Relocation MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 19 and related follow-up fixes are already complete.

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
* Cell Actions section
* Cell action hint
* Linked Frame Copy/Paste MVP
* `Copy Frame` button
* `Paste Linked Frame` button
* Linked use count display
* In-memory copied frame reference
* Same-layer linked paste using the same `FrameId`
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
```

This task implements only Phase 20.

---

## Scope

Implement only:

```text
Phase 20: Timeline Toolbar Relocation MVP
```

The goal is to move timeline/cell editing controls out of the general HomePage top status area and into the TimelinePanel area.

This is a UI structure cleanup phase.

This phase should implement:

1. Move the Cell Actions controls from `HomePage` top row into `TimelinePanel`.
2. Keep all existing buttons and keys.
3. Keep all existing behavior.
4. Keep current text labels for now.
5. Keep current hint/status text for now, but place it closer to the timeline controls.
6. Preserve existing tests or update them to use the new widget location.
7. Do not iconize buttons yet.
8. Do not remove hints or linked use count yet.

This phase should not add new editing features.

---

## Important UI Direction

The current UI has too many timeline/cell action controls in the HomePage status row.

The long-term desired direction is:

```text
HomePage top/global area:
- App/project/canvas/global information
- Undo/Redo may remain here for now if moving it would be too much

TimelinePanel:
- Timeline orientation controls
- Current timeline/cell status
- Cell Actions
- New Frame
- Blank / X
- Mark ●
- Copy Frame
- Paste Linked Frame
- Rename Frame
- Delete Cell
- - Exposure
- + Exposure
- Cell action hint
- Linked uses / copied frame status, for now
```

For Phase 20, do not redesign the whole app. Just move the existing Cell Actions and related timeline status closer to the timeline.

---

## Existing Symbol Meaning

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

Current behavior must remain exactly the same:

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

- Exposure:
- Existing exposure decrease behavior must remain.

Undo/Redo:
- Existing Undo/Redo behavior must remain.
```

---

## Very Important Restrictions

Do not implement any of the following:

* Icon-only toolbar
* Tooltip-only action UI
* Removing hint text
* Hiding linked use count
* Hiding copied frame status
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

Do not implement Phase 21 or later.

This phase must stay focused on relocating the timeline/cell toolbar.

---

## Design Direction

Current rough layout:

```text
HomePage top row:
Layer / Frame / Cell / Duration / Linked uses / Copied / Cell Actions / Hint / Undo / Redo

TimelinePanel:
Horizontal timeline or X-sheet grid
```

Desired Phase 20 layout:

```text
HomePage top/global row:
Project/canvas/global status
Undo / Redo may remain here for now

TimelinePanel:
Timeline toolbar/status row:
Layer / Frame / Cell / Duration / Linked uses / Copied
Cell Actions: [New Frame] [Blank / X] [Mark ●] [Copy Frame] [Paste Linked Frame] [Rename Frame] [Delete Cell] [- Exposure] [+ Exposure]
Hint: ...
Timeline grid / X-sheet grid
```

Exact visual layout may differ if simpler.

Important:

* Timeline/cell action buttons should live in or near `TimelinePanel`.
* The feature logic may still be owned by `HomePage` for MVP if moving all state is too big.
* Prefer passing callbacks and status strings into `TimelinePanel` rather than moving controllers deeply.
* Keep the change mechanical and low-risk.

---

## Recommended Implementation Approach

### Preferred approach

Update:

```text
lib/src/ui/timeline/timeline_panel.dart
```

Add optional toolbar/action parameters to `TimelinePanel`.

For example:

```dart
final Widget? timelineToolbar;
```

or:

```dart
final Widget? header;
final Widget? actionBar;
```

Then in `HomePage`, build the current Cell Actions/status/hint widget and pass it into `TimelinePanel`.

This keeps:

```text
- state in HomePage
- callbacks in HomePage
- UI location in TimelinePanel
```

This is the safest Phase 20 approach.

### Avoid for this phase

Do not move all timeline/cell state into `TimelinePanel`.

Do not create a new state management layer.

Do not rewrite the controller architecture.

---

## HomePage Changes

Update:

```text
lib/src/ui/home_page.dart
```

Refactor the existing timeline/cell status and Cell Actions UI into a helper widget builder.

Suggested helper:

```dart
Widget _buildTimelineActionToolbar(BuildContext context);
```

This helper should include the existing:

```text
Layer: ...
Frame: ...
Cell: ...
Duration: ...
Linked uses: ...
Copied: ...
Cell Actions section
Cell action hint
```

Then pass it into `TimelinePanel`.

Keep existing keys:

```dart
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

Remove these timeline/cell-specific UI items from the global HomePage top row after passing them into TimelinePanel.

Keep global/canvas status that is not timeline-specific in HomePage, for example:

```text
QuickAnimaker v2.1
Canvas size
Active strokes
Undo / Redo
```

Exact split can be practical.

---

## TimelinePanel Changes

Update:

```text
lib/src/ui/timeline/timeline_panel.dart
```

Add a place to render the provided toolbar above the timeline grid and below any timeline panel title/orientation control.

Possible structure:

```text
Timeline
[orientation controls]
[timelineActionToolbar]
[timeline grid]
```

Do not break horizontal timeline or X-sheet rendering.

Do not alter timeline cell display priority.

Do not alter selected cell behavior.

---

## Button UI

Keep text buttons for this phase.

Do not convert buttons to icons yet.

Do not add tooltips yet unless already present.

Future phase candidate:

```text
Icon Timeline Toolbar MVP:
- Convert text buttons to icon buttons.
- Add tooltips.
- Remove long visible action text.
```

Not part of Phase 20.

---

## Hint / Status UI

Keep visible hint and status text for now.

Do not remove:

```text
Cell action hint
Linked uses
Copied status
Layer / Frame / Cell status
```

These will be cleaned up in a future UI cleanup phase.

This phase only moves them to the TimelinePanel area.

---

## Tests

Update tests to reflect location change.

### Widget tests

Update:

```text
test/widget_test.dart
```

Required:

1. Existing New Frame / Blank X / Mark / Copy / Paste / Rename / Delete / Exposure tests still pass.
2. Existing Phase 17 status text tests still pass.
3. Existing Phase 18 Cell Actions section tests still pass.
4. Existing Phase 19 Linked Frame Copy/Paste tests still pass.
5. Cell Actions section is still visible.
6. Cell action hint is still visible.
7. Linked uses status is still visible.
8. Copied frame status is still visible.
9. Buttons still have the same keys.
10. Buttons still work after relocation.
11. No duplicate button widgets with the same key are created.
12. Timeline toolbar appears inside or near TimelinePanel.

If practical, add a key to the new TimelinePanel toolbar area:

```dart
ValueKey<String>('timeline-action-toolbar')
```

Then add a test:

```text
timeline-action-toolbar exists
cell-actions-section is contained in or below timeline-action-toolbar
```

Use robust widget tests; avoid brittle exact layout assertions.

---

### TimelinePanel tests

Update:

```text
test/ui/timeline_panel_test.dart
```

Required if a `timelineActionToolbar` parameter is added:

1. TimelinePanel renders provided toolbar widget.
2. TimelinePanel still renders horizontal timeline.
3. TimelinePanel still renders X-sheet timeline.
4. Orientation controls still work.

---

### UI grid tests

Do not modify these unless necessary:

```text
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
```

No timeline grid behavior should change.

---

### Controller tests

Controller tests should not need changes.

Do not modify controller tests unless necessary.

---

## Backward Compatibility

No model or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing linked frame copy/paste tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17, 18, and 19 widget tests still pass.

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
7. Any behavior notes about toolbar relocation

---

## Completion Criteria

This task is complete only when:

* Timeline/cell actions are no longer primarily displayed in the global HomePage top row.
* Timeline/cell actions are displayed inside or directly near TimelinePanel.
* A stable `timeline-action-toolbar` key exists if practical.
* Existing `cell-actions-section` key remains.
* Existing `cell-action-hint` key remains.
* Existing status keys remain:

    * `current-layer-status`
    * `current-frame-status`
    * `current-cell-status`
    * `linked-frame-uses-status`
    * `copied-frame-status`
* Existing action button keys remain:

    * `new-frame-button`
    * `blank-exposure-button`
    * `toggle-mark-button`
    * `copy-frame-button`
    * `paste-linked-frame-button`
    * `rename-frame-button`
    * `delete-cell-button`
    * `decrease-exposure-button`
    * `increase-exposure-button`
* Button behavior remains unchanged.
* Copy/Paste Linked Frame behavior remains unchanged.
* Linked use count behavior remains unchanged.
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
* No model/JSON migration is introduced.
* No icon-only toolbar is introduced.
* No tooltip-only UI is introduced.
* Hint text is not removed yet.
* Linked uses is not hidden yet.
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

Do not implement Phase 21.

Do not implement icon-only toolbar, tooltip-only action UI, hint removal, linked uses hiding, duplicate paste, make independent, unlink, rename conflict dialog, automatic name-based linking, cross-layer paste, cross-cut paste, project-level material pool, linked layer, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Timeline Toolbar Relocation MVP.
