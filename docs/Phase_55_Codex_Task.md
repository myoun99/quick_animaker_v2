# Phase 55 Codex Task - Cut List Basic Command Actions MVP

Create this file first:

docs/Phase_55_Codex_Task.md

Paste this full Phase 55 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_55_Codex_Task.md
git commit -m "Add Phase 55 Codex task"
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

Add the first minimal Cut command actions to the existing Cut list UI.

Previous phases prepared the Cut command layer:

- Cut command implementations exist.
- Cut command contract tests exist.
- Cut command barrel export exists.
- Cut command input planner exists.
- CutCommandCoordinator exists.

Phase 55 should use that preparation to add a small production-tool-like UI MVP for basic Cut operations.

Scope:

Add icon actions to the existing Cut list UI for:

- New Cut
- Duplicate active Cut
- Delete active Cut

Do not add Rename Cut in this phase.

Rename requires text input UI/dialog behavior and should be handled in a later dedicated phase.

Do not add a full Cut management panel.

Do not add Storyboard/Conte Panel.

Do not add Cut reorder.

Do not add Linked Cut.

Do not add Linked Layer.

Do not add save/load changes.

Do not add broad state management.

Primary implementation task:

Update the existing Cut list UI, likely:

lib/src/ui/cut/cut_list_bar.dart

and its integration point, likely:

lib/src/ui/home_page.dart

Use the existing CutCommandCoordinator from Phase 54.

Expected UI behavior:

1. New Cut action

Add a compact icon button with Tooltip.

Suggested tooltip:

New Cut

Expected behavior:

- clicking New Cut creates a new Cut in the current/primary Track
- the new Cut becomes active through existing command behavior
- undo/redo is recorded through HistoryManager
- the Cut list updates after the command
- no text dialog is shown
- default name can be the coordinator default or a compact project-consistent name

2. Duplicate active Cut action

Add a compact icon button with Tooltip.

Suggested tooltip:

Duplicate Cut

Expected behavior:

- clicking Duplicate Cut duplicates the currently active Cut
- the duplicate is independent, not linked
- the duplicate becomes active through existing command behavior
- undo/redo is recorded through HistoryManager
- the Cut list updates after the command
- no text dialog is shown
- default duplicate name should come from CutCommandCoordinator behavior

3. Delete active Cut action

Add a compact icon button with Tooltip.

Suggested tooltip:

Delete Cut

Expected behavior:

- clicking Delete Cut deletes the currently active Cut
- deleting the last Cut is allowed
- if deleting the last Cut, a replacement Cut is created by existing command/coordinator behavior
- activeCutId remains valid
- undo/redo is recorded through HistoryManager
- the Cut list updates after the command

For Phase 55, do not add a confirmation dialog.

The goal is to verify command wiring first.

A confirmation dialog can be added later if needed.

UI style requirements:

- Keep the UI compact.
- Prefer icon buttons with Tooltip labels.
- Do not add long tutorial-like text.
- Do not add verbose status messages.
- Do not add large labels unless the existing CutListBar pattern already requires them.
- The UI should feel like a production tool, not a tutorial.

Important integration rules:

Use CutCommandCoordinator.

Do not construct CreateCutCommand, DeleteCutCommand, or DuplicateCutCommand directly in widgets if the coordinator can be used.

Do not duplicate ID planning logic in UI.

Do not duplicate last-Cut replacement logic in UI.

Do not make ProjectRepository own activeCutId.

Do not make widgets manually edit Project data.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

If the existing HomePage currently uses setState/manual state refresh patterns, follow the existing local pattern.

Keep the integration small.

After running a coordinator action, trigger the minimal UI refresh needed by the existing architecture.

Do not redesign HomePage.

Do not redesign CutListBar.

Do not redesign controllers.

Important behavior rules:

CutId is the true identity of a Cut.

Cut name is only a display label.

Duplicate Cut names are allowed.

Cut duplicate creates an independent copy in this phase.

Do not implement Linked Cut.

Do not enforce unique Cut names.

Do not add duplicate-name warning UI in this phase.

Frame name/material policy must not be changed.

Frame policy remains:

