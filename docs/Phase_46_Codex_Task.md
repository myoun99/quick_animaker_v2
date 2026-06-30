# Phase 46 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 46: Cut Create Command MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 45 are complete.

Recent completed work includes:

* TimelinePanel-based timeline/cell editing UI
* New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
* Timeline marks
* X/null exposure
* Linked Frame Copy/Paste MVP
* Same-layer linked paste using shared `FrameId`
* Linked frames share drawing material/source but do not share exposure duration
* Exposure +/- operates on the selected authored timeline entry, not globally by `FrameId`
* Rename conflict policy:

    * Same frame name means same material
    * Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed
    * Conflict offers Link / Cancel only
    * Rename-only is intentionally not offered
* Compact production-tool-like timeline UI
* Product direction notes
* Cut / Conte direction notes
* Cut management policy notes
* Cut management command design notes
* Minimal Cut switching between existing sample cuts
* Active-cut edit safety regression tests
* Cut switching UX polish
* Cut deletion fallback helper
* Default Cut creation helper
* ProjectRepository Cut insert/remove/rename primitives

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Cut_Conte_Direction_Notes.md
docs/Cut_Management_Policy.md
docs/Cut_Management_Command_Design.md
docs/Phase_42_Codex_Task.md
docs/Phase_43_Codex_Task.md
docs/Phase_44_Codex_Task.md
docs/Phase_45_Codex_Task.md
```

This task implements only Phase 46.

---

## Scope

Implement only:

```text
Phase 46: Cut Create Command MVP
```

This is a small command and unit-test phase.

The goal is to add an undoable command for creating a new Cut using existing helpers and repository primitives.

This phase should not add Cut create UI.

This phase should not add Cut management panel.

This phase should not add Cut delete/rename/duplicate/reorder commands.

This phase should not change save/load schema.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a future-UI-ready command that can create a new default Cut and make it active.

Expected behavior:

```text
- Build a new default Cut using createDefaultCut.
- Insert the new Cut into the target Track using ProjectRepository.insertCut.
- Make the new Cut active through EditingSessionState.activeCutId.
- Support undo and redo through the existing HistoryManager command pattern.
- Undo removes the created Cut and restores the previous active Cut.
- Redo reinserts the created Cut and makes it active again.
```

No UI should call this command yet.

---

## Important Design Boundary

This phase should implement command-level behavior, not UI behavior.

The command may coordinate:

```text
- ProjectRepository
- HistoryManager
- EditingSessionState
- createDefaultCut
```

The command should not directly depend on Flutter widgets.

The command should not directly rebuild HomePage.

If controller retargeting needs to happen in future UI integration, keep it outside this command for now or expose a small callback only if already consistent with existing command patterns.

Preferred for Phase 46:

```text
No controller retarget callback yet.
Only mutate ProjectRepository and EditingSessionState.
Unit tests verify repository/session/history state.
```

---

## Files To Inspect

Inspect at least:

```text
lib/src/commands/
lib/src/services/project_repository.dart
lib/src/services/history_manager.dart
lib/src/controllers/editing_session_state.dart
lib/src/controllers/default_cut_helpers.dart
lib/src/controllers/cut_deletion_helpers.dart
lib/src/controllers/active_cut_helpers.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
lib/src/models/layer_id.dart
lib/src/models/track_id.dart
test/commands/
test/services/project_repository_test.dart
test/controllers/default_cut_helpers_test.dart
```

Adapt file placement to the existing architecture.

If commands are currently located somewhere other than `lib/src/commands/`, follow the existing project style.

---

## Recommended File

Preferred new file if consistent with existing architecture:

```text
lib/src/commands/cut_commands.dart
```

or, if command files are more specific:

```text
lib/src/commands/create_cut_command.dart
```

Recommended test file:

```text
test/commands/create_cut_command_test.dart
```

or:

```text
test/commands/cut_commands_test.dart
```

Follow existing test naming style.

---

## Required Command Behavior

Add a command equivalent to:

```dart
class CreateCutCommand implements AppCommand {
  CreateCutCommand({
    required ProjectRepository repository,
    required EditingSessionState editingSession,
    required TrackId trackId,
    required CutId cutId,
    required LayerId layerId,
    required String name,
    int? index,
    CanvasSize canvasSize = defaultCutCanvasSize,
  });

