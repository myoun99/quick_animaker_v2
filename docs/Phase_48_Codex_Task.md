# Phase 48 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 48: Cut Delete Command MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 47 are complete.

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

This task implements only Phase 48.

---

## Scope

Implement only Phase 48: Cut Delete Command MVP.

This is a small command and unit-test phase.

The goal is to add an undoable command for deleting an existing Cut.

This phase should not add Cut delete UI.

This phase should not add Cut management panel.

This phase should not add Cut duplicate/reorder commands.

This phase should not add undoable active cut switch.

This phase should not change save/load schema.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a future-UI-ready command that can delete a Cut, keep `EditingSessionState.activeCutId` valid, and support undo/redo.

Expected behavior:

- Delete an existing Cut through `ProjectRepository.removeCut`.
- Use `CutId`, not Cut name.
- If the deleted Cut is active, use `cutDeletionFallbackFor` to choose the next active Cut.
- Fallback order is previous Cut, then next Cut, then create a new default Cut.
- If fallback decision is `useExistingCut`, set `EditingSessionState.activeCutId` to that CutId.
- If fallback decision is `createDefaultCut`, create and insert a replacement default Cut using `createDefaultCut`, then set it active.
- If the deleted Cut is not active, keep `activeCutId` unchanged.
- Undo restores the deleted Cut at its original Track and index.
- Undo restores the previous active Cut selection.
- Redo deletes the Cut again and reapplies fallback behavior.
- No UI should call this command yet.

---

## Important Product Policy

Cut delete policy from `docs/Cut_Management_Policy.md`:

- Deleting the active Cut should fall back to previous Cut.
- If there is no previous Cut, fall back to next Cut.
- If no Cut remains, create a new default empty Cut.
- Deleting the last Cut is allowed from the user's perspective.
- The app should not end a command with zero editable Cuts.
- `activeCutId` must never point to a missing Cut after the command completes.

This phase implements the command behavior only.

Do not add delete UI.

---

## Important Design Boundary

This phase should implement command-level behavior, not UI behavior.

The command may coordinate:

- `ProjectRepository`
- `HistoryManager`
- `EditingSessionState`
- `cutDeletionFallbackFor`
- `createDefaultCut`

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
- `lib/src/services/command.dart`
- `lib/src/services/history_manager.dart`
- `lib/src/services/project_repository.dart`
- `lib/src/controllers/editing_session_state.dart`
- `lib/src/controllers/cut_deletion_helpers.dart`
- `lib/src/controllers/default_cut_helpers.dart`
- `lib/src/models/cut.dart`
- `lib/src/models/cut_id.dart`
- `lib/src/models/layer_id.dart`
- `lib/src/models/track_id.dart`
- `test/services/create_cut_command_test.dart`
- `test/services/rename_cut_command_test.dart`
- `test/controllers/cut_deletion_helpers_test.dart`
- `test/controllers/default_cut_helpers_test.dart`
- `test/services/project_repository_test.dart`

Adapt file placement to the existing architecture.

---

## Recommended File

Preferred new file if consistent with existing architecture:

- `lib/src/services/commands/delete_cut_command.dart`

Recommended test file:

- `test/services/delete_cut_command_test.dart`

If the project style prefers grouped command files, use that existing style instead.

---

## Required Command Behavior

Add a command equivalent to `DeleteCutCommand implements Command`.

Constructor direction:

- `ProjectRepository repository`
- `EditingSessionState editingSession`
- `CutId cutId`
- Optional replacement `CutId` and `LayerId` for last-Cut deletion fallback
- Optional replacement Cut name
- Optional replacement CanvasSize

Required behavior:

- Caller provides the target `CutId`.
- Command deletes by `CutId`, not by name.
- Command stores the deleted Cut.
- Command stores the deleted Cut's original `TrackId`.
- Command stores the deleted Cut's original index.
- Command stores the previous `activeCutId`.
- If the deleted Cut is active, command uses `cutDeletionFallbackFor` before mutating the project.
- If fallback is an existing Cut, command sets `activeCutId` to that CutId after deletion.
- If fallback is create-default-Cut, command creates a replacement default Cut using `createDefaultCut`.
- Replacement default Cut should be inserted into a deterministic target Track.
- Replacement default Cut should become active.
- If the deleted Cut is not active, command does not change `activeCutId`.
- Undo restores the deleted Cut at its original Track and index.
- Undo removes the replacement default Cut if one was created by last-Cut fallback.
- Undo restores the previous `activeCutId`.
- Redo deletes the same Cut again.
- Redo recreates/reinserts replacement default Cut if needed.
- Redo reapplies active Cut fallback.
- Duplicate Cut names remain allowed.
- Do not change frame/layer/timeline contents except by removing/restoring the whole Cut.

