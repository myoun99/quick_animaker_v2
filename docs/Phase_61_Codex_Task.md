# Phase 61 Codex Task - Cut List Drag Reorder MVP

Create this file first:

docs/Phase_61_Codex_Task.md

Paste this full Phase 61 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_61_Codex_Task.md
git commit -m "Add Phase 61 Codex task"
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

Add a minimal drag reorder MVP for the existing Cut list.

This is the next small step toward future Premiere-Pro-like Conte / Storyboard editing, but this phase must not implement the full Conte Panel yet.

Current completed state:

- Phase 58 added ProjectRepository.reorderCut, ReorderCutCommand, and CutCommandCoordinator.reorderCut.
- Phase 59 added Move Cut Left / Move Cut Right buttons.
- Phase 60 extracted CutReorderPlanner for position lookup and target-index planning.

Phase 61 should add direct drag reorder behavior to the existing Cut list UI.

Do not add a full Cut management panel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add cross-track moves.

Scope:

Add drag reorder support inside the existing CutListBar.

The user should be able to reorder Cuts within the same Track by dragging Cut chips in the existing Cut list.

The implementation should still use CutCommandCoordinator.reorderCut.

Do not mutate repository data directly from widgets.

Do not construct ReorderCutCommand directly in widgets if CutCommandCoordinator can be used.

Do not duplicate repository reorder logic in UI.

Expected behavior:

1. Drag a Cut chip to reorder

Given Cuts:

- Cut 1
- Cut 2

Dragging Cut 2 before Cut 1 should reorder the list to:

- Cut 2
- Cut 1

Dragging Cut 1 after Cut 2 should reorder the list to:

- Cut 2
- Cut 1

2. activeCutId remains unchanged

If Cut 2 is active and the user drags Cut 2 before Cut 1:

- Cut 2 remains active
- CanvasView still targets Cut 2
- active Cut tooltip still points to Cut 2

If Cut 1 is active and the user drags Cut 1 after Cut 2:

- Cut 1 remains active
- CanvasView still targets Cut 1
- active Cut tooltip still points to Cut 1

3. Undo / Redo

Drag reorder must be undoable and redoable through the existing HistoryManager.

Expected:

- drag reorder records one undoable command
- Undo restores previous Cut order
- Redo reapplies dragged Cut order

4. Same-track only

Only reorder Cuts within the same Track.

Do not implement cross-track drag/drop.

5. No new panel

Do not add:

- Cut management panel
- Conte Panel
- Storyboard Panel
- Premiere-style full panel UI

This phase only enhances the existing Cut list.

Implementation guidance:

Likely files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart

Maybe tests:

test/ui/cut_list_bar_test.dart
test/widget_test.dart

Recommended API shape:

CutListBar may accept a callback such as:

void Function(CutId cutId, int newIndex)? onCutReordered

or:

void Function(int oldIndex, int newIndex)? onCutReordered

Prefer a callback that lets HomePage resolve the reorder through CutReorderPlanner and CutCommandCoordinator cleanly.

Suggested stable keys:

Existing Cut chip keys should remain:

cut-list-entry-<cutId>

If a drag handle is required, use a stable key:

cut-drag-handle-<cutId>

But preferred MVP:

- allow dragging the Cut chip itself
- do not add a separate visible drag handle unless required by the Flutter widget choice

If using ReorderableListView:

- keep layout compact
- keep horizontal scrolling behavior usable
- do not break the Phase 57 top toolbar scroll hardening
- use stable keys for each Cut item
- ensure action buttons remain visible or reachable
- ensure no default vertical full-screen list behavior disrupts the toolbar

If Flutter's ReorderableListView is too disruptive for the existing compact horizontal toolbar, use a smaller custom drag/drop approach, but keep the implementation simple.

Important reorder index semantics:

Use the current ProjectRepository.reorderCut / ReorderCutCommand semantics:

- newIndex is the final insertion position after removing the Cut from its old position
- moving A from index 0 to index 1 in A, B, C results in B, A, C
- moving B from index 1 to index 0 in A, B, C results in B, A, C

If a Flutter reorder callback reports indexes using different semantics, normalize them before calling CutCommandCoordinator.reorderCut.

Do not call reorder when oldIndex == newIndex.

Do not create a history entry for no-op drag.

HomePage responsibilities:

HomePage may:

- receive the drag reorder callback from CutListBar
- resolve the active/project state
- compute target index normalization if needed
- call CutCommandCoordinator.reorderCut
- refresh controllers after the command

HomePage must not:

- mutate ProjectRepository directly
- manage command internals
- change activeCutId for reorder
- implement cross-track moves

CutListBar responsibilities:

CutListBar may:

- render reorderable Cut chips
- emit reorder intent to HomePage
- keep existing action buttons
- keep existing selection behavior
- preserve compact UI

CutListBar must not:

- mutate ProjectRepository
- manage HistoryManager
- know about EditingSessionState
- know about CanvasController
- implement project-level logic

Existing UI must remain:

- New Cut button
- Rename Cut button
- Duplicate Cut button
- Move Cut Left button
- Move Cut Right button
- Delete Cut button
- Undo button
- Redo button

Existing behavior must remain:

