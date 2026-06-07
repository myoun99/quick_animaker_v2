# Phase 19 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 19: Linked Frame Copy/Paste MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 18 and related follow-up fixes are already complete.

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
```

This task implements only Phase 19.

---

## Scope

Implement only:

```text
Phase 19: Linked Frame Copy/Paste MVP
```

The goal is to add a basic linked frame copy/paste workflow.

Important:

This is not duplicate-frame paste.

This phase should paste the same underlying drawing material by reusing the same `FrameId`.

When a copied frame is pasted elsewhere, both timeline positions should reference the same `Frame`. Editing the drawing from either position should affect all linked positions because they share the same `FrameId`.

This phase should implement:

1. Copy Frame action.
2. Paste Linked Frame action.
3. In-memory copied frame clipboard in the UI/controller layer.
4. Linked paste using the copied `FrameId`.
5. Linked use count display.
6. Cell action hint updates for copy/paste.
7. Undo/Redo for paste linked frame.
8. Tests for controller behavior, UI behavior, status/hint display, and existing behavior preservation.

Do not implement duplicate copy/paste.

Do not clone strokes in this phase.

Do not create a new `FrameId` when pasting.

---

## Important Professional Workflow Rule

In this project, a drawing frame represents animation material/cel material.

Professional workflow assumption:

```text
Same displayed frame name = same material.
Same material should be linked.
```

However, internally, the program should still use `FrameId` as the true link identity.

Recommended interpretation:

```text
FrameId = internal unique material identity
Frame.name = user-facing cel/material name
TimelineExposure.frameId = reference to material
```

For Phase 19:

* Linked frame copy/paste should use `FrameId`.
* Do not use `Frame.name` as the internal link key.
* Do not implement automatic linking by rename yet.
* Do not implement name conflict handling yet.

Future phase candidate:

```text
Frame Name Link Policy MVP:
- If renaming to an existing frame name that belongs to a different FrameId,
  show Link / Cancel dialog.
- Link merges timeline references into the existing material.
- Cancel keeps the current frame unchanged.
- Same name with different FrameId should be prevented.
```

That future behavior is not part of Phase 19.

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

Current behavior must remain:

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

* Duplicate Frame Paste
* Clone Frame Paste
* Stroke duplication
* New FrameId creation on paste
* System clipboard integration
* Keyboard shortcuts
* Multi-frame copy
* Exposure range copy
* Timeline range paste
* Cut/cross-layer clipboard
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

Do not implement Phase 20 or later.

This phase must stay focused on linked frame copy/paste MVP.

---

## Design Direction

Add two buttons to the existing Cell Actions section:

```text
Copy Frame
Paste Linked Frame
```

Suggested keys:

```dart
ValueKey<String>('copy-frame-button')
ValueKey<String>('paste-linked-frame-button')
```

Copy should store a simple in-memory reference to the copied frame.

Recommended MVP clipboard shape:

```dart
class _CopiedFrameReference {
  const _CopiedFrameReference({
    required this.layerId,
    required this.frameId,
    required this.frameName,
  });