Important:

- Do not generate IDs in this phase.
- If a replacement default Cut is needed, caller should provide replacement `CutId` and `LayerId`.
- Do not add a global ID generator.
- Do not enforce unique Cut names.
- Do not implement Cut delete UI.
- Do not change save/load.

---

## Replacement Default Cut Policy

Last Cut deletion needs a replacement default Cut.

For this MVP:

- If deleting the only Cut would require `createDefaultCut`, the command should require caller-provided replacement `CutId` and replacement `LayerId`.
- The replacement name may default to `Cut 1` or be caller-provided.
- The replacement CanvasSize may use `defaultCutCanvasSize` or be caller-provided.
- The replacement should be inserted into the same Track from which the deleted Cut was removed when possible.
- If the original Track still exists but has no Cuts, insert the replacement into that Track.
- Do not create a new Track in this phase.
- Do not design project creation/opening behavior in this phase.

If replacement IDs are not provided and deleting the only Cut requires replacement, throw `StateError`.

This keeps ID generation outside the command.

---

## Original Location Lookup

The command needs to restore the deleted Cut to its original location.

Preferred approach:

- Add a minimal private command-side lookup by reading `repository.requireProject()`.
- Store original `TrackId` and original cut index before removal.
- Do not add broad query APIs unless clearly useful and consistent with existing repository style.

Acceptable helper if small and useful:

- `CutLocation`
- `locationOfCut(CutId cutId)`

Only add this if it stays focused.

Do not refactor repository architecture.

---

## HistoryManager Integration

Use the existing `HistoryManager` command pattern.

Expected behavior:

- Deleting a Cut through the command should be undoable.
- Undo should restore the deleted Cut and previous active Cut.
- Redo should delete again and reapply fallback.
- Undo/Redo history remains volatile.
- Do not save undo/redo stacks.

If existing commands are executed through `historyManager.execute(command)`, tests should use the same pattern.

Do not redesign `HistoryManager`.

Do not add persistent history.

Do not save undo/redo stacks.

---

## Error Behavior

Required behavior:

- If target `CutId` is missing, execute should throw `StateError`.
- If deleting the only Cut requires a replacement default Cut but replacement IDs are missing, execute should throw `StateError`.
- If execute fails, project state should remain unchanged.
- If execute fails, `activeCutId` should remain unchanged.
- Undo before execute should throw `StateError` or follow existing command lifecycle convention.
- Redo before execute should throw `StateError` or follow existing command lifecycle convention.

Follow existing command style, especially `CreateCutCommand` and `RenameCutCommand`.

---

## Part A: Add Command

Add the delete Cut command in the existing command architecture.

The command should:

- find and store original Cut location
- compute fallback before deleting when target Cut is active
- delete through `ProjectRepository.removeCut`
- update `EditingSessionState.activeCutId` only when needed
- create replacement default Cut for last-Cut deletion when needed
- support undo/redo

Keep it small.

Avoid UI dependencies.

Avoid Flutter widget dependencies.

Avoid save/load dependencies.

---

## Part B: Add Unit Tests

Add command tests.

Required test coverage:

1. execute deletes the target Cut by `CutId`.
2. execute uses `CutId`, not Cut name.
3. execute returns project state without the deleted Cut.
4. deleting an active middle Cut falls back to previous Cut.
5. deleting the first active Cut falls back to next Cut.
6. deleting the last active Cut falls back to previous Cut.
7. deleting a non-active Cut does not change `activeCutId`.
8. deleting the only Cut creates a replacement default Cut.
9. replacement default Cut uses caller-provided replacement `CutId`.
10. replacement default Cut uses caller-provided replacement `LayerId`.
11. replacement default Cut becomes active.
12. undo restores the deleted Cut at its original Track and index.
13. undo removes the replacement default Cut if one was created.
14. undo restores previous `activeCutId`.
15. redo deletes the Cut again.
16. redo reapplies active Cut fallback.
17. missing target `CutId` causes execute to throw `StateError`.
18. last-Cut deletion without replacement IDs throws `StateError`.
19. failed execute does not change project state.
20. failed execute does not change `activeCutId`.
21. undo before execute throws or follows existing command lifecycle convention.
22. command does not add UI behavior.

