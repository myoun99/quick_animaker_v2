# Phase 58 Codex Task - Cut Reorder Command Foundation

Create this file first:

docs/Phase_58_Codex_Task.md

Paste this full Phase 58 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_58_Codex_Task.md
git commit -m "Add Phase 58 Codex task"
git push
git status

Do not run dart format on this Markdown document.

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Command/model foundation phase.

This is not a UI phase.

Goal:

Add undoable Cut reorder support as a foundation for future Premiere-Pro-like Conte / Storyboard editing.

The long-term direction is that QuickAnimaker v2.1 will have a production-style Conte Panel where Cuts can be arranged, reviewed, and edited as a higher-level sequence.

Phase 58 should not implement the Conte Panel yet.

Phase 58 should add only the underlying command/repository support needed to reorder Cuts safely.

Current completed Cut UI state:

- New Cut UI exists.
- Rename Cut UI exists.
- Duplicate Cut UI exists.
- Delete Cut UI exists.
- Cut action row has been hardened.
- CutCommandCoordinator exists.
- Undo/redo exists through HistoryManager.
- activeCutId is owned by EditingSessionState.

Phase 58 should add:

- repository primitive for reordering Cuts within a Track
- undoable ReorderCutCommand
- coordinator method for reorder
- tests for execute / undo / redo / activeCutId safety

Do not add any reorder UI in this phase.

Do not add drag/drop.

Do not add Cut management panel.

Do not add Conte Panel.

Scope:

Add support for reordering Cuts within the same Track.

This phase should not support moving a Cut across Tracks.

Cross-track Cut moves can be added later if needed.

Recommended semantics:

- Given a TrackId, a CutId, and a target index, move that Cut to the target index within the same Track.
- Index should refer to the final insertion position after removing the Cut from its old position.
- Reordering should preserve the Cut object and CutId.
- Reordering should preserve all Layers, Frames, Strokes, canvasSize, duration, and name.
- Reordering should not change activeCutId.
- If the moved Cut was active, it remains active.
- If a different Cut was active, that same activeCutId remains active.
- Undo restores the original order.
- Redo reapplies the new order.

Repository task:

Add a ProjectRepository primitive for Cut reorder.

Suggested method direction:

void reorderCut({
required TrackId trackId,
required CutId cutId,
required int newIndex,
})

Use the existing repository style and naming conventions.

Expected repository behavior:

- finds the Track by TrackId
- finds the Cut by CutId in that Track
- removes the Cut from its old index
- inserts it at newIndex
- clamps or validates newIndex according to the existing project style

Preferred error behavior:

- missing Track should fail clearly
- missing Cut should fail clearly
- invalid index should fail clearly unless the repository already uses clamping elsewhere

Use StateError or RangeError consistently with existing repository conventions.

Do not silently no-op on missing Track or missing Cut.

Do not change activeCutId in ProjectRepository.

Do not manage undo/redo in ProjectRepository.

Command task:

Add an undoable ReorderCutCommand.

Recommended file:

lib/src/services/commands/reorder_cut_command.dart

Suggested constructor inputs:

- ProjectRepository repository
- TrackId trackId
- CutId cutId
- int newIndex

The command should capture enough state to undo and redo safely.

Expected command behavior:

Execute:

- records the original index of the Cut
- reorders the Cut to the target index
- does not change activeCutId

Undo:

- restores the Cut to the original index
- does not change activeCutId

Redo:

- reapplies the target index
- does not change activeCutId

If the command architecture only has execute/undo and HistoryManager re-executes for redo, follow existing command conventions.

The command must not duplicate ProjectRepository internals unnecessarily.

Coordinator task:

Update CutCommandCoordinator to expose a reorder method.

Suggested method:

void reorderCut({
required TrackId trackId,
required CutId cutId,
required int newIndex,
})

Expected coordinator behavior:

- creates ReorderCutCommand
- executes it through HistoryManager
- does not mutate Project directly
- does not change activeCutId itself
- does not add UI behavior

Export task:

Update the command barrel if appropriate:

lib/src/services/commands/cut_commands.dart

Export:

reorder_cut_command.dart

and keep existing exports.

Update export coverage tests if the project has them.

