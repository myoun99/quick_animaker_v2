# Phase 23 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 23: Frame Name Link Policy MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 22 and related follow-up fixes are already complete.

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
```

This task implements only Phase 23.

---

## Scope

Implement only:

```text
Phase 23: Frame Name Link Policy MVP
```

The goal is to enforce the professional animation workflow rule:

```text
Same frame name = same material.
Same name with different FrameId should not be allowed.
```

This phase should update frame renaming so that if the user tries to rename a drawing frame to a name already used by another frame in the same layer, the app offers to link/merge into the existing material instead of allowing an independent duplicate name.

This phase should implement:

1. Detect frame name conflicts during Rename Frame.
2. If no conflict exists, keep current rename behavior.
3. If the same name exists on the same `FrameId`, keep current rename/no-op behavior.
4. If the same name exists on a different `FrameId`, show a confirmation dialog.
5. Confirmation dialog has only:

    * `Link`
    * `Cancel`
6. `Link` changes timeline references from the current frame’s `FrameId` to the existing frame’s `FrameId`.
7. `Cancel` makes no change.
8. Do not offer `Rename only`.
9. Remove the old backing frame if it becomes unreferenced after linking.
10. Preserve marks, exposure positions, blank entries, and timeline placement.
11. Make the link/merge operation Undo/Redo-able.
12. Update tests for controller behavior and widget dialog behavior.

Do not implement Make Independent or Unlink.

Do not implement cross-layer or cross-cut name linking.

---

## Professional Workflow Rule

In this project, `Frame.name` represents the user-facing cel/material name.

The production rule is:

```text
Same name means same drawing material.
```

Therefore:

```text
Allowed:
- Multiple authored timeline entries with the same FrameId and same name.
- Renaming a linked frame changes the shared Frame.name for all linked uses.

