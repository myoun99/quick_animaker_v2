# Phase 65 Codex Task - Cut Note Command Foundation

Create this file first:

docs/Phase_65_Codex_Task.md

Paste this full Phase 65 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Command foundation phase.

This is not a UI phase.

Goal:

Add an undoable command foundation for updating Cut-level note metadata.

Current state:

* CutMetadata exists.
* CutMetadata is note-only.
* actionMemo and dialogueMemo were removed from CutMetadata.
* actionMemo and dialogueMemo are reserved for future StoryboardPanel / ContePanel data.
* Cut has metadata.
* CutMetadata JSON round-trip works.
* old metadata JSON with actionMemo/dialogueMemo is ignored safely.
* Cut duplication preserves metadata.

Phase 65 should add command-layer support for changing CutMetadata.note through the existing command architecture.

Do not add UI.

Do not add Cut inspector.

Do not add metadata editor.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add StoryboardLayer.

Do not add StoryboardPanel.

Required command:

Add an undoable command for updating Cut note metadata.

Preferred command name:

UpdateCutNoteCommand

Suggested file:

lib/src/services/commands/update_cut_note_command.dart

Alternative name allowed only if existing project naming strongly suggests another convention.

Required behavior:

1. Command updates CutMetadata.note

Given:

* target CutId
* new note string

When executed:

* find the target Cut
* update cut.metadata.note to the new note
* preserve all other Cut fields
* preserve all Layer / Frame / Stroke data
* preserve CutId
* preserve Cut name
* preserve Cut duration
* preserve Cut canvasSize

2. Undo

Undo should restore the previous CutMetadata.

Not only previous note if the model grows later; storing previous CutMetadata is safer.

3. Redo

Redo should re-apply the new CutMetadata note.

4. activeCutId

Executing, undoing, and redoing this command must not change activeCutId.

5. Missing Cut

If the target CutId is missing, command execution should fail consistently with existing command style.

Follow the error style used by existing commands such as RenameCutCommand, DeleteCutCommand, or ReorderCutCommand.

Do not silently create a Cut.

Do not silently ignore missing Cut unless existing command style does so.

6. No-op policy

If the new note is the same as the current note, prefer no-op behavior where practical.

However, do not overcomplicate the command if the existing command architecture always records commands.

If a no-op is implemented:

* no project mutation
* ideally no history entry if handled at coordinator level

If no-op is not implemented:

* add a comment or test expectation consistent with existing command behavior

Preferred:

Coordinator should skip if note is unchanged.

Required coordinator integration:

Add a method to CutCommandCoordinator if that pattern exists.

Preferred method:

updateCutNote({
required CutId cutId,
required String note,
})

Behavior:

* resolve current Project
* if target Cut missing, follow existing error behavior
* if existing note equals new note, skip command and do not create a history entry
* otherwise execute UpdateCutNoteCommand through HistoryManager

Do not let UI mutate repository directly.

Repository support:

Use existing ProjectRepository methods if possible.

If a small repository helper is needed, add it carefully.

Preferred helper name:

updateCut

or

replaceCut

or

updateCutMetadata

Only add a helper if existing repository APIs cannot replace a Cut cleanly.

Do not add broad repository redesign.

Do not introduce activeCutId into ProjectRepository.

Testing requirements:

Add focused tests.

Likely files:

test/services/commands/update_cut_note_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart

Required tests:

1. Execute updates Cut note

Given a Project with one Cut with empty metadata.

Execute UpdateCutNoteCommand with note "General note".

Expected:

* target Cut metadata.note == "General note"
* other Cut fields unchanged
* activeCutId unchanged

2. Undo restores previous note

After execute:

* undo
* target Cut metadata returns to previous value
* activeCutId unchanged

3. Redo reapplies note

After undo:

* redo
* target Cut metadata.note == new note
* activeCutId unchanged

4. Existing non-empty note can be replaced

Given CutMetadata(note: "Old note")

Execute command with "New note"

Expected:

* metadata.note == "New note"
* undo restores "Old note"

5. Missing Cut behavior

Given missing CutId

Expected:

* command fails consistently with existing command style

6. Coordinator executes command

CutCommandCoordinator.updateCutNote should update note through HistoryManager.

Expected:

* note changes
* undoCount increases by 1
* undo/redo works

7. Coordinator skips unchanged note

Given current note is "Same note"