  final LayerId layerId;
  final FrameId frameId;
  final String? frameName;
}
```

This can live in `HomePage` for MVP.

Alternative:

* Add clipboard state to `TimelineController` if cleaner.
* Keep it in memory only.
* No JSON persistence.
* No system clipboard.

Recommended MVP:

```text
Keep copied frame state in HomePage.
Use TimelineController method to paste the copied FrameId.
```

---

## Copy Frame Behavior

Copy Frame should be enabled when the current selected cell resolves to a drawing frame.

Allowed:

```text
drawingStart
held drawing
drawingStart + Mark ●
held drawing + Mark ●
```

Not allowed:

```text
blankStart / X
blankHeld
empty
mark-only empty
no active layer
negative frame index
```

Rules:

* Copy stores the resolved `FrameId`.
* Copy does not change the project.
* Copy does not create Undo/Redo entry.
* Copy does not change selection.
* Copy does not change marks.
* Copy does not change timeline.
* Copy does not change frame names.
* Copy should remember copied frame name for UI hint/status only.
* Copy can copy a linked frame just like any other frame.

If the copied frame is later deleted and no longer exists, Paste Linked Frame should become disabled or no-op safely.

---

## Paste Linked Frame Behavior

Paste Linked Frame should be enabled when:

```text
- active layer exists
- current frame index >= 0
- copied frame reference exists
- copied frame still exists in the target project/layer context
```

For Phase 19, keep paste within the current project.

Cross-layer paste can be allowed only if the copied `FrameId` exists in the target layer. Since current model likely stores frames per layer, prefer same-layer paste only for MVP.

Recommended MVP:

```text
Copy and paste only within the same layer.
```

If active layer is different from copied layer:

```text
Paste Linked Frame disabled.
```

Rules:

* Paste inserts/replaces a `TimelineExposure.drawing(frameId: copiedFrameId)` at the current frame index.
* Paste does not create a new `Frame`.
* Paste does not create a new `FrameId`.
* Paste does not clone strokes.
* Paste does not clone name.
* Paste keeps the current cell's `●` mark if any.
* Paste should replace `X` if current cell is blankStart.
* Paste should replace existing drawingStart if current cell is drawingStart.
* Paste should create a drawingStart if current cell is held drawing.
* Paste should create a drawingStart if current cell is blankHeld.
* Paste should create a drawingStart if current cell is empty.
* Paste should not shift following timeline entries in this phase.
* Paste should be Undo/Redo-able.

Examples:

### Paste on X

Before:

```text
0 -> X
copy frame A
paste at 0
```

After:

```text
0 -> drawing A
```

### Paste on drawingStart

Before:

```text
0 -> drawing A
5 -> drawing B
copy A
paste at 5
```

After:

```text
0 -> drawing A
5 -> drawing A
```

If frame B is no longer referenced anywhere, it may be removed from `frames`.

### Paste on held drawing

Before:

```text
0 -> drawing A
copy B
paste at 3
```

After:

```text
0 -> drawing A
3 -> drawing B
```

### Paste on empty

Before:

```text
timeline empty
copy A
paste at 6
```

After:

```text
6 -> drawing A
```

### Paste on mark

Before:

```text
0 -> X
mark at 0
copy A
paste at 0
```

After:

```text
0 -> drawing A
mark at 0 remains
```

Display may show `●` because mark priority remains higher.

---

## Linked Use Count

Add a small linked use count to the existing status area or Cell Actions hint area.

Recommended key:

```dart
ValueKey<String>('linked-frame-uses-status')
```

Recommended display:

```text
Linked uses: 2
```

Rules:

* If current cell resolves to a drawing frame:

    * Count how many timeline drawing exposure entries in the current layer reference the same `FrameId`.
    * Display `Linked uses: N`.
* If current cell does not resolve to a drawing frame:

    * Display `Linked uses: -`
* Count only authored drawing exposures in `layer.timeline`, not held cells.
* If a single authored drawingStart uses this frame, display `Linked uses: 1`.
* If linked paste creates another timeline entry using same `FrameId`, display `Linked uses: 2`.

This is a minimal visibility feature so users can understand whether a frame is linked.

Do not add cell-level link icon in this phase.

Do not add link overlay in this phase.

---

## Cell Action Hint Updates

Update existing Phase 18 hint to include copy/paste where helpful.

Examples:

If drawingStart without mark:

```text
Drawing start: Copy Frame can copy this material; Delete Cell will delete this drawing frame.
```

If drawingStart with mark:

```text
Drawing start + Mark ●: Copy Frame can copy this material; Delete Cell will delete this drawing and its mark.
```

If held drawing:

```text
Held drawing: Copy Frame can copy this material; Rename Frame can rename the held drawing.
```

If X and clipboard has a copied frame:

```text
Blank start (X): Paste Linked Frame will replace X with the copied drawing.
```

If X and clipboard is empty:

```text
Blank start (X): New Frame will replace X with a drawing.
```

If empty and clipboard has a copied frame:

```text
Empty: Paste Linked Frame can place the copied drawing here.
```

If empty and clipboard is empty:

```text
Empty: New Frame can create a drawing here.
```

If empty + Mark ● and clipboard has a copied frame:

```text
Empty + Mark ●: Paste Linked Frame can place the copied drawing here; Mark ● will remove the mark.
```

Keep tests robust with substring checks.

---

## Controller Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Add minimal APIs.

Suggested APIs:

```dart
bool canPasteLinkedFrameAt({
  required Layer layer,
  required int frameIndex,
  required FrameId copiedFrameId,
});

void pasteLinkedFrameForLayer({
  required LayerId layerId,
  required FrameId frameId,
});
```

Optional helper:

```dart
int linkedUseCountForLayerFrame({
  required Layer layer,
  required FrameId frameId,
});
```

Rules for `canPasteLinkedFrameAt`:

* false if frameIndex < 0
* false if frameId does not exist in layer.frames
* true otherwise

Rules for `pasteLinkedFrameForLayer`:

* use current frame index
* target layer must exist
* frameId must exist in target layer.frames
* create/replace timeline entry at current index with drawing exposure referencing frameId
* do not create new Frame
* do not clone strokes
* preserve marks
* if replacing a drawingStart that referenced another FrameId, remove the old Frame from frames only if no remaining timeline entries reference it
* use existing layer snapshot command or equivalent so Undo/Redo works
* no-op or clear StateError if invalid, consistent with existing controller style

Do not change existing New Frame, Blank, Mark, Rename, Delete, Exposure logic.

---

## UI Changes

Update:

```text
lib/src/ui/home_page.dart
```

Add copied frame state.

Suggested field:

```dart
_CopiedFrameReference? _copiedFrame;
```

Add buttons in Cell Actions section:

```text
Copy Frame
Paste Linked Frame
```

Suggested keys:

```dart
ValueKey<String>('copy-frame-button')
ValueKey<String>('paste-linked-frame-button')
```

Enablement:

```text
Copy Frame:
- enabled when current selected cell resolves to a drawing frame

