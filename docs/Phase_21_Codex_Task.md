# Phase 21 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 21: Icon Timeline Toolbar MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 20 and related follow-up fixes are already complete.

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
* Cell action hint
* Linked Frame Copy/Paste MVP
* `Copy Frame` action
* `Paste Linked Frame` action
* Linked use count display
* In-memory copied frame reference
* Same-layer linked paste using the same `FrameId`
* Timeline/cell action toolbar relocated into `TimelinePanel`
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
```

This task implements only Phase 21.

---

## Scope

Implement only:

```text
Phase 21: Icon Timeline Toolbar MVP
```

The goal is to reduce visual clutter in the TimelinePanel toolbar by replacing long text action buttons with compact icon-style buttons and tooltips.

This is a UI cleanup phase.

This phase should implement:

1. Convert timeline/cell action buttons from visible long text buttons to icon-style buttons.
2. Add `Tooltip` text for every timeline/cell action button.
3. Preserve all existing action keys.
4. Preserve all existing behavior.
5. Preserve current Cell action hint, Linked uses, Copied status, and Layer/Frame/Cell status for now.
6. Preserve current toolbar location inside TimelinePanel.
7. Update widget tests to verify buttons still exist, tooltips exist, and behavior is unchanged.

Do not add new editing features.

Do not remove hint/status text yet.

---

## Important UI Direction

The long-term UI direction is:

```text
- Timeline/cell actions live in TimelinePanel.
- Buttons are compact.
- Buttons are icon-based.
- Text labels are available through Tooltip.
- The screen should feel closer to a professional animation tool, not a tutorial UI.
```

Phase 21 is only the first icon toolbar step.

Future phases may remove or hide long hints/status text, but not this phase.

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

- Exposure:
- Existing exposure decrease behavior must remain.

Undo/Redo:
- Existing Undo/Redo behavior must remain.
```

---

## Very Important Restrictions

Do not implement any of the following:

* Removing hint text
* Hiding linked use count
* Hiding copied frame status
* Removing Layer / Frame / Cell status
* Moving toolbar back to HomePage top row
* Tooltip-only UI without accessible labels
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

Do not implement Phase 22 or later.

This phase must stay focused on iconizing the existing TimelinePanel toolbar actions.

---

## Design Direction

Current Phase 20 toolbar contains visible text buttons:

```text
New Frame
Blank / X
Mark ●
Copy Frame
Paste Linked Frame
Rename Frame
Delete Cell
- Exposure
+ Exposure
```

Phase 21 should make them compact.

Recommended visual labels/icons:

```text
New Frame: ○+
Blank / X: X
Mark ●: ●
Copy Frame: copy icon or ⧉
Paste Linked Frame: link/paste icon or 🔗+
Rename Frame: edit icon or ✎
Delete Cell: trash icon
- Exposure: −
+ Exposure: +
```

Prefer Material icons where available and clear:

```dart
Icons.add_box_outlined
Icons.close
Icons.circle
Icons.content_copy
Icons.link
Icons.edit_outlined
Icons.delete_outline
Icons.remove
Icons.add
```

However, for animation-specific symbols, text glyphs are acceptable:

```text
○
X
●
−
+
```

Choose a simple consistent approach.

Recommended MVP:

* Use `IconButton` or compact `TextButton`/`OutlinedButton` with short symbol child.
* Wrap every action in `Tooltip`.
* Keep existing `ValueKey`s on the clickable widget or a stable parent.

Important:

* Tests currently find buttons by key and cast to `TextButton` in some cases.
* If converting to `IconButton`, update tests to avoid assuming `TextButton`.
* Tests should check enabled/disabled through a helper that supports both `TextButton` and `IconButton`.

---

## Required Button Keys

The following keys must remain available:

