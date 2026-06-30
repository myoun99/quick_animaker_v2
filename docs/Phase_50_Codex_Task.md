# Phase 50 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 50: Cut Duplicate Command MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 49 are complete.

Recent completed work includes:

- TimelinePanel-based timeline/cell editing UI
- New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
- Timeline marks
- X/null exposure
- Linked Frame Copy/Paste MVP
- Same-layer linked paste using shared `FrameId`
- Linked frames share drawing material/source but do not share exposure duration
- Exposure +/- operates on the selected authored timeline entry, not globally by `FrameId`
- Rename Frame conflict policy:
    - Same frame name means same material
    - Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed
    - Conflict offers Link / Cancel only
    - Rename-only is intentionally not offered
- Compact production-tool-like timeline UI
- Product direction notes
- Cut / Conte direction notes
- Cut management policy notes
- Cut management command design notes
- Minimal Cut switching between existing sample cuts
- Active-cut edit safety regression tests
- Cut switching UX polish
- Cut deletion fallback helper
- Default Cut creation helper
- ProjectRepository Cut insert/remove/rename primitives
- Undoable Create Cut command
- Undoable Rename Cut command
- Undoable Delete Cut command
- Independent Cut duplicate helper

Read these documents before making changes:

- `docs/Architecture.md`
- `docs/ImplementationPlan.md`
- `docs/Product_Direction_Notes.md`
- `docs/Cut_Structure_Preparation.md`
- `docs/Cut_Structure_Audit.md`
- `docs/Active_Cut_State_Design.md`
- `docs/Id_Scope_Decision.md`
- `docs/Cut_Conte_Direction_Notes.md`
- `docs/Cut_Management_Policy.md`
- `docs/Cut_Management_Command_Design.md`
- `docs/Phase_42_Codex_Task.md`
- `docs/Phase_43_Codex_Task.md`
- `docs/Phase_44_Codex_Task.md`
- `docs/Phase_45_Codex_Task.md`
- `docs/Phase_46_Codex_Task.md`
- `docs/Phase_47_Codex_Task.md`
- `docs/Phase_48_Codex_Task.md`
- `docs/Phase_49_Codex_Task.md`

This task implements only Phase 50.

---

## Scope

Implement only Phase 50: Cut Duplicate Command MVP.

This is a small command and unit-test phase.

The goal is to add an undoable command for duplicating an existing Cut as an independent deep copy.

This phase should not add Cut duplicate UI.

This phase should not add Cut management panel.

This phase should not add Cut reorder behavior.

This phase should not implement Linked Cut.

This phase should not implement Linked Layer.

This phase should not implement cross-cut linked paste.

This phase should not add project-level material pool.

This phase should not change save/load schema.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a future-UI-ready command that can duplicate a Cut as an independent deep copy, insert it into the project, make it active, and support undo/redo.

Expected behavior:

- Duplicate an existing source Cut by `CutId`.
- Use `duplicateCutAsIndependentCopy`.
- Use caller-provided new `CutId`.
- Use caller-provided new Cut name.
- Use caller-provided `LayerId` mapping.
- Use caller-provided `FrameId` mapping.
- Insert the duplicated Cut through `ProjectRepository.insertCut`.
- Default insertion should be controlled by caller-provided target `TrackId` and optional index.
- If index is null, append to the target Track.
- After execute, set `EditingSessionState.activeCutId` to the duplicated Cut.
- Undo removes the duplicated Cut.
- Undo restores the previous `activeCutId`.
- Redo reinserts the same duplicated Cut.
- Redo makes the duplicated Cut active again.

No UI should call this command yet.

---

## Important Product Policy

Cut duplicate MVP policy from `docs/Cut_Management_Policy.md`:

- Initial Cut duplicate should be an independent deep copy.
- A duplicated Cut should receive a new `CutId`.
- Duplicated layers should receive new `LayerId`s.
- Duplicated frames should receive new `FrameId`s.
- The duplicate should not be linked by default.
- Timeline placement in the duplicate should be copied as independent authored placement.
- Strokes/material content may be copied as independent content for the MVP.

Important:

- Do not implement Linked Cut.
- Do not implement Linked Layer.
- Do not implement cross-cut linked frames.
- Do not introduce project-level material/source pool.
- Do not share timeline placement.
- Do not share active selection state.

---

## Important Design Boundary

This phase should implement command-level behavior, not UI behavior.

The command may coordinate:

- `ProjectRepository`
- `HistoryManager`
- `EditingSessionState`
- `duplicateCutAsIndependentCopy`

The command should not directly coordinate:

- `HomePage`
- `CutListBar`
- Flutter widgets
- controller rebuild / retarget
- save/load metadata