  void execute();
  void undo();
  void redo();
}
```

Adapt to existing command interface.

Required behavior:

```text
- Caller provides TrackId.
- Caller provides CutId.
- Caller provides LayerId.
- Caller provides Cut name.
- Optional index controls insert position.
- If index is null, append or use the repository's append behavior.
- Build the Cut using createDefaultCut.
- Insert the Cut using ProjectRepository.insertCut.
- Store the previous activeCutId before execute.
- Set EditingSessionState.activeCutId to the new CutId after execute.
- Undo removes the created Cut.
- Undo restores the previous activeCutId.
- Redo reinserts the same created Cut at the same position.
- Redo sets activeCutId to the created CutId.
```

Important:

```text
- Do not generate IDs in this phase.
- Do not enforce unique Cut names.
- Do not mutate timeline/canvas/layers beyond creating the default Cut.
- Do not create initial frames.
- Do not create strokes.
- Do not change save/load.
```

---

## HistoryManager Integration

Use the existing HistoryManager command pattern.

Expected behavior:

```text
- Creating a Cut through the command should be undoable.
- Undo should remove the created Cut and restore previous active Cut.
- Redo should recreate/reinsert the created Cut and make it active.
```

If existing commands are executed through something like:

```dart
historyManager.execute(command);
```

then tests should use the same pattern.

Do not redesign HistoryManager.

Do not add persistent history.

Do not save undo/redo stacks.

---

## Active Cut Policy

From `docs/Cut_Management_Command_Design.md`:

```text
- New Cut should probably become active after creation.
- Undo should remove the created Cut and restore the previous active Cut.
- Redo should reinsert the Cut and make it active again.
```

Implement that policy in this command.

Important:

```text
- EditingSessionState owns activeCutId.
- ProjectRepository does not own activeCutId.
- The command coordinates both.
```

Do not store activeCutId in ProjectRepository.

---

## Insert Position Policy

For this MVP:

```text
- If index is provided, insert at that index.
- If index is null, append to the target Track.
```

Do not automatically infer "after active Cut" in this phase unless trivial and already supported by caller-provided index.

Preferred:

```text
Caller decides index.
Command just passes index to ProjectRepository.insertCut.
```

This keeps the command deterministic and testable.

---

## Error Behavior

Required behavior:

```text
- If target TrackId is missing, execute should throw StateError through ProjectRepository.insertCut.
- If index is invalid, execute should throw RangeError through ProjectRepository.insertCut.
- If execute fails, activeCutId should not change.
- Undo before execute should either throw StateError or be safely disallowed according to existing command style.
- Redo before execute should either throw StateError or be safely disallowed according to existing command style.
```

Do not over-engineer command lifecycle if existing commands already have a convention.

Follow existing command style.

---

## Part A: Add Command

Add the create Cut command in the existing command architecture.

The command should:

```text
- build a default Cut
- insert it into the repository
- update EditingSessionState.activeCutId
- support undo/redo
```

Keep it small.

Avoid UI dependencies.

Avoid Flutter widget dependencies.

Avoid save/load dependencies.

---

## Part B: Add Unit Tests

Add command tests.

Required test coverage:

```text
1. execute inserts a new default Cut into the target Track.
2. execute appends when index is null.
3. execute inserts at a specific index.
4. execute sets activeCutId to the new CutId.
5. execute allows duplicate Cut names.
6. execute creates one default Layer named Layer 1.
7. undo removes the created Cut.
8. undo restores the previous activeCutId.
9. redo reinserts the created Cut.
10. redo sets activeCutId to the created CutId.
11. missing TrackId causes execute to throw StateError.
12. invalid index causes execute to throw RangeError.
13. failed execute does not change activeCutId.
14. command does not create frames or strokes.
15. command does not add UI behavior.
```

Use unit tests, not widget tests.

Do not require Android Studio manual tests for this command-only phase.

---

## Part C: Do Not Wire UI

Do not update:

```text
lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart
```

Do not add:

```text
- New Cut button
- Delete Cut button
- Rename Cut UI
- Cut management panel
- dialogs
- menus
- toolbar actions
- shortcuts
```

This command should be available for future UI but not used by the app yet.

---

## Part D: Preserve Existing Behavior

The app should continue to:

```text
- show Cut 1 and Cut 2
- keep Cut 1 active by default
- switch between Cut 1 and Cut 2
- keep active-cut editing scoped correctly
```

No user-visible behavior should change.

---

## Policy Requirements To Preserve

From `docs/Cut_Management_Policy.md`:

```text
- CutId is identity.
- Cut names are display labels.
- Duplicate Cut names are allowed.
- Undo/Redo is volatile session history.
- Undo/Redo stack must not be saved.
```

From `docs/Cut_Management_Command_Design.md`:

```text
- ProjectRepository owns project data mutation.
- EditingSessionState owns activeCutId.
- HistoryManager records volatile undoable/redoable command history.
- Future Cut create should use createDefaultCut or equivalent.
- New Cut should probably become active.
```

From linked-frame policy:

```text
- Linked frames share material/source only.
- Timeline placement remains independent.
- Cross-cut linked paste is not implemented.
```

Do not weaken these policies.

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut create UI
- Cut delete UI
- Cut rename UI
- Cut duplicate UI
- Cut reorder UI
- Cut management panel
- Undoable Cut delete command
- Undoable Cut rename command
- Undoable Cut duplicate command
- Undoable Cut reorder command
- Undoable active cut switch
- Save/load lastActiveCutId
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
- Global FrameId refactor
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
```