```dart
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

The key may be placed on the `IconButton` itself.

Do not rename keys.

---

## Required Tooltip Labels

Add tooltips for each action.

Required tooltip strings:

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

Note:

* Keep action semantics clear.
* The visible button child may be icon-only or symbol-only.
* The tooltip contains the readable label.
* Existing tests that used `find.text('New Frame')` may need to change to tooltip checks or key checks.

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

## Helper Recommendation

To avoid repeated `Tooltip + IconButton` boilerplate, add a small private helper in `HomePage`.

Recommended:

```dart
Widget _timelineActionButton({
  required String keyName,
  required String tooltip,
  required VoidCallback? onPressed,
  required Widget icon,
});
```

or:

```dart
Widget _timelineActionIconButton({
  required ValueKey<String> key,
  required String tooltip,
  required IconData icon,
  required VoidCallback? onPressed,
});
```

For symbol buttons:

```dart
Widget _timelineActionSymbolButton({
  required ValueKey<String> key,
  required String tooltip,
  required String symbol,
  required VoidCallback? onPressed,
});
```

Keep it simple.

Do not introduce a new public widget unless it clearly reduces complexity.

---

## HomePage Changes

Update:

```text
lib/src/ui/home_page.dart
```

Modify `_buildTimelineActionToolbar` only as needed.

Current `cell-actions-section` should remain.

The visible section title `Cell Actions` may remain for now.

Replace long text action buttons inside the section with compact icon/symbol buttons.

Required:

* Keep `cell-actions-section`.
* Keep `cell-action-hint`.
* Keep `timeline-action-toolbar`.
* Keep status texts:

    * `current-layer-status`
    * `current-frame-status`
    * `current-cell-status`
    * `linked-frame-uses-status`
    * `copied-frame-status`
* Keep exact action behavior and callback wiring.

---

## TimelinePanel Changes

No TimelinePanel changes should be required unless tests reveal layout issues.

Do not move the toolbar again.

Do not change timeline grid behavior.

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
3. Tooltips exist for:

    * New Frame
    * Blank / X
    * Mark ●
    * Copy Frame
    * Paste Linked Frame
    * Rename Frame
    * Delete Cell
    * Decrease Exposure
    * Increase Exposure
4. Button enable/disable tests do not assume `TextButton`.
5. Tapping buttons by key still works.
6. No duplicate action buttons with same key.
7. Cell Actions section remains visible.
8. Cell action hint remains visible.
9. Linked uses status remains visible.
10. Copied frame status remains visible.
11. Timeline action toolbar remains visible.
12. Existing Phase 19 linked paste widget tests still pass.
13. Existing Phase 20 relocation widget tests still pass.

If tests need helper changes, add helper functions such as:

```dart
bool _isActionButtonEnabled(WidgetTester tester, ValueKey<String> key);
```

This helper should support:

```text
TextButton
IconButton
```

or any final chosen button widget.

Example:

```dart
bool _isButtonEnabled(WidgetTester tester, ValueKey<String> key) {
  final widget = tester.widget(find.byKey(key));
  return switch (widget) {
    TextButton(:final onPressed) => onPressed != null,
    IconButton(:final onPressed) => onPressed != null,
    _ => throw StateError('Unsupported button type: ${widget.runtimeType}'),
  };
}
```

For tooltip tests:

```dart
expect(find.byTooltip('New Frame'), findsOneWidget);
```

Use key checks for actions, tooltip checks for readable labels.

Avoid relying on visible text labels for action buttons.

---

### TimelinePanel tests

Usually no changes required.

If existing TimelinePanel tests assert text button labels, update them to keys/tooltips.

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
* Existing Phase 17, 18, 19, and 20 widget tests still pass.

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
7. Any behavior notes about icon toolbar and tooltips

---

## Completion Criteria

This task is complete only when:

* Timeline/cell action buttons are compact icon/symbol buttons.
* Each action button has a tooltip.
* Required tooltip labels exist.
* Existing button keys remain unchanged.
* Existing action behavior remains unchanged.
* Existing button enable/disable behavior remains unchanged.
* Existing Cell Actions section remains.
* Existing `timeline-action-toolbar` remains.
* Existing `cell-action-hint` remains.
* Existing status keys remain:

    * `current-layer-status`
    * `current-frame-status`
    * `current-cell-status`
    * `linked-frame-uses-status`
    * `copied-frame-status`
* Existing Copy/Paste Linked Frame behavior remains unchanged.
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
* No hint removal is introduced.
* No linked uses hiding is introduced.
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

Do not implement Phase 22.

Do not remove hint text, hide linked uses, hide copied status, implement duplicate paste, make independent, unlink, rename conflict dialog, automatic name-based linking, cross-layer paste, cross-cut paste, project-level material pool, linked layer, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Icon Timeline Toolbar MVP.