Reason:

- The command should mutate project data and session state.
- Future UI integration can handle controller retargeting around command execution.
- This phase should not wire the command into the app UI.

Do not directly depend on Flutter widgets.

Do not change `HomePage`.

---

## Files To Inspect

Inspect at least:

- `lib/src/services/commands/`
- `lib/src/services/commands/create_cut_command.dart`
- `lib/src/services/commands/rename_cut_command.dart`
- `lib/src/services/commands/delete_cut_command.dart`
- `lib/src/services/command.dart`
- `lib/src/services/history_manager.dart`
- `lib/src/services/project_repository.dart`
- `lib/src/controllers/editing_session_state.dart`
- `lib/src/controllers/cut_duplicate_helpers.dart`
- `lib/src/models/cut.dart`
- `lib/src/models/cut_id.dart`
- `lib/src/models/layer_id.dart`
- `lib/src/models/frame_id.dart`
- `lib/src/models/track_id.dart`
- `test/services/create_cut_command_test.dart`
- `test/services/rename_cut_command_test.dart`
- `test/services/delete_cut_command_test.dart`
- `test/controllers/cut_duplicate_helpers_test.dart`
- `test/services/project_repository_test.dart`

Adapt file placement to the existing architecture.

---

## Recommended File

Preferred new file if consistent with existing architecture:

- `lib/src/services/commands/duplicate_cut_command.dart`

Recommended test file:

- `test/services/duplicate_cut_command_test.dart`

If the project style prefers grouped command files, use that existing style instead.

---

## Required Command Behavior

Add a command equivalent to `DuplicateCutCommand implements Command`.

Constructor direction:

- `ProjectRepository repository`
- `EditingSessionState editingSession`
- source `CutId`
- target `TrackId`
- new duplicate `CutId`
- new duplicate Cut name
- `Map<LayerId, LayerId>` layer id mapping
- `Map<FrameId, FrameId>` frame id mapping
- optional insert index

Required behavior:

- Caller provides the source `CutId`.
- Caller provides the target `TrackId`.
- Caller provides new duplicate `CutId`.
- Caller provides new duplicate Cut name.
- Caller provides all new `LayerId` mappings.
- Caller provides all new `FrameId` mappings.
- Command finds the source Cut by `CutId`.
- Command duplicates the source Cut using `duplicateCutAsIndependentCopy`.
- Command inserts the duplicate through `ProjectRepository.insertCut`.
- If index is null, append to the target Track.
- If index is provided, insert at that index.
- Command stores previous `activeCutId`.
- Command sets `EditingSessionState.activeCutId` to the duplicated Cut after execute.
- Undo removes the duplicated Cut.
- Undo restores the previous `activeCutId`.
- Redo reinserts the same duplicated Cut at the same target Track/index.
- Redo sets `activeCutId` to the duplicated Cut.
- Duplicate Cut names remain allowed.
- Do not change source Cut.
- Do not share source CutId, LayerId, or FrameId with duplicate.

Important:

- Do not generate IDs in this phase.
- Do not add a global ID generator.
- Do not enforce unique Cut names.
- Do not implement Cut duplicate UI.
- Do not change save/load.

---

## Source Cut Lookup

The command needs to find the source Cut before duplicating.

Preferred approach:

- Add a minimal private command-side lookup by reading `repository.requireProject()`.
- Store the source Cut or duplicated Cut before insertion.
- Do not add broad query APIs unless clearly useful and consistent with existing repository style.

Acceptable helper if small and useful:

- `Cut requireCut(CutId cutId)`
- `Cut requireCutById(CutId cutId)`

Only add this if it stays focused.

Do not refactor repository architecture.

---

## Insert Position Policy

For this MVP:

- Caller supplies target `TrackId`.
- Caller may supply insert index.
- If insert index is null, append to target Track.
- Do not automatically infer “after source Cut” unless the caller passes the index.
- Do not move source Cut.
- Do not reorder other Cuts except by normal insertion behavior.

Reason:

- The command should be deterministic and easy to test.
- Future UI can decide whether “Duplicate” means insert after source, append, or another rule.

---

## HistoryManager Integration

Use the existing `HistoryManager` command pattern.

Expected behavior:

- Duplicating a Cut through the command should be undoable.
- Undo should remove the duplicated Cut and restore previous active Cut.
- Redo should reinsert the duplicated Cut and make it active again.
- Undo/Redo history remains volatile.
- Do not save undo/redo stacks.

If existing commands are executed through `historyManager.execute(command)`, tests should use the same pattern.

Do not redesign `HistoryManager`.

