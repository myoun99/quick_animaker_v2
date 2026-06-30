# Phase 56 Codex Task - Rename Cut UI Dialog

Create this file first:

docs/Phase_56_Codex_Task.md

Paste this full Phase 56 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_56_Codex_Task.md
git commit -m "Add Phase 56 Codex task"
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

Small UI integration phase.

Goal:

Add a focused Rename Cut UI for the currently active Cut.

Phase 55 added compact Cut list actions for:

- New Cut
- Duplicate active Cut
- Delete active Cut

Phase 56 should add only Rename Cut UI.

Keep this phase small and focused.

Do not add Cut reorder.

Do not add a full Cut management panel.

Do not add Linked Cut.

Do not add save/load changes.

Do not add broad state management.

Scope:

Add a compact Rename Cut action to the existing Cut list UI.

When clicked, show a small dialog or popup that lets the user edit the active Cut display name.

Use CutCommandCoordinator.renameCut.

Do not construct RenameCutCommand directly in widgets if the coordinator can be used.

Do not add duplicate-name blocking.

Do not add Frame rename/linking behavior.

Cut rename is display-label-only.

Duplicate Cut names are allowed.

Primary implementation task:

Update the existing Cut list UI and HomePage integration, likely:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart

Expected UI behavior:

1. Rename Cut action

Add a compact icon button with Tooltip.

Suggested tooltip:

Rename Cut

Expected behavior:

- clicking Rename Cut opens a small dialog
- dialog is initialized with the active Cut name
- user can edit the text
- confirming applies the rename through CutCommandCoordinator.renameCut
- canceling closes without changes
- empty or whitespace-only input should not rename the Cut
- after rename, Cut list refreshes
- activeCutId remains unchanged and valid
- undo/redo is recorded through HistoryManager

2. Dialog text

Keep dialog text compact.

Suggested title:

Rename Cut

Suggested text field key if useful for tests:

rename-cut-text-field

Suggested confirm button text:

Rename

Suggested cancel button text:

Cancel

Do not add tutorial-like text.

Do not add long explanatory text.

3. Duplicate-name policy

Duplicate Cut names are allowed.

If the user renames a Cut to the same name as another Cut:

- allow it
- do not merge Cuts
- do not change CutIds
- do not show duplicate-name warning
- do not apply Frame material/link policy

Important:

Cut rename policy is different from Frame rename/material policy.

Cut name is only a display label.

Frame name/material policy must not be changed.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Integration rules:

Use CutCommandCoordinator.

Do not construct RenameCutCommand directly in widgets if the coordinator can be used.

Do not manually edit Project data from UI.

Do not make ProjectRepository own activeCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

If the existing HomePage uses setState/manual refresh patterns, follow that existing pattern.

After rename, trigger the minimal UI refresh needed by the existing architecture.

Do not redesign HomePage.

Do not redesign CutListBar.

Do not redesign controllers.

Undo/redo:

Rename must be recorded through HistoryManager.

Existing Undo/Redo buttons should undo/redo the rename.

Do not add a new undo/redo system.

Do not persist undo/redo.

Out of scope:

Do not add Cut reorder.

Do not add drag/drop.

Do not add Cut management panel.

Do not add Storyboard Panel.

Do not add Conte Panel.

Do not add Linked Cut.

Do not add Linked Layer.

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

Do not implement Phase 57 or later.

Required tests:

Add or update widget tests for Rename Cut UI.

Likely files:

test/ui/cut_list_bar_test.dart
test/widget_test.dart

Required test coverage:

1. Rename Cut button

Verify that:

- Rename Cut button is present with Tooltip
- button is compact and follows the existing Cut command action pattern
- callback is invoked in CutListBar unit/widget test if callbacks are tested there

2. Rename dialog opens

Verify that:

- tapping Rename Cut opens a dialog
- dialog title is Rename Cut
- text field is initialized with active Cut name
- Cancel closes the dialog without changing the Cut name

3. Confirm rename

Verify that:

- editing the text and confirming renames the active Cut
- Cut list updates
- activeCutId remains the same CutId
- Undo restores the previous Cut name
- Redo reapplies the new Cut name

4. Empty rename is ignored

Verify that:

- whitespace-only input does not rename the Cut
- dialog closes or remains open according to the simplest existing UI pattern
- no command is recorded if no rename occurs

Prefer closing the dialog without mutation for Phase 56, unless existing UI conventions suggest otherwise.

5. Duplicate Cut names are allowed

Verify that:

- renaming active Cut to another Cut's display name is allowed
- both Cuts remain present
- CutIds remain different
- no duplicate-name warning UI is shown

6. Existing actions remain

Verify that:

- New Cut button still exists
- Duplicate Cut button still exists
- Delete Cut button still exists
- existing Cut selection behavior still works
- existing drawing/timeline UI still appears

Testing style:

Prefer focused widget tests over golden tests.

Do not add screenshot/golden tests unless the project already uses them for this UI.

It is okay to find buttons by Tooltip text.

It is okay to use stable ValueKeys for the text field and buttons if helpful.

Expected changed files:

Likely changed files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Avoid touching unrelated files.

Required checks for Codex:

Because this is a code/UI/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is Rename Cut UI only
- confirmation that Cut reorder / Cut management panel were not added
- confirmation that duplicate Cut names remain allowed
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 56 is complete when:

1. Existing Cut list UI has compact Rename Cut action.
2. Rename Cut action opens a focused rename dialog.
3. Dialog initializes with the active Cut name.
4. Confirming rename uses CutCommandCoordinator.renameCut.
5. Canceling does not mutate the Cut.
6. Empty or whitespace-only input does not rename.
7. Duplicate Cut names are allowed.
8. Rename is undoable and redoable through existing HistoryManager.
9. Active Cut remains valid after rename, undo, and redo.
10. Existing New / Duplicate / Delete Cut actions still exist.
11. No Cut reorder is added.
12. No Cut management panel is added.
13. No save/load or JSON schema behavior is changed.
14. No broad state-management framework is introduced.
15. dart format lib test completes.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.

Manual check guidance after merge:

This phase adds visible UI, so do a small Android Studio manual check.

Check:

- app launches
- existing drawing/timeline UI still appears
- Cut list still appears
- New Cut / Duplicate Cut / Delete Cut still work
- Rename Cut button is visible as compact icon with Tooltip
- clicking Rename Cut opens dialog
- dialog starts with active Cut name
- Cancel closes without changes
- Rename applies the new display name
- duplicate Cut names are allowed
- Undo restores previous Cut name
- Redo reapplies new Cut name
- active Cut selection remains valid
- no Cut reorder UI appears
- no full Cut management panel appears
- no long tutorial text/status messages appear