Do not implement Phase 47 or later.

---

## Allowed Changes

Allowed:

```text
- Add an undoable CreateCutCommand or equivalent.
- Add unit tests for execute/undo/redo behavior.
- Add exports only if needed by existing command organization.
```

Preferred result:

```text
No existing user-visible behavior changes.
No HomePage changes.
No UI changes.
No JSON schema changes.
No save/load changes.
```

---

## Expected User-Visible Behavior

After Phase 46:

```text
The app should look and behave exactly the same as Phase 45.
```

The change is internal test-covered command support for future Cut create UI.

---

## Tests / Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

Do not run `dart format` on Markdown files.

---

## Manual Check In Android Studio

Manual app check is optional for this command-only phase.

If performed, verify:

```text
1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No Cut create/delete/rename UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Create Cut command exists.
2. Command uses createDefaultCut or equivalent.
3. Command inserts the Cut through ProjectRepository.
4. Command updates EditingSessionState.activeCutId to the new Cut.
5. Undo removes the created Cut.
6. Undo restores the previous activeCutId.
7. Redo reinserts the created Cut.
8. Redo makes the created Cut active again.
9. Duplicate Cut names are allowed.
10. Caller supplies CutId and LayerId.
11. No ID generator is added.
12. No Cut create UI is added.
13. No Cut management panel is added.
14. No JSON schema changes are made.
15. No save/load changes are made.
16. Existing user-visible behavior remains unchanged.
17. dart format lib test passes.
18. flutter analyze passes.
19. flutter test passes.
20. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 46 Cut Create Command MVP.

Changed:
- Added undoable Create Cut command.
- Command creates a default Cut using createDefaultCut.
- Command inserts the Cut through ProjectRepository.
- Command updates EditingSessionState.activeCutId.
- Added tests for execute/undo/redo behavior.
- Existing user-visible behavior is unchanged.
- No Cut management UI was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_46_Codex_Task.md` and implement Phase 46 only. Add an undoable Create Cut command that uses `createDefaultCut`, inserts the new Cut through `ProjectRepository.insertCut`, updates `EditingSessionState.activeCutId` to the new Cut, and supports undo/redo by removing/reinserting the Cut and restoring activeCutId. Caller supplies CutId and LayerId; do not add ID generation. Add unit tests. Do not add Cut create UI, Cut management panel, delete/rename/duplicate/reorder commands, save/load changes, JSON schema changes, Conte Panel, or Phase 47+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