Do not add persistent history.

Do not save undo/redo stacks.

---

## Error Behavior

Required behavior:

- If source `CutId` is missing, execute should throw `StateError`.
- If target `TrackId` is missing, execute should throw `StateError` through `ProjectRepository.insertCut`.
- If insert index is invalid, execute should throw `RangeError` through `ProjectRepository.insertCut`.
- If required layer id mapping is missing, execute should throw `ArgumentError` through `duplicateCutAsIndependentCopy`.
- If required frame id mapping is missing, execute should throw `ArgumentError` through `duplicateCutAsIndependentCopy`.
- If execute fails before insertion, project state should remain unchanged.
- If execute fails before insertion, `activeCutId` should remain unchanged.
- Undo before execute should throw `StateError` or follow existing command lifecycle convention.
- Redo before execute should throw `StateError` or follow existing command lifecycle convention.

Follow existing command style, especially `CreateCutCommand`, `RenameCutCommand`, and `DeleteCutCommand`.

---

## Atomicity Note

This phase does not need a full transaction system.

However, the command should avoid changing `activeCutId` until after repository insertion succeeds.

Preferred order:

1. Find source Cut.
2. Build duplicate Cut.
3. Store previous `activeCutId`.
4. Insert duplicate Cut.
5. Set `activeCutId` to duplicate Cut.

This minimizes partial state changes if duplication or insertion fails.

---

## Part A: Add Command

Add the duplicate Cut command in the existing command architecture.

The command should:

- find source Cut
- create independent duplicate through `duplicateCutAsIndependentCopy`
- insert through `ProjectRepository.insertCut`
- update `EditingSessionState.activeCutId`
- support undo/redo

Keep it small.

Avoid UI dependencies.

Avoid Flutter widget dependencies.

Avoid save/load dependencies.

---

## Part B: Add Unit Tests

Add command tests.

Required test coverage:

1. execute duplicates source Cut by `CutId`.
2. execute uses `CutId`, not Cut name.
3. execute inserts duplicate into target Track.
4. execute appends when index is null.
5. execute inserts at specific index.
6. execute sets `activeCutId` to duplicate Cut.
7. execute stores previous `activeCutId`.
8. duplicate uses caller-provided new `CutId`.
9. duplicate uses caller-provided new name.
10. duplicate remaps LayerIds.
11. duplicate remaps FrameIds.
12. duplicate remaps timeline drawing exposures.
13. duplicate preserves blank/X/null exposures.
14. duplicate preserves duration and canvas size.
15. duplicate does not mutate source Cut.
16. duplicate allows duplicate Cut names.
17. undo removes duplicated Cut.
18. undo restores previous `activeCutId`.
19. redo reinserts duplicated Cut.
20. redo makes duplicated Cut active.
21. missing source `CutId` causes execute to throw `StateError`.
22. missing target `TrackId` causes execute to throw `StateError`.
23. invalid index causes execute to throw `RangeError`.
24. missing LayerId mapping causes execute to throw `ArgumentError`.
25. missing FrameId mapping causes execute to throw `ArgumentError`.
26. failed execute does not change project state.
27. failed execute does not change `activeCutId`.
28. undo before execute throws or follows existing command lifecycle convention.
29. command does not add UI behavior.

Use unit tests, not widget tests.

Do not require Android Studio manual tests for this command-only phase.

---

## Part C: Do Not Wire UI

Do not update:

- `lib/src/ui/home_page.dart`
- `lib/src/ui/cut/cut_list_bar.dart`

Do not add:

- Duplicate Cut button
- Delete Cut button
- Rename Cut button
- New Cut button
- Cut management panel
- dialogs
- menus
- toolbar actions
- shortcuts

This command should be available for future UI but not used by the app yet.

---

## Part D: Preserve Existing Behavior

The app should continue to:

- show Cut 1 and Cut 2
- keep Cut 1 active by default
- switch between Cut 1 and Cut 2
- keep active-cut editing scoped correctly

No user-visible behavior should change.

---

## Policy Requirements To Preserve

From `docs/Cut_Management_Policy.md`:

- Cut duplicate MVP should be an independent deep copy.
- Duplicated Cut should receive new `CutId`.
- Duplicated Layers should receive new `LayerId`s.
- Duplicated Frames should receive new `FrameId`s.
- The duplicate should not be linked by default.
- Timeline placement should be copied as independent authored placement.
- Linked Cut is long-term only.
- Undo/Redo is volatile session history.
- Undo/Redo stack must not be saved.

From `docs/Cut_Management_Command_Design.md`:

