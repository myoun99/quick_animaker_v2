# Phase 57 Codex Task - Cut List Action UI Hardening

Create this file first:

docs/Phase_57_Codex_Task.md

Paste this full Phase 57 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_57_Codex_Task.md
git commit -m "Add Phase 57 Codex task"
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

Small UI/test hardening phase.

Goal:

Harden the Cut list action UI after Phase 55 and Phase 56 added visible Cut command buttons.

Current Cut list actions:

- New Cut
- Rename Cut
- Duplicate Cut
- Delete Cut

Phase 56 and the follow-up test fix showed that the top toolbar can become too wide for the default 800x600 widget test viewport.

Phase 57 should make the Cut list action row and related tests more robust before adding more Cut-related features.

This is a hardening phase.

Do not add new product features.

Do not add Cut reorder.

Do not add a full Cut management panel.

Do not add keyboard shortcuts yet.

Do not add save/load changes.

Scope:

Improve the existing Cut list action UI and tests so that:

- New / Rename / Duplicate / Delete remain visible and usable
- Undo / Redo remain reachable in widget tests and normal small-width layouts
- the top row does not rely on accidental overflow behavior
- widget tests do not need fragile off-screen taps when avoidable
- the UI remains compact and production-tool-like

Primary implementation task:

Inspect and harden the top row layout in:

lib/src/ui/home_page.dart

and the Cut list bar layout in:

lib/src/ui/cut/cut_list_bar.dart

Use the smallest reasonable layout adjustment.

Recommended direction:

- Keep CutListBar compact.
- Keep icon buttons compact.
- If the existing parent row can overflow horizontally, wrap the relevant top-row controls in a horizontal scroll view or another small layout container consistent with the current UI.
- Prefer preserving the existing visual style.
- Do not redesign HomePage.
- Do not redesign CutListBar.
- Do not move Cut actions into a new full panel.
- Do not create a new management toolbar class unless the existing code clearly benefits from a small private helper widget.

Important:

Phase 57 is not about adding features.

It is about making the Phase 55/56 UI stable and testable.

Expected UI behavior:

1. Cut list actions remain available

The existing compact actions must still be present:

- New Cut
- Rename Cut
- Duplicate Cut
- Delete Cut

2. Undo / Redo remain available

The existing Undo and Redo buttons must still be present.

They should be reachable even after adding the Cut action buttons.

3. No new Cut features

Do not add:

- Cut reorder
- Cut drag/drop
- Cut management panel
- Cut context menu
- keyboard shortcuts
- confirmation dialogs
- linked cut controls

4. No behavior changes

Existing behavior must remain:

- New Cut creates and activates a Cut.
- Rename Cut opens dialog and renames the active Cut.
- Duplicate Cut duplicates and activates the active Cut.
- Delete Cut deletes the active Cut and keeps activeCutId valid.
- Deleting the last Cut leaves a replacement Cut.
- Duplicate Cut names are allowed.
- Undo/Redo continue to work.

Testing requirements:

Update tests to cover the hardened layout behavior.

Likely files:

test/ui/cut_list_bar_test.dart
test/widget_test.dart

Required test coverage:

1. Cut action buttons remain present

Verify:

- New Cut tooltip exists
- Rename Cut tooltip exists
- Duplicate Cut tooltip exists
- Delete Cut tooltip exists

2. Undo / Redo reachable at default test viewport

Add or strengthen a test proving that Undo and Redo can be reached and tapped after the Cut action buttons are present.

This should not rely on missed taps.

Do not use warnIfMissed: false as the main fix.

The tap must actually execute the command.

3. Existing undo/redo smoke test remains meaningful

The existing test:

undo and redo smoke after cut switching keeps Cut 2 active

should keep proving that:

- after switching to Cut 2
- creating a frame
- undo removes the frame marker from Cut 2
- redo restores the frame marker in Cut 2
- Cut 2 remains active

The test may use a helper that ensures the Undo/Redo buttons are visible before tapping.

4. Rename undo/redo test remains meaningful

The Rename Cut undo/redo test should still prove that:

- rename applies
- undo restores old Cut name
- redo reapplies new Cut name

5. No new UI features

Verify that the following are still absent:

- Cut reorder UI
- Cut management panel
- Linked Cut control

Use stable tooltip/key/text checks where practical.

Testing style:

Prefer focused widget tests.

Do not add golden tests unless the project already uses them.

Avoid brittle pixel-perfect expectations.

Avoid hiding real tap failures with warnIfMissed: false.

If a helper is needed for top bar text buttons, keep it narrowly named and documented by test usage.

Out of scope:

Do not add new product features.

Do not add Cut reorder.

Do not add drag/drop.

Do not add Cut management panel.

Do not add context menus.

Do not add keyboard shortcuts.

Do not add confirmation dialogs.

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

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 58 or later.

Expected changed files:

Likely changed files:

lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Possibly changed files:

none

Avoid touching unrelated files.

Required checks for Codex:

Because this is a UI/test hardening phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- root cause or hardening target
- confirmation that no new product feature was added
- confirmation that Cut reorder / Cut management panel were not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 57 is complete when:

1. Cut list action UI remains compact.
2. New Cut action remains available.
3. Rename Cut action remains available.
4. Duplicate Cut action remains available.
5. Delete Cut action remains available.
6. Undo and Redo remain reachable in the default widget test viewport.
7. Widget tests no longer fail because Undo/Redo are off-screen.
8. Existing Cut action behavior remains unchanged.
9. Existing Rename Cut behavior remains unchanged.
10. No Cut reorder is added.
11. No full Cut management panel is added.
12. No save/load or JSON schema behavior is changed.
13. No broad state-management framework is introduced.
14. dart format lib test completes.
15. flutter analyze passes.
16. flutter test passes.
17. git status is clean after commit.

Manual check guidance after merge:

This phase touches visible layout, so do a small Android Studio manual check.

Check:

- app launches
- existing drawing/timeline UI still appears
- Cut list still appears
- New Cut / Rename Cut / Duplicate Cut / Delete Cut are visible or reachable
- Undo / Redo remain visible or reachable
- New Cut still works
- Rename Cut still works
- Duplicate Cut still works
- Delete Cut still works
- Undo / Redo still work after Cut actions
- no Cut reorder UI appears
- no full Cut management panel appears
- no long tutorial text/status messages appear