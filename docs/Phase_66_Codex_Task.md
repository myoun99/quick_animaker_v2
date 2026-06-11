# Phase 66 Codex Task - Cut Note UI Dialog

Create this file first:

docs/Phase_66_Codex_Task.md

Paste this full Phase 66 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Small UI wiring phase.

Goal:

Add a minimal UI dialog for editing Cut-level note metadata.

Current state:

* CutMetadata exists.
* CutMetadata is note-only.
* actionMemo and dialogueMemo are not CutMetadata fields.
* actionMemo and dialogueMemo are reserved for future StoryboardPanel / ContePanel data.
* UpdateCutNoteCommand exists.
* CutCommandCoordinator.updateCutNote exists.
* Undo/redo command behavior exists for Cut note changes.

Phase 66 should add a small UI entry point for editing the selected Cut's note.

This is not a Cut Inspector phase.

This is not a metadata panel phase.

This is not a Conte Panel phase.

This is not a Storyboard Panel phase.

Required behavior:

1. Add a Cut Note action to existing Cut list controls

Add a small action button for the active / selected Cut.

Preferred label / tooltip:

* Edit Cut Note

Suggested key:

* edit-cut-note-button

The button should be placed near existing Cut actions such as rename / duplicate / delete if practical.

Do not redesign the Cut list.

Do not create a new panel.

Do not create a persistent inspector.

2. Open a simple dialog

When the user clicks Edit Cut Note:

* open a dialog
* show the current active Cut note
* allow editing a multi-line text field
* provide Save and Cancel actions

Suggested dialog title:

* Edit Cut Note

Suggested text field key:

* cut-note-text-field

Suggested Save button key:

* save-cut-note-button

Suggested Cancel button key:

* cancel-cut-note-button

3. Save behavior

When Save is clicked:

* call CutCommandCoordinator.updateCutNote(...)
* close the dialog

If note is unchanged:

* coordinator should skip history entry
* dialog may still close

4. Cancel behavior

When Cancel is clicked:

* close dialog
* do not call updateCutNote
* do not change note
* do not create history entry

5. activeCutId behavior

Editing note should not change activeCutId.

Undo/redo of note changes should not change activeCutId.

6. Missing active Cut

If there is no active Cut or the active Cut is missing:

* disable the Edit Cut Note button if practical
* or do nothing safely

Do not crash the app.

7. Note-only rule

The UI must edit only:

* CutMetadata.note

Do not add:

* actionMemo
* dialogueMemo
* panelNote
* storyboard text fields

8. Undo / Redo

Because the UI uses CutCommandCoordinator.updateCutNote, existing Undo / Redo buttons should work.

No new undo/redo system should be added.

Testing requirements:

Add widget tests.

Likely files:

lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart
test/widget_test.dart
test/ui/cut_list_bar_test.dart

Exact files may vary depending on current UI structure.

Required tests:

1. Edit Cut Note button appears

Given an active Cut:

* Edit Cut Note button is visible
* key edit-cut-note-button exists

2. Dialog opens with current note

Given active Cut has metadata.note = "Old note"

Click Edit Cut Note

Expected:

* dialog title Edit Cut Note appears
* text field contains "Old note"

3. Save updates note through command/history

Open dialog

Change note to "New note"

Click Save

Expected:

* dialog closes
* active Cut metadata.note == "New note"
* undoCount increases by 1
* activeCutId unchanged

4. Undo restores previous note

After saving "New note":

* press Undo or call historyManager.undo in test if UI test already uses history manager helpers
* active Cut metadata.note == "Old note"
* activeCutId unchanged

5. Redo reapplies note

After undo:

* press Redo or call historyManager.redo
* active Cut metadata.note == "New note"
* activeCutId unchanged

6. Cancel does not change note

Open dialog

Change text

Click Cancel

Expected:

* dialog closes
* Cut metadata.note unchanged
* undoCount unchanged
* activeCutId unchanged

7. Saving unchanged note does not create history entry

Open dialog with note "Same note"

Click Save without changing text

Expected:

* dialog closes
* note unchanged
* undoCount does not increase

8. No future UI

Verify the following are not present:

* Storyboard Panel
* Conte Panel
* StoryboardLayer UI
* actionMemo field
* dialogueMemo field

Out of scope:

Do not add Cut Inspector.

Do not add metadata side panel.

Do not add persistent note panel.

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

Do not implement Phase 67 or later.

Architecture rules:

UI must not mutate ProjectRepository directly.

UI should call CutCommandCoordinator.updateCutNote.

CutMetadata is Cut-level metadata only.

CutMetadata.note is a general Cut-level note.

actionMemo and dialogueMemo are future StoryboardPanel fields, not CutMetadata fields.

Cut Note UI must not know about StoryboardPanel.

Cut Note UI must not know about renderer.

Cut Note UI must not know about canvas size.

Cut Note UI must not know about drawable area.

Cut Note UI must not know about camera/framing.

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

lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart
test/widget_test.dart
test/ui/cut_list_bar_test.dart

Possibly changed files:

lib/src/ui/cut/cut_note_dialog.dart
test/ui/cut_note_dialog_test.dart

Avoid touching unrelated files.

Do not change command behavior unless tests reveal a small bug.

Do not change save/load code.

Do not change renderer/canvas code.

Required checks for Codex:

Run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

* changed files
* UI entry point added
* dialog behavior summary
* confirmation that Cut note updates through CutCommandCoordinator.updateCutNote
* confirmation that undo/redo works
* confirmation that activeCutId is unchanged
* confirmation that unchanged note is skipped without history entry
* confirmation that CutMetadata remains note-only
* confirmation that actionMemo/dialogueMemo were not added
* confirmation that no Cut Inspector was added
* confirmation that no StoryboardLayer/StoryboardPanel was added
* confirmation that no Conte Panel or Storyboard Panel was added
* confirmation that no Cut canvas size or drawable area was added
* confirmation that no broad state-management framework was added
* analyze result
* test result
* git status summary

Acceptance criteria:

Phase 66 is complete when:

1. Edit Cut Note button exists.
2. Button has a stable key.
3. Button opens a dialog.
4. Dialog shows current Cut note.
5. Dialog has a multi-line note text field.
6. Dialog has Save.
7. Dialog has Cancel.
8. Save updates CutMetadata.note through CutCommandCoordinator.updateCutNote.
9. Save closes the dialog.
10. Cancel closes the dialog.
11. Cancel does not change note.
12. Cancel does not create history entry.
13. Saving unchanged note does not create history entry.
14. Undo restores previous note.
15. Redo reapplies new note.
16. activeCutId remains unchanged.
17. CutMetadata remains note-only.
18. actionMemo is not added.
19. dialogueMemo is not added.
20. No Cut Inspector is added.
21. No StoryboardLayer is added.
22. No StoryboardPanel is added.
23. No Conte Panel is added.
24. No Storyboard Panel is added.
25. No Cut canvas size is added.
26. No drawable area is added.
27. No broad state-management framework is introduced.
28. Existing Cut create/rename/duplicate/delete/reorder UI still works.
29. dart format lib test completes.
30. flutter analyze passes.
31. flutter test passes.
32. git status is clean after commit.

Manual check guidance after merge:

After merge, manually check:

* app launches
* existing Cut list appears
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* Edit Cut Note opens dialog
* Save note closes dialog
* Undo restores previous note
* Redo reapplies note
* Cancel does not change note
* no actionMemo field appears
* no dialogueMemo field appears
* no Conte Panel appears
* no Storyboard Panel appears