- Future Cut duplicate MVP should be an independent deep copy.
- It should not create Linked Cut.
- It should not create Linked Layer.
- It should not create cross-cut linked frames.
- Timeline placement should be copied as independent authored placement.
- Strokes/material should be copied as independent content for the MVP.
- Duplicate should be undoable/redoable.

From linked-frame policy:

- Linked frames share material/source only.
- Timeline placement remains independent.
- Cross-cut linked paste is not implemented.

Do not weaken these policies.

---

## Very Important Restrictions

Do not implement any of the following:

- Cut duplicate UI
- Cut delete UI
- Cut rename UI
- Cut create UI
- Cut reorder UI
- Cut management panel
- Undoable Cut reorder command
- Undoable active cut switch
- Save/load `lastActiveCutId`
- Persistent project open/close flow
- Linked Cut
- Linked Layer
- Cross-cut paste
- Cross-layer paste
- Project-level material pool
- Conte Panel
- Conte Layer
- Storyboard Panel
- Camera Layer
- Audio Layer behavior
- Layer type enum
- V/A track UI
- Global `FrameId` refactor
- ID generation refactor
- JSON schema changes
- Save/load format changes
- Undo/Redo redesign
- Timeline behavior redesign
- Timeline placement sharing
- Canvas painting behavior redesign
- Canvas layout redesign
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier

Do not implement Phase 51 or later.

---

## Allowed Changes

Allowed:

- Add an undoable `DuplicateCutCommand` or equivalent.
- Add small private command-side source Cut lookup.
- Add minimal focused helper only if needed.
- Add unit tests for execute/undo/redo behavior.
- Use existing `duplicateCutAsIndependentCopy`.

Preferred result:

- No existing user-visible behavior changes.
- No `HomePage` changes.
- No UI changes.
- No JSON schema changes.
- No save/load changes.

---

## Expected User-Visible Behavior

After Phase 50:

The app should look and behave exactly the same as Phase 49.

The change is internal test-covered command support for future Cut duplicate UI.

---

## Tests / Validation

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`

Do not run `dart format` on Markdown files.

---

## Manual Check In Android Studio

Manual app check is optional for this command-only phase.

If performed, verify:

1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No Cut create/delete/rename/duplicate UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.

---

## Completion Criteria

This phase is complete only when:

1. Duplicate Cut command exists.
2. Command finds source Cut by `CutId`.
3. Command uses `duplicateCutAsIndependentCopy`.
4. Duplicate Cut uses caller-provided new `CutId`.
5. Duplicate Cut uses caller-provided new name.
6. Duplicate Cut remaps LayerIds.
7. Duplicate Cut remaps FrameIds.
8. Duplicate Cut remaps timeline drawing exposures.
9. Command inserts duplicate through `ProjectRepository.insertCut`.
10. Command sets `activeCutId` to duplicate after execute.
11. Undo removes duplicated Cut.
12. Undo restores previous `activeCutId`.
13. Redo reinserts duplicated Cut.
14. Redo sets `activeCutId` to duplicate again.
15. No ID generator is added.
16. No Cut duplicate UI is added.
17. No Cut management panel is added.
18. No JSON schema changes are made.
19. No save/load changes are made.
20. Existing user-visible behavior remains unchanged.
21. `dart format lib test` passes.
22. `flutter analyze` passes.
23. `flutter test` passes.
24. `git status` is clean after commit.

---

## Suggested Final Response From Codex

After completing the task, summarize:

Implemented Phase 50 Cut Duplicate Command MVP.

Changed:

- Added undoable Duplicate Cut command.
- Command duplicates source Cut through `duplicateCutAsIndependentCopy`.
- Command inserts duplicate through `ProjectRepository.insertCut`.
- Command updates `EditingSessionState.activeCutId` to duplicated Cut.
- Command supports undo/redo.
- Added tests for execute/undo/redo behavior.
- Existing user-visible behavior is unchanged.
- No Cut duplicate UI was added.

Validation:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_50_Codex_Task.md` and implement Phase 50 only.

Add an undoable Duplicate Cut command that finds a source Cut by `CutId`, uses `duplicateCutAsIndependentCopy` with caller-provided new `CutId`, new name, `LayerId` mapping, and `FrameId` mapping, inserts the duplicate through `ProjectRepository.insertCut`, updates `EditingSessionState.activeCutId` to the duplicate, and supports undo/redo by removing/reinserting the duplicate and restoring activeCutId.

Do not add ID generation.

Do not add Cut duplicate UI, Cut management panel, reorder command, undoable active cut switch, save/load changes, JSON schema changes, Linked Cut, Linked Layer, cross-cut paste, project-level material pool, Conte Panel, or Phase 51+ work.

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`