- Same frame name means same material within the same layer.
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Frame rename conflict offers Link / Cancel only.
- Rename-only should not be offered for frame rename conflicts.

Required tests:

Add or update widget tests for the Cut list UI.

Likely files:

test/ui/cut_list_bar_test.dart
test/widget_test.dart

Add service/widget integration tests where appropriate.

Required test coverage:

1. New Cut button

Verify that:

- New Cut button is present with Tooltip
- tapping it creates a new Cut
- activeCutId becomes the new Cut
- Cut list updates
- no unrelated UI changes are introduced

2. Duplicate Cut button

Verify that:

- Duplicate Cut button is present with Tooltip
- tapping it duplicates the active Cut
- duplicate Cut appears in the Cut list
- duplicate Cut becomes active
- duplicate uses a new CutId
- source Cut remains present
- this is independent duplicate behavior, not Linked Cut behavior

Do not repeat all deep-copy tests from previous phases.

The goal here is UI command wiring.

3. Delete Cut button

Verify that:

- Delete Cut button is present with Tooltip
- tapping it deletes the active Cut
- activeCutId remains valid
- Cut list updates
- deleting the last Cut leaves one replacement Cut
- the app does not reach zero Cuts

4. No Rename UI yet

Verify that Phase 55 does not add Rename Cut UI.

If there are existing rename features elsewhere, do not remove them.

This acceptance criterion only means do not add a new Cut rename UI in this phase.

5. Existing UI still present

Verify that:

- existing drawing/timeline UI still appears
- existing Cut list still appears
- existing Cut selection behavior still works

Testing style:

Prefer focused tests over broad golden tests.

Do not add screenshot/golden tests unless the project already uses them for this UI.

Keep tests stable and not dependent on exact icon glyph rendering if possible.

It is okay to find buttons by Tooltip text.

Out of scope:

Do not add Rename Cut UI.

Do not add text input dialogs.

Do not add confirmation dialogs.

Do not add Cut management panel.

Do not add Cut reorder.

Do not add drag/drop.

Do not add Linked Cut.

Do not add Linked Layer.

Do not add Cross-cut linked paste.

Do not add Project-level material pool.

Do not add Storyboard Panel.

Do not add Conte Panel.

Do not add Conte Layer.

Do not add Camera Layer.

Do not add Audio Layer.

Do not change save/load.

Do not change JSON schema.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId in this phase.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 56 or later.

Expected changed files:

Likely changed files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Possibly changed files:

lib/src/services/commands/cut_commands.dart
test/services/commands/cut_commands_export_test.dart

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
- confirmation that this is basic Cut list command UI only
- confirmation that Rename Cut UI was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 55 is complete when:

1. Existing Cut list UI has compact New Cut action.
2. Existing Cut list UI has compact Duplicate Cut action.
3. Existing Cut list UI has compact Delete Cut action.
4. Actions use CutCommandCoordinator.
5. UI does not duplicate command construction or ID planning logic.
6. New Cut action creates a Cut and makes it active.
7. Duplicate Cut action duplicates the active Cut and makes the duplicate active.
8. Delete Cut action deletes the active Cut and leaves activeCutId valid.
9. Deleting the last Cut leaves one replacement Cut.
10. Cut list refreshes after each action.
11. No Rename Cut UI is added.
12. No save/load or JSON schema behavior is changed.
13. No broad state-management framework is introduced.
14. dart format lib test completes.
15. flutter analyze passes.
16. flutter test passes.
17. git status is clean after commit.

Manual check guidance after merge:

This phase adds visible UI, so do a small Android Studio manual check.

Check:

- app launches
- existing drawing/timeline UI still appears
- Cut list still appears
- New Cut button is visible as compact icon with Tooltip
- Duplicate Cut button is visible as compact icon with Tooltip
- Delete Cut button is visible as compact icon with Tooltip
- clicking New Cut adds a Cut and selects it
- clicking Duplicate Cut duplicates the active Cut and selects the duplicate
- clicking Delete Cut removes the active Cut and selects a valid fallback/replacement
- deleting the last Cut does not leave the app with zero Cuts
- no Rename Cut UI appears yet
- no new long tutorial text/status messages appear