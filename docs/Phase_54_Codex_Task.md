# Phase 54 Codex Task - Cut Command Coordinator Preparation

Create this file first:

docs/Phase_54_Codex_Task.md

Paste this full Phase 54 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_54_Codex_Task.md
git commit -m "Add Phase 54 Codex task"
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

Small code/test preparation phase.

This is not a UI phase.

Goal:

Add a small Cut command coordinator/helper layer that prepares and executes existing Cut commands through HistoryManager.

Phase 53 added pure input planning helpers for command IDs and maps.

Phase 54 should add a thin coordinator that combines:

- ProjectRepository
- EditingSessionState
- HistoryManager
- Cut command input planner
- existing Cut commands

The goal is to prepare for future Cut management UI without putting command construction logic directly into widgets.

Do not add UI.

Do not wire this into existing widgets.

Do not change existing command behavior.

Do not change save/load.

Do not change JSON schema.

Do not redesign repository, command, or history architecture.

Primary implementation task:

Add a small coordinator/helper for user-level Cut command execution.

Recommended file:

lib/src/services/commands/cut_command_coordinator.dart

If the existing project structure suggests a better nearby location or naming pattern, follow it, but keep the purpose the same.

The coordinator should use the existing command barrel if appropriate:

lib/src/services/commands/cut_commands.dart

The coordinator should expose simple methods for future UI use.

Suggested class name:

CutCommandCoordinator

Suggested constructor dependencies:

- ProjectRepository repository
- EditingSessionState editingSession
- HistoryManager historyManager

Suggested methods:

1. createCut

Purpose:

Plan IDs with planCreateCutCommandInput, create a CreateCutCommand, and execute it through HistoryManager.

Suggested signature direction:

void createCut({
required TrackId trackId,
String name = 'New Cut',
})

Expected behavior:

- reads current project from ProjectRepository
- plans CutId and LayerId using the Phase 53 planner
- creates CreateCutCommand
- executes it through HistoryManager
- activeCutId is updated by the command
- undo/redo is recorded by HistoryManager

2. renameCut

Purpose:

Create a RenameCutCommand and execute it through HistoryManager.

Suggested signature direction:

void renameCut({
required CutId cutId,
required String newName,
})

Expected behavior:

- duplicate Cut names remain allowed
- CutId identity is unchanged
- command is executed through HistoryManager
- undo/redo is recorded by HistoryManager

3. deleteCut

Purpose:

Create a DeleteCutCommand and execute it through HistoryManager.

Suggested signature direction:

void deleteCut({
required CutId cutId,
})

Expected behavior:

- if deleting the last remaining Cut, plan replacementCutId and replacementLayerId using the Phase 53 planner
- otherwise do not pass replacement IDs unless the existing DeleteCutCommand API requires them
- command is executed through HistoryManager
- activeCutId safety remains owned by DeleteCutCommand
- undo/redo is recorded by HistoryManager

4. duplicateCut

Purpose:

Plan IDs/maps with planDuplicateCutCommandInput, create a DuplicateCutCommand, and execute it through HistoryManager.

Suggested signature direction:

void duplicateCut({
required CutId sourceCutId,
required TrackId targetTrackId,
String? newName,
})

Expected behavior:

- finds the source Cut by CutId from the current Project
- plans new CutId, LayerId map, and FrameId map using the Phase 53 planner
- creates DuplicateCutCommand
- executes it through HistoryManager
- duplicate Cut becomes active through the command
- undo/redo is recorded by HistoryManager
- duplicate is still an independent copy, not a Linked Cut

Name policy for duplicate:

If newName is provided, use it.

If newName is not provided, use a compact deterministic default based on the source Cut name.

Recommended default:

[source name] Copy

Example:

Cut 1 Copy

Do not block duplicate Cut names.

Do not add name uniqueness enforcement.

Important constraints:

The coordinator must not duplicate command internals.

The coordinator must not mutate Project directly except through existing commands.

The coordinator must not call ProjectRepository mutation primitives directly unless there is no existing command for that action.

The coordinator must not own activeCutId logic.

The coordinator must not implement fallback rules itself except deciding whether replacement IDs are needed for last-Cut deletion.

The coordinator must not create its own undo/redo stack.

The coordinator must not persist anything.

ProjectRepository remains responsible for project data mutation.

EditingSessionState remains responsible for activeCutId.

HistoryManager remains responsible for undo/redo.

Cut commands remain responsible for command-specific mutation and undo/redo behavior.

Required tests:

Add tests for the new coordinator.

Recommended file:

test/services/commands/cut_command_coordinator_test.dart

If the existing test organization suggests a better nearby path, follow it.

Required test coverage:

1. createCut

Verify that createCut:

- creates a new Cut using first-available planned IDs
- inserts it into the target Track
- sets activeCutId to the new Cut
- records undo/redo through HistoryManager
- undo removes the created Cut and restores a valid activeCutId
- redo recreates the Cut and makes it active again

2. renameCut

Verify that renameCut:

- renames a Cut by CutId
- allows duplicate Cut names
- does not merge Cuts
- records undo/redo through HistoryManager
- undo restores the old name
- redo reapplies the new name

