# Phase 11 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 11: Timeline Exposure UI Refinement MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 10 are already complete.

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
* Sparse timeline MVP
* Integrated timeline/layer UI
* Horizontal timeline grid
* Vertical X-sheet timeline grid
* Frame exposure duration editing
* New Drawing button
* Increase/decrease exposure controls
* Drawing-start / held-exposure / empty-cell state
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
```

This task implements only Phase 11.

---

## Scope

Implement only:

```text
Phase 11: Timeline Exposure UI Refinement MVP
```

The goal is to refine the timeline/exposure UI so it behaves and looks closer to animation software timelines.

This phase should:

1. Display timeline frame numbers as 1-based numbers in the UI.
2. Keep internal frame indexes 0-based.
3. Use `○` for drawing frame heads instead of `●`.
4. Display held exposure ranges as block-like continuous areas instead of relying mainly on repeated text markers.
5. Keep held exposure text marker minimal or remove it if the block visual is clear.
6. Remove duplicate orientation controls.
7. Keep only one timeline orientation toggle button.
8. Remove the dedicated `+ Layer` column from vertical X-sheet mode.
9. Move X-sheet add-layer control into the top toolbar/header area.
10. Give vertical X-sheet mode a cleaner top toolbar area inspired by OpenToonz / TVPaint exposure sheet layouts.
11. Keep normal click behavior as selection only.
12. Keep New Drawing button as the safe way to create a drawing frame for now.
13. Preserve all Phase 10 exposure editing behavior.
14. Preserve sparse timeline behavior.

This is a UI refinement phase, not a new data-model phase.

---

## Very Important Restrictions

Do not implement any of the following:

* Playback
* Audio
* Onion skin
* Timeline mark data model
* `●` inbetween/timesheet mark creation
* Double-click mark behavior
* Frame name editing
* Frame rename dialog
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

Do not implement Phase 12 or later.

This phase must stay focused on UI refinement only.

---

## Important Future UX Direction

Do not implement this future behavior in Phase 11, but keep the UI direction compatible with it.

Future intended behavior:

```text
Normal click:
- Empty cell: select only
- Held exposure cell: select only
- Drawing frame head: select only

Double click:
- Empty cell: create a new drawing frame, displayed as ○
- Held exposure cell: toggle a separate inbetween/timesheet mark, displayed as ●
- Drawing frame head: open frame name editing dialog
```

Marker meaning:

```text
○ = actual drawing frame head with no assigned frame name
● = future separate inbetween/timesheet mark, not a drawing frame
block/exposure fill = held exposure range
blank = empty cell
```

For Phase 11:

* Use `○` for drawing frame heads.
* Do not use `●` for drawing frame heads.
* Do not implement `●` mark creation yet.
* Do not implement double-click behavior yet.
* Do not implement frame naming yet.

---

## Current Problem to Fix

### 1. Frame numbers are currently 0-based in the UI

Current UI displays:

```text
0, 1, 2, 3...
```

Desired UI displays:

```text
1, 2, 3, 4...
```

Important:

* Internal timeline index must remain 0-based.
* Only displayed labels should become 1-based.
* Test keys should remain 0-based unless there is a strong reason to change them.
* Callback values should remain 0-based.

Example:

```text
Displayed label "1" -> internal frameIndex 0
Displayed label "2" -> internal frameIndex 1
Displayed label "10" -> internal frameIndex 9
```

### 2. Duplicate orientation controls

Current TimelinePanel has both:

```text
Horizontal / X-sheet segmented button
Show X-sheet / Show Timeline button
```

Desired:

```text
Only one toggle control
```

Prefer keeping the simple text button:

```text
Show X-sheet
Show Timeline
```

and removing the segmented button.

If the implementation strongly prefers the segmented control instead, that is acceptable, but only one orientation control should remain.

### 3. Drawing frame head marker uses filled dot

Current drawing start marker may use:

```text
●
```

Desired drawing frame head marker:

```text
○
```

Meaning:

```text
○ = a drawing frame exists at this cell, but it has no assigned frame name yet.
```

The filled dot `●` is reserved for a future separate inbetween/timesheet mark and must not be used for drawing frame heads.

### 4. Held exposure should look more like a block

Current held exposure may be shown mainly as a text marker:

```text
─
```

Desired direction:

```text
The exposure range should visually read as one block or connected range.
```

Example:

```text
Layer 1 | [○][==== held exposure block ====][ ][○][==]
```

Implementation can be simple:

* Use background color/border styling to make held cells visually connected.
* Drawing head cell may use `○`.
* Held exposure cells may use a subtle fill and no text, or keep a very subtle `─` if helpful.
* Do not add thumbnails.
* Do not add drag handles.
* Do not add resizing handles.
* Do not implement true merged cells yet if that is too complex.

MVP acceptable approach:

```text
drawingStart cell:
- display ○
- use stronger border/fill