Required tests:

Add focused tests for repository, command, and coordinator behavior.

Likely files:

test/services/project_repository_test.dart
test/services/commands/reorder_cut_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart

If existing test organization suggests better locations, follow it.

Required repository test coverage:

1. Reorder Cut within one Track

Given Cuts A, B, C:

- moving A to index 2 results in B, C, A
- moving C to index 0 results in C, A, B
- moving B to index 1 keeps A, B, C if same index is treated as no-op

If same-index behavior should not be no-op under existing conventions, document and test the chosen behavior.

2. Missing Track / missing Cut behavior

Verify clear failure behavior.

3. activeCutId not owned by repository

This can be covered indirectly by command/coordinator tests.

Do not add activeCutId to repository.

Required command test coverage:

1. Execute reorder

Given Cuts A, B, C:

- execute moves the requested Cut to the target index
- CutIds are preserved
- Cut content is preserved
- activeCutId remains unchanged

2. Undo reorder

- undo restores original order
- activeCutId remains unchanged

3. Redo reorder

- redo reapplies reordered state
- activeCutId remains unchanged

4. Active Cut safety

Cover:

- moved Cut is active
- a different Cut is active

Expected:

- activeCutId remains valid and unchanged in both cases

Required coordinator test coverage:

1. Coordinator reorder executes through HistoryManager

Verify:

- CutCommandCoordinator.reorderCut changes order
- undo restores order
- redo reapplies order
- activeCutId remains unchanged
- HistoryManager undo/redo counts update as expected

Required export test coverage:

If cut_commands.dart exports command types, add ReorderCutCommand to the export test.

Architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

ProjectRepository primitives must not manage:

- activeCutId
- undo/redo
- controller retargeting
- UI behavior

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

Undo/redo is volatile and must not be saved to project files.

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Cut reorder must preserve CutId identity.

Cut reorder must not imply Linked Cut or material changes.

Frame name/material policy must not be changed.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Out of scope:

Do not implement any UI.

Specifically do not add:

- Cut reorder buttons
- Cut drag/drop
- Cut context menu
- Cut management panel
- Storyboard Panel
- Conte Panel
- Premiere-style panel UI
- keyboard shortcuts
- confirmation dialogs

Do not implement cross-track Cut moves.

Do not implement Linked Cut.

Do not implement Linked Layer.

Do not add Cross-cut linked paste.

Do not add Project-level material pool.

Do not add Conte Layer.

Do not add Camera Layer.

Do not add Audio Layer.

Do not change save/load.

Do not change JSON schema.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 59 or later.

Expected changed files:

Likely changed files:

lib/src/services/project_repository.dart
lib/src/services/commands/reorder_cut_command.dart
lib/src/services/commands/cut_command_coordinator.dart
lib/src/services/commands/cut_commands.dart
test/services/commands/reorder_cut_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart

Possibly changed files:

test/services/project_repository_test.dart

Avoid touching unrelated UI files.

Required checks for Codex:

Because this is a code/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is Cut reorder command foundation only
- confirmation that no UI was added
- confirmation that cross-track Cut move was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 58 is complete when:

1. ProjectRepository can reorder a Cut within a Track.
2. ReorderCutCommand exists.
3. ReorderCutCommand supports undo/redo.
4. CutCommandCoordinator exposes reorderCut.
5. Reordering preserves CutId and Cut content.
6. Reordering does not change activeCutId.
7. Active Cut remains valid after execute, undo, and redo.
8. Missing Track / missing Cut behavior is tested.
9. Export coverage is updated if applicable.
10. No UI is added.
11. No cross-track Cut move is added.
12. No Cut management panel or Conte Panel is added.
13. No save/load or JSON schema behavior is changed.
14. No broad state-management framework is introduced.
15. dart format lib test completes.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.

Manual check guidance after merge:

No major Android Studio manual UI check is required because this phase should not add visible UI.

After merge and local checks, optionally open the app once and verify:

- app launches
- existing drawing/timeline UI still appears
- existing Cut list UI still appears
- New/Rename/Duplicate/Delete Cut actions still work
- no Cut reorder UI appears yet
- no full Cut management panel appears
- no Conte Panel appears yet