# Phase 67 Codex Task - Cut Note UI Hardening

Create this file first:

docs/Phase_67_Codex_Task.md

Paste this full Phase 67 task document into that file.

Before implementing, read:

docs/Design_CutMetadata_CanvasPlanning.md

Repository:

myoun99/quick_animaker_v2

Base branch:

master

Project type:

Flutter / Dart

Phase type:

Small UI hardening phase.

Goal:

Harden the Cut Note UI introduced in Phase 66.

Current state:

* CutMetadata exists.
* CutMetadata is note-only.
* actionMemo and dialogueMemo are not CutMetadata fields.
* actionMemo and dialogueMemo are reserved for future StoryboardPanel / ContePanel data.
* UpdateCutNoteCommand exists.
* CutCommandCoordinator.updateCutNote exists.
* Edit Cut Note button exists.
* CutNoteDialog exists.
* Save / Cancel / Undo / Redo work.

Phase 67 should improve reliability and test coverage around the existing Cut Note UI.

Do not add new feature areas.

Do not add Cut Inspector.

Do not add StoryboardLayer.

Do not add StoryboardPanel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Required hardening targets:

1. Long note handling

The Cut Note dialog should remain usable with a long note.

Expected:

* text field supports multi-line input
* dialog does not overflow in normal desktop/window test layout
* Save and Cancel remain reachable

If needed, wrap dialog content in a constrained scrollable area.

Do not redesign the whole dialog.

2. Cut switching note correctness

When different Cuts have different notes:

* selecting Cut 1 and opening Edit Cut Note shows Cut 1 note
* selecting Cut 2 and opening Edit Cut Note shows Cut 2 note
* editing Cut 2 note must not change Cut 1 note
* Undo/Redo should affect the note change for the correct Cut

3. Active Cut safety

Edit Cut Note should always target the active Cut at the time the dialog was opened.

If the active Cut changes while the dialog is open, do not introduce a crash.

Preferred behavior:

* The dialog save applies to the CutId captured when the dialog opened.

This is already likely how HomePage behaves if activeCutId is captured before showDialog.

Add a test if practical.

4. Button reachability

The Edit Cut Note button should remain reachable in the top toolbar / Cut action row with the existing horizontal scroll behavior.

Do not remove the existing top toolbar scroll hardening.

Do not hide Undo / Redo.

Do not hide existing Cut actions.

5. Disabled / missing active Cut safety

If the active Cut is missing, the Edit Cut Note action should not crash.

Preferred:

* no-op safely

If button disabling is easy and consistent with existing action behavior, do it.

Do not introduce broad state management.

6. No future UI

Ensure no future UI appears:

* no actionMemo field
* no dialogueMemo field
* no Cut Inspector
* no metadata side panel
* no Conte Panel
* no Storyboard Panel
* no StoryboardLayer UI
* no StoryboardPanel UI

Testing requirements:

Add or update widget tests.

Likely files:

lib/src/ui/cut/cut_note_dialog.dart
lib/src/ui/home_page.dart
test/widget_test.dart
test/ui/cut_note_dialog_test.dart

Exact files may vary depending on current structure.

Required tests:

1. Long note dialog test

Open Edit Cut Note.

Enter a long multi-line note.

Expected:

* Save button is still reachable
* Save succeeds
* reopening dialog shows the full saved note or enough to confirm the note was saved exactly

Suggested note:

Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
Line 7
Line 8

2. Different Cuts keep separate notes

Given Cut 1 and Cut 2:

* edit Cut 1 note to "Cut 1 note"
* switch to Cut 2
* edit Cut 2 note to "Cut 2 note"
* reopen Cut 2 note and confirm "Cut 2 note"
* switch back to Cut 1
* reopen Cut 1 note and confirm "Cut 1 note"

3. Undo / Redo affects correct Cut note

After editing Cut 2 note:

* undo should restore Cut 2 previous note
* Cut 1 note should remain unchanged
* redo should reapply Cut 2 note
* activeCutId should remain stable

4. Dialog save targets captured CutId

If practical:

* open Cut 1 note dialog
* switch active Cut externally is probably hard through UI while modal is open
* if not practical, skip this test

If a direct state test is possible without overengineering, add it.

Do not create test-only production hooks.

5. Existing Cut actions still reachable

Verify:

* New Cut
* Rename Cut
* Edit Cut Note
* Duplicate Cut
* Move Cut Left
* Move Cut Right
* Delete Cut
* Undo
* Redo

are still findable/reachable according to existing test style.

6. No future UI

Verify the following are not present:

* actionMemo
* dialogueMemo
* Cut Inspector
* Metadata Panel
* Conte Panel
* Storyboard Panel
* StoryboardLayer
* StoryboardPanel

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

Do not implement Phase 68 or later.

Architecture rules:

UI must not mutate ProjectRepository directly.

UI should continue to call CutCommandCoordinator.updateCutNote.

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

lib/src/ui/cut/cut_note_dialog.dart
lib/src/ui/home_page.dart
test/widget_test.dart

Possibly changed files:

test/ui/cut_note_dialog_test.dart
test/ui/cut_list_bar_test.dart

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
* hardening summary
* confirmation that long notes remain usable
* confirmation that different Cuts keep separate notes
* confirmation that undo/redo affects the correct Cut note
* confirmation that activeCutId remains stable
* confirmation that existing Cut actions remain reachable
* confirmation that Cut note still updates through CutCommandCoordinator.updateCutNote
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

Phase 67 is complete when:

1. Long note editing remains usable.
2. Save and Cancel remain reachable with long notes.
3. Different Cuts can keep separate notes.
4. Editing Cut 2 note does not change Cut 1 note.
5. Undo restores the correct Cut note.
6. Redo reapplies the correct Cut note.
7. activeCutId remains stable.
8. Edit Cut Note action remains reachable.
9. Undo / Redo remain reachable.
10. Existing Cut create/rename/duplicate/delete/reorder actions remain reachable.
11. Cut note still updates through CutCommandCoordinator.updateCutNote.
12. CutMetadata remains note-only.
13. actionMemo is not added.
14. dialogueMemo is not added.
15. No Cut Inspector is added.
16. No StoryboardLayer is added.
17. No StoryboardPanel is added.
18. No Conte Panel is added.
19. No Storyboard Panel is added.
20. No Cut canvas size is added.
21. No drawable area is added.
22. No broad state-management framework is introduced.
23. Existing Cut create/rename/duplicate/delete/reorder UI still works.
24. dart format lib test completes.
25. flutter analyze passes.
26. flutter test passes.
27. git status is clean after commit.

Manual check guidance after merge:

After merge, manually check:

* app launches
* Edit Cut Note opens dialog
* long multi-line note can be typed
* Save closes dialog
* reopening dialog shows saved note
* Cut 1 and Cut 2 can have different notes
* Undo restores previous note
* Redo reapplies note
* Cancel does not change note
* Cut creation still works
* Cut rename still works
* Cut duplicate still works
* Cut delete still works
* Cut drag reorder still works
* no actionMemo field appears
* no dialogueMemo field appears
* no Conte Panel appears
* no Storyboard Panel appears