Call updateCutNote with "Same note"

Expected:

* note remains "Same note"
* undoCount does not increase
* activeCutId unchanged

8. Barrel export

If command barrel exists:

lib/src/services/commands/cut_commands.dart

Export UpdateCutNoteCommand.

Update export test.

Out of scope:

Do not add UI.

Do not add note editor UI.

Do not add Cut inspector.

Do not add metadata panel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add StoryboardLayer.

Do not add StoryboardPanel.

Do not add actionMemo.

Do not add dialogueMemo.

Do not add panelNote.

Do not add Cut status.

Do not add priority.

Do not add assignee.

Do not add dueDate.

Do not add retakeCount.

Do not add checkedBy.

Do not add Cut canvas size.

Do not add drawable area.

Do not add drawing area scale.

Do not add Project camera size.

Do not add camera/framing.

Do not add renderer changes.

Do not add tile engine changes.

Do not change save/load schema.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 66 or later.

Architecture rules:

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are future StoryboardPanel fields, not CutMetadata fields.

UpdateCutNoteCommand must not know about UI.

UpdateCutNoteCommand must not know about StoryboardPanel.

UpdateCutNoteCommand must not know about rendering.

UpdateCutNoteCommand must not know about canvas size.

UpdateCutNoteCommand must not know about drawable area.

UpdateCutNoteCommand must not know about camera/framing.

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the UI-facing command entry point.

CutId remains the true identity of a Cut.

Cut name remains a display label.

Duplicate Cut names remain allowed.

Cut reorder behavior must not change.

Cut duplication should preserve CutMetadata.

Frame name/material policy must not change.

Frame policy remains:

* Same frame name means same material within the same layer.
* Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
* Frame rename conflict offers Link / Cancel only.
* Rename-only should not be offered for frame rename conflicts.

Expected changed files:

Likely changed files:

lib/src/services/commands/update_cut_note_command.dart
lib/src/services/commands/cut_command_coordinator.dart
lib/src/services/commands/cut_commands.dart
test/services/commands/update_cut_note_command_test.dart
test/services/commands/cut_command_coordinator_test.dart
test/services/commands/cut_commands_export_test.dart

Possibly changed files:

lib/src/services/project_repository.dart
test/services/project_repository_test.dart

Avoid touching unrelated files.

Do not change UI files.

Do not change CutListBar.

Do not change HomePage.

Do not change CanvasView.

Do not change save/load code unless absolutely required by existing tests.

Required checks for Codex:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* command name
* coordinator method name
* confirmation that Cut note is updated through command/history
* confirmation that undo/redo works
* confirmation that activeCutId is unchanged
* confirmation that unchanged note is skipped without history entry if implemented
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added
* confirmation that no UI was added
* confirmation that no StoryboardLayer/StoryboardPanel was added
* confirmation that no Conte Panel or Storyboard Panel was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 65 is complete when:

1. UpdateCutNoteCommand or equivalent exists.
2. Command updates CutMetadata.note.
3. Command preserves all other Cut fields.
4. Command preserves Layer / Frame / Stroke content.
5. Command undo restores previous metadata.
6. Command redo reapplies new metadata.
7. activeCutId remains unchanged on execute/undo/redo.
8. Missing Cut behavior is tested.
9. CutCommandCoordinator has updateCutNote or equivalent method.
10. Coordinator executes the command through HistoryManager.
11. Coordinator skips unchanged note without creating history entry, if implemented.
12. Command is exported through the command barrel if applicable.
13. Focused tests are added.
14. Existing Cut commands still pass.
15. Existing Cut reorder tests still pass.
16. Existing Cut duplicate tests still pass.
17. CutMetadata remains note-only.
18. actionMemo is not re-added.
19. dialogueMemo is not re-added.
20. No UI is added.
21. No StoryboardLayer is added.
22. No StoryboardPanel is added.
23. No Conte Panel is added.
24. No Storyboard Panel is added.
25. No Cut canvas size is added.
26. No drawable area is added.
27. No broad state-management framework is introduced.
28. dart format lib test completes.
29. flutter analyze passes.
30. flutter test passes.
31. git status is clean after commit.

Manual check guidance after merge:

This phase should not change visible UI.

After merge, a short manual check is enough:

* app launches
* existing Cut list appears
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* Undo/Redo still work
* no metadata UI appears yet
* no Conte Panel appears
* no Storyboard Panel appears