heldExposure cell:
- no text or a light line marker
- use same/subtle background fill as the frame block
- make neighboring held cells look visually connected if practical

empty cell:
- blank
- normal cell background
```

### 5. Vertical X-sheet `+ Layer` column should be removed

Current vertical X-sheet may show:

```text
Frame | + Layer | Layer 1 | Layer 2
```

Desired:

```text
Frame | Layer 1 | Layer 2
```

The add-layer control should move to a top toolbar/header area.

The X-sheet grid should not have a dedicated `+ Layer` data column.

### 6. X-sheet top UI should have more breathing room

Vertical X-sheet mode should have a simple top toolbar area inspired by OpenToonz / TVPaint:

```text
Current: 1 / total
[Show Timeline]
[+ Layer]
```

This does not need to be final UI.

Do not add playback functionality.

A play icon may be shown as a disabled/decorative placeholder only if it does not imply working playback. Prefer not adding it yet unless needed for layout.

---

## Files You May Create or Modify

You may modify:

```text
lib/src/ui/home_page.dart
lib/src/ui/timeline/timeline_panel.dart
lib/src/ui/timeline/layer_timeline_grid.dart
lib/src/ui/timeline/xsheet_timeline_grid.dart
lib/src/ui/timeline/timeline_cell_exposure_state.dart
test/ui/layer_timeline_grid_test.dart
test/ui/xsheet_timeline_grid_test.dart
test/ui/timeline_panel_test.dart
```

You may modify controller tests only if required by UI label behavior, but this should not be necessary.

Do not modify:

```text
lib/src/models/*
lib/src/services/project_json_serializer.dart
lib/src/services/project_file_service.dart
test/models/*
docs/*
```

Avoid modifying:

```text
lib/src/controllers/*
lib/src/services/project_repository.dart
test/controllers/*
test/services/*
```

unless absolutely necessary.

This phase should be almost entirely UI and UI tests.

---

## TimelinePanel Changes

Update:

```text
lib/src/ui/timeline/timeline_panel.dart
```

Requirements:

1. Remove duplicate orientation controls.
2. Keep only one orientation toggle.
3. The remaining orientation toggle should switch:

    * horizontal -> vertical X-sheet
    * vertical X-sheet -> horizontal
4. Show current frame using 1-based display.
5. Provide a top toolbar area that can hold:

    * timeline title
    * current frame display
    * orientation toggle
    * add layer button, if useful for X-sheet layout
6. Keep existing callbacks working:

    * onSelectLayer
    * onSelectFrame
    * onAddLayer
    * onToggleLayerVisibility
    * onLayerOpacityChanged
    * onOrientationChanged
    * exposureStateForLayer

Suggested text:

```text
Timeline • Current frame: 1
```

when internal `currentFrameIndex == 0`.

Do not change callback index values.

---

## Horizontal Timeline Grid Changes

Update:

```text
lib/src/ui/timeline/layer_timeline_grid.dart
```

Requirements:

1. Frame header labels should be 1-based.
2. Test keys should stay 0-based:

    * `timeline-frame-header-0`
    * `timeline-cell-layer-1-0`
3. `onSelectFrame` should still receive 0-based values.
4. Drawing-start cells should display `○`.
5. Held exposure cells should be block-like:

    * Prefer visual background/border connection over text.
    * Do not use `●`.
6. Empty cells should remain blank.
7. Integrated layer controls should keep working.
8. The add layer button may remain in the left header area for horizontal mode.
9. Normal click should only select layer/frame.
10. Do not implement double-click behavior in this phase.

Suggested cell display:

switch (state) {
    case TimelineCellExposureState.empty:
        return '';
    case TimelineCellExposureState.drawingStart:
        return '○';
    case TimelineCellExposureState.heldExposure:
        return ''; // or a subtle non-filled line if block styling is not clear enough
}

Suggested styling:

Drawing start: stronger block color/border, centered ○
Held exposure: same or lighter block fill, left/right borders reduced if practical
Empty: normal cell fill

If reducing borders between held cells is complex, just use a consistent held-exposure background fill for now.

---

## Vertical X-sheet Grid Changes

Update:

```text
lib/src/ui/timeline/xsheet_timeline_grid.dart
```

Requirements:

1. Remove the dedicated `+ Layer` column from the grid.
2. Frame labels should be 1-based.
3. Test keys should stay 0-based:

    * `xsheet-frame-row-0`
    * `xsheet-cell-layer-1-0`
4. `onSelectFrame` should still receive 0-based values.
5. Drawing-start cells should display `○`.
6. Held exposure cells should use block-like styling.
7. Empty cells should remain blank.
8. Layer header controls should still work:

    * select layer
    * visibility
    * opacity
9. Add layer should be available through TimelinePanel top toolbar or a compact X-sheet header control, but not as a dedicated grid column.
10. Normal click should only select layer/frame.
11. Do not implement double-click behavior in this phase.

Desired simplified grid:

```text
Frame | Layer 1 | Layer 2
  1   |   ○     |
  2   |         |
  3   |         |
```

Not:

```text
Frame | + Layer | Layer 1 | Layer 2
```

---

## HomePage Changes

Update only if needed.

Requirements:

1. Current frame display should be 1-based where shown to the user.
2. Internal timeline index must stay 0-based.
3. Existing New Drawing, - Exposure, + Exposure controls should keep working.
4. Existing Undo/Redo should keep working.
5. Existing layer controls should keep working.
6. Existing orientation state should keep working.

Example:

```text
Current frame: 1
Selected: Layer 1 / Frame 1
```

when internal index is 0.

Do not change `TimelineController.currentFrameIndex`.

---

## Tests

Update UI tests only.

### timeline_panel_test.dart

Required tests:

1. Current frame text displays 1-based frame number.
2. Only one orientation toggle control exists.
3. Orientation toggle still calls `onOrientationChanged`.
4. Add layer callback still works.
5. Exposure state callback still forwards to the active grid.
6. Horizontal mode renders.
7. Vertical X-sheet mode renders.

### layer_timeline_grid_test.dart

Required tests:

1. Frame header displays `1` for internal frame index `0`.
2. Tapping frame header `timeline-frame-header-0` still calls `onSelectFrame(0)`.
3. Drawing-start cell displays `○`.
4. Drawing-start cell does not display `●`.
5. Held exposure cell uses block/held styling or at minimum does not display `●`.
6. Empty cell remains blank.
7. Layer selection still works.
8. Add layer still works.
9. Visibility toggle still works.
10. Opacity control still works.

### xsheet_timeline_grid_test.dart

Required tests:

1. Frame row displays `1` for internal frame index `0`.
2. Tapping `xsheet-frame-row-0` or related cell still calls `onSelectFrame(0)`.
3. Dedicated `+ Layer` column is absent.
4. Add layer button is still available outside the dedicated grid column.
5. Drawing-start cell displays `○`.
6. Drawing-start cell does not display `●`.
7. Held exposure cell uses block/held styling or at minimum does not display `●`.
8. Empty cell remains blank.
9. Layer header selection still works.
10. Visibility toggle still works.
11. Opacity control still works.

---

## Analyze and Test

After implementation, run:

```bash
dart format lib/src/ui test/ui lib/main.dart
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

* UI frame labels are displayed 1-based.
* Internal frame indexes remain 0-based.
* Only one orientation toggle remains.
* Drawing frame heads display `○`.
* Drawing frame heads do not display `●`.
* Held exposure cells are visually block-like.
* Empty cells remain blank.
* Horizontal timeline still works.
* Vertical X-sheet still works.
* X-sheet no longer has a dedicated `+ Layer` column.
* Add layer still works.
* Layer selection still works.
* Visibility toggle still works.
* Opacity control still works.
* New Drawing still works.
* Increase/decrease exposure still works.
* Existing drawing still works.
* Existing Undo/Redo still works.
* No timeline mark data model is added.
* No `●` mark creation is added.
* No double-click behavior is added.
* No frame naming is added.
* No playback is added.
* No state management package is added.
* `flutter analyze` passes.
* `flutter test` passes.

---

## Reminder

Do not implement Phase 12.

Do not implement `●` inbetween/timesheet marks, double-click behavior, frame naming, playback, onion skin, exposure dragging, frame dragging, frame copy/paste, frame delete, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, or state management packages.

This phase is only timeline exposure UI refinement.