Paste Linked Frame:
- enabled when copied frame exists
- active layer is the copied layer
- copied FrameId still exists in active layer.frames
- current frame index >= 0
```

Button behavior:

```text
Copy Frame:
- store copied layerId, frameId, frameName
- call setState

Paste Linked Frame:
- call controller paste linked frame
- call setState
```

Optional status text:

```text
Copied: A1
```

If useful, key:

```dart
ValueKey<String>('copied-frame-status')
```

This is optional.

Required:

```dart
ValueKey<String>('linked-frame-uses-status')
```

---

## Tests

Add/update tests.

### Controller tests

Add or update:

```text
test/controllers/frame_copy_paste_controller_test.dart
```

or use an existing controller test file if preferred.

Required tests:

1. `canPasteLinkedFrameAt` is false for negative index.
2. `canPasteLinkedFrameAt` is false when frameId does not exist.
3. `canPasteLinkedFrameAt` is true when frameId exists and index is non-negative.
4. Paste linked frame on X replaces blank entry with drawing entry.
5. Paste linked frame on drawingStart replaces old drawing entry.
6. Replacing drawingStart removes old backing frame only if unreferenced.
7. Replacing drawingStart keeps old backing frame if still referenced.
8. Paste linked frame on held drawing creates authored drawingStart.
9. Paste linked frame on blankHeld creates authored drawingStart.
10. Paste linked frame on empty creates authored drawingStart.
11. Paste linked frame preserves existing mark at same index.
12. Paste linked frame does not create a new Frame.
13. Paste linked frame does not clone strokes.
14. Paste linked frame is Undo/Redo-able.
15. Linked use count returns 1 for single authored use.
16. Linked use count returns 2 after linked paste creates second authored use.
17. Dense frames are not created.

---

### Widget tests

Update:

```text
test/widget_test.dart
```

Required tests:

1. Copy Frame button is visible.
2. Paste Linked Frame button is visible.
3. Copy Frame button has key `copy-frame-button`.
4. Paste Linked Frame button has key `paste-linked-frame-button`.
5. Copy Frame disabled on initial X.
6. Paste Linked Frame disabled when clipboard is empty.
7. New Frame on X creates drawingStart.
8. Copy Frame enabled on drawingStart.
9. Copy Frame stores copied frame and enables Paste Linked Frame.
10. Paste Linked Frame on another cell creates linked drawing exposure.
11. Linked use count changes from 1 to 2 after paste.
12. Editing/drawing behavior still uses the same frame when linked. If full stroke drawing is hard in widget test, cover this in controller/model tests instead.
13. Paste on X replaces X.
14. Paste preserves `●` mark.
15. Cell action hint mentions Copy Frame on drawingStart.
16. Cell action hint mentions Paste Linked Frame when clipboard is available.
17. Existing New Frame / Blank X / Mark / Rename / Delete / Exposure buttons still work.
18. Existing Phase 17 status texts remain visible.
19. Existing Phase 18 Cell Actions section and hint remain visible.

Use `ensureVisible + pumpAndSettle` before tapping toolbar buttons if they are in a horizontal scroll view.

Prefer substring checks for hints.

---

### UI tests

Update timeline grid tests only if needed.

No timeline cell rendering changes should be required.

---

## Backward Compatibility

No model or JSON changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17 and Phase 18 tests still pass.

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
7. Any behavior notes about linked frame copy/paste

---

## Completion Criteria

This task is complete only when:

* Copy Frame button exists.
* Paste Linked Frame button exists.
* Copy Frame button has key `copy-frame-button`.
* Paste Linked Frame button has key `paste-linked-frame-button`.
* Copy Frame is enabled on drawingStart.
* Copy Frame is enabled on held drawing.
* Copy Frame is disabled on X.
* Copy Frame is disabled on blankHeld.
* Copy Frame is disabled on empty.
* Copy Frame stores the resolved FrameId.
* Paste Linked Frame uses the copied FrameId.
* Paste Linked Frame does not create a new Frame.
* Paste Linked Frame does not clone strokes.
* Paste Linked Frame on X replaces X with drawing exposure.
* Paste Linked Frame on drawingStart replaces existing drawing exposure.
* Paste Linked Frame on held drawing creates authored drawingStart.
* Paste Linked Frame on blankHeld creates authored drawingStart.
* Paste Linked Frame on empty creates authored drawingStart.
* Paste Linked Frame preserves current cell mark.
* Paste Linked Frame is Undo/Redo-able.
* Linked use count is visible.
* Linked use count has key `linked-frame-uses-status`.
* Linked use count displays 1 for single authored use.
* Linked use count displays 2 after linked paste.
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
* Existing Cell Actions section remains.
* Existing Cell action hint remains.
* Undo/Redo remains.
* No model/JSON migration is introduced.
* No duplicate frame paste is introduced.
* No new FrameId is created by Paste Linked Frame.
* No stroke cloning is introduced.
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

Do not implement Phase 20.

Do not implement duplicate paste, make independent, unlink, rename conflict dialog, automatic name-based linking, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Linked Frame Copy/Paste MVP.