Use unit tests, not widget tests.

Do not require Android Studio manual tests for this command-only phase.

---

## Part C: Do Not Wire UI

Do not update:

- `lib/src/ui/home_page.dart`
- `lib/src/ui/cut/cut_list_bar.dart`

Do not add:

- Delete Cut button
- Rename Cut button
- New Cut button
- Duplicate Cut button
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

- `CutId` is identity.
- Cut names are display labels.
- Duplicate Cut names are allowed.
- Deleting active Cut falls back previous, then next, then new default Cut.
- Deleting the last Cut is allowed from the user's perspective.
- Undo/Redo is volatile session history.
- Undo/Redo stack must not be saved.

From `docs/Cut_Management_Command_Design.md`:

- Cut delete should use `cutDeletionFallbackFor`.
- Last-Cut delete should use `createDefaultCut`.
- `ProjectRepository` owns project data mutation.
- `EditingSessionState` owns `activeCutId`.
- `HistoryManager` records volatile undoable/redoable command history.

From linked-frame policy:

- Linked frames share material/source only.
- Timeline placement remains independent.
- Cross-cut linked paste is not implemented.

Do not weaken these policies.

---

## Very Important Restrictions

Do not implement any of the following:

- Cut delete UI
- Cut rename UI
- Cut create UI
- Cut duplicate UI
- Cut reorder UI
- Cut management panel
- Undoable Cut duplicate command
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

Do not implement Phase 49 or later.

---

## Allowed Changes

Allowed:

- Add an undoable `DeleteCutCommand` or equivalent.
- Add small private command-side location lookup.
- Add minimal focused helper/value type only if needed.
- Add unit tests for execute/undo/redo behavior.
- Use existing `cutDeletionFallbackFor`.
- Use existing `createDefaultCut`.

Preferred result:

- No existing user-visible behavior changes.
- No `HomePage` changes.
- No UI changes.
- No JSON schema changes.
- No save/load changes.

---

## Expected User-Visible Behavior

After Phase 48:

The app should look and behave exactly the same as Phase 47.

The change is internal test-covered command support for future Cut delete UI.

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
3. No Cut create/delete/rename UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.

---

## Completion Criteria

This phase is complete only when:

1. Delete Cut command exists.
2. Command deletes the target Cut using `CutId`.
3. Command stores deleted Cut location.
4. Command uses `cutDeletionFallbackFor` for active Cut deletion.
5. Command uses `createDefaultCut` for last-Cut replacement.
6. Undo restores deleted Cut at original Track/index.
7. Undo restores previous `activeCutId`.
8. Redo deletes Cut again.
9. Redo reapplies fallback behavior.
10. Last-Cut deletion creates a replacement default Cut.
11. Replacement IDs are caller-provided.
12. No ID generator is added.
13. No Cut delete UI is added.
14. No Cut management panel is added.
15. No JSON schema changes are made.
16. No save/load changes are made.
17. Existing user-visible behavior remains unchanged.
18. `dart format lib test` passes.
19. `flutter analyze` passes.
20. `flutter test` passes.
21. `git status` is clean after commit.

---

## Suggested Final Response From Codex

After completing the task, summarize:

Implemented Phase 48 Cut Delete Command MVP.

Changed:

- Added undoable Delete Cut command.
- Command deletes Cut through `ProjectRepository.removeCut`.
- Command uses `cutDeletionFallbackFor` for active Cut fallback.
- Command uses `createDefaultCut` for last-Cut replacement.
- Command updates `EditingSessionState.activeCutId` when needed.
- Added tests for execute/undo/redo behavior.
- Existing user-visible behavior is unchanged.
- No Cut management UI was added.

Validation:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_48_Codex_Task.md` and implement Phase 48 only.

Add an undoable Delete Cut command that deletes a Cut by `CutId` through `ProjectRepository.removeCut`, uses `cutDeletionFallbackFor` when deleting the active Cut, creates a replacement default Cut with `createDefaultCut` when deleting the only Cut, updates `EditingSessionState.activeCutId` only when needed, and supports undo/redo by restoring the deleted Cut and previous active Cut.

Caller must provide replacement `CutId` and `LayerId` for last-Cut deletion fallback. Do not add ID generation.

Add unit tests.

Do not add Cut delete UI, Cut management panel, duplicate/reorder commands, undoable active cut switch, save/load changes, JSON schema changes, Conte Panel, or Phase 49+ work.

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`