Not allowed:
- Two different FrameIds in the same layer with the same non-empty name.
```

Important:

* `FrameId` remains the internal material identity.
* `Frame.name` is the professional cel/material name.
* Do not use `Frame.name` as the internal ID.
* Do not replace `FrameId` with name-based lookup.
* Use name conflicts only as a user-facing link/merge policy.

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

All current behavior must remain unless explicitly changed by the rename conflict policy:

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
- New Phase 23 behavior:
  - If target name already exists on another FrameId, show Link / Cancel dialog.

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

* Rename only when name conflict exists
* Same-name independent frames
* Make Independent
* Unlink
* Cross-layer name linking
* Cross-cut name linking
* Project-level material pool
* Linked layer
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

Do not implement Phase 24 or later.

This phase must stay focused on frame name conflict linking policy.

---

## Name Normalization Policy

Use the existing frame name normalization behavior if present.

Expected:

```text
- Empty or whitespace input clears the frame name.
- Cleared/null/empty names do not trigger conflict linking.
- Non-empty names should be trimmed.
```

Recommended conflict matching:

```text
- Use the normalized trimmed name.
- Exact string match after trimming.
- Case-sensitive for this MVP unless existing code already normalizes case.
```

Do not add complex locale/case-insensitive matching in this phase.

---

## Rename Conflict Behavior

When renaming current frame to `targetName`:

### Case 1: targetName is empty/null

Existing behavior:

```text
Clear current frame name.
No conflict dialog.
No link.
```

### Case 2: no other frame in same layer has targetName

Existing behavior:

```text
Rename current frame to targetName.
```

### Case 3: same FrameId already has targetName

Existing behavior/no-op:

```text
No conflict dialog.
Keep frame linked as-is.
```

### Case 4: another FrameId in same layer has targetName

New behavior:

```text
Show confirmation dialog:
A frame named "<targetName>" already exists.
Link this frame to the existing "<targetName>" drawing?
```

Dialog actions:

```text
Link
Cancel
```

If Cancel:

```text
No model changes.
Dialog closes.
```

If Link:

```text
- Replace timeline drawing exposures that reference the current frameId with the existing frameId.
- Preserve all timeline start indexes.
- Preserve all blank entries.
- Preserve all marks.
- Preserve exposure durations/placement as authored timeline entries.
- Remove current frame from layer.frames if no timeline entry references it anymore.
- Do not clone strokes.
- Do not copy name.
- Do not create a new FrameId.
- The existing frame keeps its strokes/name.
- Operation is Undo/Redo-able.
```

---

## Important Linked Duration Rule

This phase must preserve the linked exposure duration hotfix.

When linking by name:

```text
- The linked frames share material via existingFrameId.
- Timeline authored entries remain independent.
- Exposure + / - must still operate on the selected authored timeline entry, not the first entry with the same FrameId.
```

Do not regress this.

---

## Controller Changes

Update:

```text
lib/src/controllers/timeline_controller.dart
```

Add minimal APIs.

Suggested APIs:

```dart
Frame? frameWithNameInLayer({
  required Layer layer,
  required String name,
  FrameId? exceptFrameId,
});
```

or:

```dart
FrameId? existingFrameIdForName({
  required Layer layer,
  required String name,
  FrameId? exceptFrameId,
});
```

Add link/merge API:

```dart
void linkFrameToExistingFrameForLayer({
  required LayerId layerId,
  required FrameId sourceFrameId,
  required FrameId targetFrameId,
});
```

Rules for `linkFrameToExistingFrameForLayer`:

* `sourceFrameId` and `targetFrameId` must exist in the same layer.
* If sourceFrameId == targetFrameId, no-op.
* Replace every drawing timeline exposure referencing `sourceFrameId` with drawing exposure referencing `targetFrameId`.
* Preserve timeline keys/start indexes.
* Preserve blank exposures.
* Preserve marks.
* Preserve frame durations as much as current model allows.
* Remove source frame from `layer.frames` if no timeline entries reference it anymore.
* Use existing command/history mechanism so Undo/Redo works.
* No-op or throw consistently with existing controller style for invalid IDs.

Important:

```text
Do not mutate frame strokes.
Do not clone frames.
Do not create a new FrameId.
```

If existing `renameFrameForLayer` can be extended safely, keep behavior clear and tested.

Recommended separation:

```text
renameFrameForLayer = rename only when no conflict
linkFrameToExistingFrameForLayer = conflict Link action
```

Do not hide conflict behavior inside controller without clear API/tests.

---

## UI Changes

Update:

```text
lib/src/ui/home_page.dart
```

Current Rename Frame dialog should remain for entering the new name.

When the user submits a non-empty target name:

1. Normalize/trim the name.
2. Check if another frame in the current layer already has that name.
3. If no conflict:

    * call existing rename method.
4. If conflict with another FrameId:

    * show Link / Cancel confirmation dialog.
5. If Link:

    * call controller link/merge method.
6. If Cancel:

    * no change.

Recommended dialog title:

```text
Frame name already exists
```

Recommended dialog body:

```text
A frame named "<name>" already exists.
Link this frame to the existing drawing?
```

Recommended buttons:

```text
Cancel
Link
```

Suggested keys:

```dart
ValueKey<String>('frame-name-conflict-dialog')
ValueKey<String>('frame-name-conflict-cancel-button')
ValueKey<String>('frame-name-conflict-link-button')
```

The existing rename dialog keys, if any, should remain.

Do not implement Rename only button.

Do not automatically link without confirmation.

---

## Tests

Add/update tests.

### Controller tests

Update or add:

```text
test/controllers/frame_name_link_controller_test.dart
```

or use an existing controller test file if preferred.

Required tests:

1. Finds existing frame by normalized name.
2. Empty/whitespace name does not trigger conflict policy.
3. Renaming to a unique name still renames the frame.
4. Linking source frame to target frame replaces all source timeline references with target FrameId.
5. Linking preserves timeline start indexes.
6. Linking preserves blank exposures.
7. Linking preserves marks.
8. Linking removes source frame if unreferenced.
9. Linking keeps source frame if still referenced somehow.
10. Linking does not clone strokes.
11. Linking does not create new FrameId.
12. Linking is Undo/Redo-able.
13. Linked use count updates after linking.
14. Exposure duration operations after linking still target selected authored timeline entry.
15. Same name / different FrameId state can be resolved by link.

---

### Widget tests

Update:

```text
test/widget_test.dart
```

Required tests:

1. Rename to unique name works as before.
2. Rename to empty/whitespace clears name as before.
3. Rename to existing name on another FrameId shows conflict dialog.
4. Conflict dialog has key `frame-name-conflict-dialog`.
5. Conflict dialog has `Cancel` and `Link` buttons.
6. Cancel closes dialog and leaves frames unchanged.
7. Link closes dialog and links current frame to existing named frame.
8. After Link, timeline entries that previously referenced source frame show the existing frame name.
9. After Link, linked use count increases.
10. After Link, editing/drawing shared material still works if existing tests can cover it.
11. After Link, Exposure + / - on one authored entry does not modify another authored entry with the same FrameId.
12. No `Rename only` option appears.
13. Existing Rename Frame behavior on held drawing still works.
14. Existing Copy/Paste Linked Frame behavior still works.
15. Existing compact status text remains.
16. Existing action tooltips remain.

Use robust tests. Do not rely on long hint text from old phases.

---

### JSON / model tests

No JSON schema changes should be required.

If model invariants are added, update model tests only as needed.

Do not introduce a migration.

---

## Backward Compatibility

No JSON schema changes should be required.

Required:

* Existing project JSON tests still pass.
* Existing timeline exposure tests still pass.
* Existing mark tests still pass.
* Existing frame editing tests still pass.
* Existing linked frame copy/paste tests still pass.
* Existing linked exposure duration regression tests still pass.
* Existing save/load tests still pass.
* Existing Phase 17 through Phase 22 widget tests still pass after expectation updates.

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
7. Any behavior notes about frame name conflict linking

---

## Completion Criteria

This task is complete only when:

* Rename to a unique non-empty name still works.
* Rename to empty/whitespace still clears name.
* Rename to an existing same-layer name on another FrameId shows Link / Cancel dialog.
* Dialog has stable key `frame-name-conflict-dialog`.
* Dialog has stable key `frame-name-conflict-cancel-button`.
* Dialog has stable key `frame-name-conflict-link-button`.
* Cancel makes no model changes.
* Link replaces source FrameId timeline references with target FrameId.
* Link preserves authored timeline positions.
* Link preserves blank entries.
* Link preserves marks.
* Link removes source frame if unreferenced.
* Link does not clone strokes.
* Link does not create a new FrameId.
* Link is Undo/Redo-able.
* Same name / different FrameId is not allowed through Rename only.
* No Rename only button exists.
* Existing Copy/Paste Linked Frame behavior remains unchanged.
* Existing linked exposure duration hotfix remains unchanged.
* Existing compact status text remains.
* Existing action tooltips remain.
* Existing button keys remain unchanged.
* Existing action behavior remains unchanged.
* Existing `○` display remains.
* Existing frame name display remains.
* Existing `X` display remains.
* Existing `●` display priority remains.
* Existing selected cell highlight remains.
* Existing selected layer highlight remains.
* Existing New Frame behavior remains.
* Existing Blank / X behavior remains.
* Existing Mark ● behavior remains.
* Existing Rename Frame behavior remains for non-conflict names.
* Existing Delete Cell behavior remains.
* Existing + / - Exposure behavior remains.
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

Do not implement Phase 24.

Do not implement Rename only on conflict, same-name independent frames, duplicate paste, make independent, unlink, cross-layer linking, cross-cut linking, project-level material pool, linked layer, layer types, camera layer, audio layer, storyboard layer, section folding, double-click behavior, long-press behavior, right-click menus, keyboard shortcuts, playback, onion skin, exposure dragging, frame dragging, frame copy/paste ranges, frame reorder UI, thumbnails, audio, advanced brush engine, bitmap engine, file picker UI, timesheet export, PDF export, CSV export, or state management packages.

This phase is only Frame Name Link Policy MVP.