- selecting a Cut works
- New Cut works
- Rename Cut works
- Duplicate Cut works
- Move Left works
- Move Right works
- Delete Cut works
- Undo / Redo works
- long Cut labels remain ellipsized
- top toolbar remains horizontally scrollable / stable

Required tests:

Add or update focused widget tests.

1. CutListBar exposes drag reorder callback

At the CutListBar unit/widget level:

- render at least two Cut entries
- simulate reorder if practical
- verify the callback receives the expected reorder intent

If direct drag simulation is too brittle in the isolated CutListBar test, at minimum test that the reorderable structure exists and app-level drag tests cover behavior.

2. App-level drag Cut 2 before Cut 1

In test/widget_test.dart:

- start app
- switch to Cut 2
- drag Cut 2 before Cut 1
- verify visual Cut order is Cut 2 then Cut 1
- verify active Cut remains Cut 2
- verify CanvasView cutId remains Cut 2
- Undo restores Cut 1 then Cut 2
- Redo reapplies Cut 2 then Cut 1

3. App-level drag Cut 1 after Cut 2

In test/widget_test.dart:

- start app
- active Cut 1
- drag Cut 1 after Cut 2
- verify visual Cut order is Cut 2 then Cut 1
- verify active Cut remains Cut 1
- verify CanvasView cutId remains Cut 1
- Undo restores Cut 1 then Cut 2
- Redo reapplies Cut 2 then Cut 1

4. No-op drag does not create undo entry

If practical:

- drag a Cut to its same position
- verify order unchanged
- verify undo state does not gain a new reorder entry

If hard to simulate reliably, cover this through a smaller callback normalization test.

5. Existing Move Left / Move Right tests remain meaningful

Do not remove or weaken Phase 59 tests.

6. Existing action buttons remain

Verify:

- New Cut
- Rename Cut
- Duplicate Cut
- Move Cut Left
- Move Cut Right
- Delete Cut

7. No future UI

Verify absence of:

- Cut management panel
- Conte Panel
- Storyboard Panel
- Linked Cut control
- Cross-track reorder UI

Testing style:

Prefer stable keys.

Avoid brittle pixel-perfect expectations.

Avoid overly long drag distances that depend on exact layout if a more stable test approach is possible.

Do not use warnIfMissed: false as the main fix.

Do not skip tests.

Do not remove edge disabled tests.

Do not remove existing reorder button tests.

Out of scope:

Do not add full Cut management panel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add Premiere-style panel UI yet.

Do not add cross-track Cut moves.

Do not add Linked Cut.

Do not add Linked Layer.

Do not add Cross-cut linked paste.

Do not add Project-level material pool.

Do not add Conte Layer.

Do not add Camera Layer.

Do not add Audio Layer.

Do not add keyboard shortcuts.

Do not add context menus.

Do not add confirmation dialogs.

Do not change save/load.

Do not change JSON schema.

Do not persist undo/redo.

Do not persist command history.

Do not persist lastActiveCutId.

Do not add Provider, Riverpod, Bloc, ChangeNotifier, or broad state-management changes.

Do not implement Phase 62 or later.

Architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

CutReorderPlanner must not mutate project data.

CutReorderPlanner must not manage undo/redo.

CutReorderPlanner must not know about UI.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is the entry point for executing reorder commands from UI.

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

Expected changed files:

Likely changed files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Possibly changed files:

lib/src/services/commands/cut_reorder_planner.dart
test/services/commands/cut_reorder_planner_test.dart

Avoid touching unrelated files.

Do not change repository/command behavior unless a clear bug is found.

Required checks for Codex:

Because this is a UI/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is Cut list drag reorder MVP only
- confirmation that no Cut management panel or Conte Panel was added
- confirmation that no Storyboard Panel was added
- confirmation that cross-track Cut move was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 61 is complete when:

1. Existing Cut list supports drag reorder within the same Track.
2. Drag reorder uses CutCommandCoordinator.reorderCut.
3. Drag reorder does not mutate repository directly from UI.
4. Dragging Cut 2 before Cut 1 works.
5. Dragging Cut 1 after Cut 2 works.
6. activeCutId remains unchanged and valid after drag reorder.
7. CanvasView remains targeted to the same active Cut after drag reorder.
8. Undo restores the previous Cut order.
9. Redo reapplies the dragged Cut order.
10. No-op drag does not create an unnecessary history entry, if practical to verify.
11. Existing Move Cut Left / Move Cut Right still work.
12. Existing New/Rename/Duplicate/Delete Cut actions still work.
13. Top toolbar remains usable.
14. Long Cut labels remain compact.
15. No Cut management panel is added.
16. No Conte Panel is added.
17. No Storyboard Panel is added.
18. No cross-track Cut move is added.
19. No save/load or JSON schema behavior is changed.
20. No broad state-management framework is introduced.
21. dart format lib test completes.
22. flutter analyze passes.
23. flutter test passes.
24. git status is clean after commit.

Manual check guidance after merge:

This phase changes visible behavior, so do an Android Studio manual check.

Check:

- app launches
- existing Cut list appears
- drag Cut 2 before Cut 1
- active Cut remains active after drag
- Undo restores order
- Redo reapplies order
- Move Cut Left still works
- Move Cut Right still works
- New Cut still works
- Rename Cut still works
- Duplicate Cut still works
- Delete Cut still works
- no full Cut management panel appears
- no Conte Panel appears
- no Storyboard Panel appears