3. deleteCut

Verify that deleteCut:

- deletes the requested Cut
- preserves activeCutId safety
- records undo/redo through HistoryManager
- undo restores the deleted Cut
- redo deletes it again

Also verify last-Cut deletion:

- deleting the only Cut creates a replacement Cut
- replacement IDs are planned by the Phase 53 planner
- activeCutId points to the replacement
- undo restores the original Cut and removes the replacement
- redo recreates the replacement behavior

4. duplicateCut

Verify that duplicateCut:

- finds the source Cut by CutId
- creates a duplicate with a planned new CutId
- uses planned LayerId and FrameId maps
- inserts the duplicate into the target Track
- sets activeCutId to the duplicate
- records undo/redo through HistoryManager
- undo removes the duplicate and restores a valid activeCutId
- redo recreates the duplicate and makes it active again
- duplicate remains independent, not linked

Do not mechanically duplicate all Phase 51 deep-copy assertions.

Phase 54 should prove that the coordinator correctly wires the existing planner and command layer.

5. Error behavior

If source Cut is missing for duplicateCut, the coordinator should fail clearly.

Use the existing project style for missing entity behavior.

If the existing commands throw StateError, use StateError.

Do not silently no-op.

Do not add UI dialogs or user-facing error handling.

Export surface:

Update the command barrel if appropriate:

lib/src/services/commands/cut_commands.dart

It may export:

cut_command_coordinator.dart

and, if not already exported:

cut_command_input_planner.dart

Keep the export surface limited to command-related files.

If the barrel is updated, update export coverage tests.

Architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

ProjectRepository primitives must not manage:

- activeCutId
- undo/redo
- controller retargeting
- UI behavior

EditingSessionState owns activeCutId.

activeCutId is session state, not Project data.

HistoryManager owns undo/redo command history.

Undo/redo is volatile and must not be saved to project files.

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Cut rename must not block duplicate names.

Frame name/material policy must not be weakened.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Important analyzer rule:

Do not use const map literals with LayerId or FrameId keys.

Bad:

layerIdMap: const {LayerId('a'): LayerId('b')}
frameIdMap: const {FrameId('a'): FrameId('b')}

Good:

layerIdMap: {
const LayerId('a'): const LayerId('b'),
}

frameIdMap: {
const FrameId('a'): const FrameId('b'),
}

Reason:

LayerId and FrameId override == / hashCode, so Dart analyzer reports:

const_map_key_not_primitive_equality

Out of scope:

Do not implement any UI.

Specifically do not add:

- Cut management panel
- Cut switching UI
- Cut create/delete/rename/duplicate buttons
- menu commands
- keyboard shortcuts
- timeline integration
- controller retargeting UI behavior

Do not change existing command behavior.

Do not change command public APIs unless absolutely necessary.

Do not implement save/load changes.

Specifically do not add:

- JSON schema changes
- persisted undo/redo
- persisted command history
- persisted lastActiveCutId

Do not add:

- Provider
- Riverpod
- Bloc
- ChangeNotifier
- broad state-management framework changes

Do not implement:

- Cut reorder
- Linked Cut
- Linked Layer
- cross-cut linked frames
- project-level material pool
- Conte Panel
- Conte Layer
- Camera Layer
- Audio Layer

Do not replace hardcoded sample cuts in this phase.

Do not implement Phase 55 or later.

Expected changed files:

Likely changed files:

lib/src/services/commands/cut_command_coordinator.dart
test/services/commands/cut_command_coordinator_test.dart

Possibly changed files:

lib/src/services/commands/cut_commands.dart
test/services/commands/cut_commands_export_test.dart

Avoid touching unrelated files.

Required checks for Codex:

Because this is a code/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is command coordinator preparation only
- confirmation that no UI was added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no existing command behavior was changed
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 54 is complete when:

1. A Cut command coordinator/helper exists.
2. Coordinator createCut uses the Phase 53 planner and CreateCutCommand.
3. Coordinator renameCut uses RenameCutCommand.
4. Coordinator deleteCut uses DeleteCutCommand and plans last-Cut replacement IDs when needed.
5. Coordinator duplicateCut uses the Phase 53 planner and DuplicateCutCommand.
6. Coordinator executes commands through HistoryManager.
7. Coordinator does not mutate Project directly except through existing commands.
8. Coordinator does not own activeCutId fallback logic.
9. Coordinator does not add UI.
10. Existing command behavior is not changed.
11. No save/load or JSON schema behavior is changed.
12. Tests cover create, rename, delete, last-Cut delete, duplicate, undo, and redo through the coordinator.
13. dart format lib test completes.
14. flutter analyze passes.
15. flutter test passes.
16. git status is clean after commit.

Manual check guidance after merge:

No major Android Studio manual UI check is required because this phase should not add UI or visible runtime behavior.

After the PR is merged and local checks pass, optional manual check:

- app still launches
- existing drawing/timeline UI still appears
- existing Cut list/sample Cut behavior is not visibly broken
- no new Cut management UI appears
- no visible behavior changed