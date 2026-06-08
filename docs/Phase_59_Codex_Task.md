# Phase 59 Codex Task - Cut Reorder Basic UI Actions

Create this file first:

docs/Phase_59_Codex_Task.md

Paste this full Phase 59 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_59_Codex_Task.md
git commit -m "Add Phase 59 Codex task"
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

Add basic Cut reorder UI actions using the Phase 58 reorder command foundation.

Phase 58 added:

- ProjectRepository.reorderCut
- ReorderCutCommand
- CutCommandCoordinator.reorderCut
- tests for repository / command / coordinator / export coverage

Phase 59 should expose this capability in the existing Cut list UI with compact Move Cut Left / Move Cut Right actions.

This is the first small user-facing step toward future Premiere-Pro-like Conte / Storyboard editing.

Do not implement the full Conte Panel yet.

Do not implement drag/drop yet.

Do not implement a full Cut management panel.

Scope:

Add two compact actions to the existing Cut list action row:

- Move Cut Left
- Move Cut Right

These actions should reorder the currently active Cut within its current Track.

Use CutCommandCoordinator.reorderCut.

Do not construct ReorderCutCommand directly in widgets if the coordinator can be used.

Do not duplicate repository reorder logic in UI.

Do not support cross-track moves in this phase.

Expected UI behavior:

1. Move Cut Left action

Add a compact icon button with Tooltip.

Suggested tooltip:

Move Cut Left

Expected behavior:

- moves the active Cut one position earlier within the same Track
- uses CutCommandCoordinator.reorderCut
- activeCutId remains unchanged
- Cut list refreshes
- undo/redo is recorded through HistoryManager
- if the active Cut is already the first Cut in its Track, the action should be disabled or should safely no-op according to the simplest existing UI pattern

Preferred behavior:

- disable the button when the active Cut is already first

2. Move Cut Right action

Add a compact icon button with Tooltip.

Suggested tooltip:

Move Cut Right

Expected behavior:

- moves the active Cut one position later within the same Track
- uses CutCommandCoordinator.reorderCut
- activeCutId remains unchanged
- Cut list refreshes
- undo/redo is recorded through HistoryManager
- if the active Cut is already the last Cut in its Track, the action should be disabled or should safely no-op according to the simplest existing UI pattern

Preferred behavior:

- disable the button when the active Cut is already last

3. Existing Cut actions remain

The existing compact Cut actions must remain:

- New Cut
- Rename Cut
- Duplicate Cut
- Delete Cut

4. Existing Undo / Redo remain

The existing Undo and Redo buttons must remain reachable.

Phase 57 added top-row hardening. Do not undo that hardening.

5. No drag/drop yet

Do not add drag/drop reorder.

Do not add reorder handles.

Do not add long-press behavior.

Do not add context menus.

Implementation guidance:

Likely files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart

Use the existing CutListBar callback pattern.

Suggested new CutListBar callbacks:

- onMoveActiveCutLeft
- onMoveActiveCutRight

Suggested button keys:

- move-cut-left-button
- move-cut-right-button

Suggested tooltips:

- Move Cut Left
- Move Cut Right

Suggested icons:

- Icons.chevron_left
- Icons.chevron_right

Use whatever Material icons fit the existing project style.

HomePage should determine:

- the active Cut's TrackId
- the active Cut's current index within that Track
- whether Move Left / Move Right should be enabled
- the target index for reorder

Important:

Do not put ID planning or repository mutation into UI.

The UI may compute the active Cut index and target index because this is view/action enablement and command input selection.

The actual mutation must go through CutCommandCoordinator.reorderCut.

Recommended HomePage behavior:

- if active Cut index > 0, Move Left target index is activeIndex - 1
- if active Cut index < cuts.length - 1, Move Right target index is activeIndex + 1
- after reorder, call the same minimal refresh path used by other Cut commands
- active Cut remains selected because activeCutId does not change

If active Cut cannot be resolved:

- fail clearly using existing project style
- do not silently mutate the project

Important reorder index semantics:

Use Phase 58 semantics:

- newIndex is the final insertion position after removing the Cut from its old position
- moving A from index 0 to index 1 in A, B, C results in B, A, C
- moving B from index 1 to index 0 in A, B, C results in B, A, C

Do not implement cross-track moves.

Do not clamp invalid indexes in UI.

Avoid calling reorder when the active Cut is already at the edge.

Undo/redo behavior:

Move Left and Move Right must be undoable and redoable through existing HistoryManager.

Do not add a new undo/redo system.

Do not persist undo/redo.

Out of scope:

Do not add drag/drop.

Do not add Cut reorder handles.

Do not add a Cut management panel.

Do not add Storyboard Panel.

Do not add Conte Panel.

Do not add Premiere-style panel UI yet.

Do not add keyboard shortcuts.

Do not add context menus.

Do not add confirmation dialogs.

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

Do not implement Phase 60 or later.

Required tests:

Add or update focused widget tests.

Likely files:

test/ui/cut_list_bar_test.dart
test/widget_test.dart

Required test coverage:

1. CutListBar renders move buttons when callbacks are provided

Verify:

- Move Cut Left tooltip exists
- Move Cut Right tooltip exists
- move-cut-left-button key exists
- move-cut-right-button key exists
- tapping each invokes the provided callback

2. Move Left action reorders active Cut

Using the app-level widget test:

- start with at least two Cuts
- switch active Cut to the second Cut
- tap Move Cut Left
- verify the second Cut moved before the first Cut
- verify active Cut remains the same CutId
- verify active tooltip/name still points to the moved Cut
- verify Undo restores the original order
- verify Redo reapplies the moved order

3. Move Right action reorders active Cut

Using the app-level widget test:

- start with at least two Cuts
- active Cut starts as the first Cut or switch to the first Cut
- tap Move Cut Right
- verify the active Cut moved after the next Cut
- verify active Cut remains the same CutId
- verify Undo restores original order
- verify Redo reapplies the moved order

4. Edge behavior

Verify:

- Move Cut Left is disabled when active Cut is first
- Move Cut Right is disabled when active Cut is last

If the final implementation chooses no-op instead of disabled, document the reason and test the no-op behavior.

Preferred behavior is disabled.

5. Existing actions still exist

Verify:

- New Cut still exists
- Rename Cut still exists
- Duplicate Cut still exists
- Delete Cut still exists
- Undo / Redo remain reachable

6. No future UI

Verify absence of:

- drag/drop reorder handle
- Cut management panel
- Conte Panel
- Linked Cut control

Testing style:

Prefer finding buttons by stable ValueKeys or Tooltip text.

Do not use golden tests unless the project already uses them.

Do not use warnIfMissed: false as the main fix.

Ensure move buttons are actually tappable.

Keep tests focused and stable.

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

Expected changed files:

Likely changed files:

lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Avoid touching unrelated files.

Do not change command/repository behavior unless a bug is found in the Phase 58 reorder implementation.

Required checks for Codex:

Because this is a UI/test phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is basic Cut reorder UI only
- confirmation that no drag/drop was added
- confirmation that no Cut management panel or Conte Panel was added
- confirmation that cross-track Cut move was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 59 is complete when:

1. Existing Cut list UI has compact Move Cut Left action.
2. Existing Cut list UI has compact Move Cut Right action.
3. Move Left uses CutCommandCoordinator.reorderCut.
4. Move Right uses CutCommandCoordinator.reorderCut.
5. Move Left moves the active Cut one position earlier in the same Track.
6. Move Right moves the active Cut one position later in the same Track.
7. activeCutId remains unchanged and valid after move.
8. Undo restores the previous Cut order.
9. Redo reapplies the moved Cut order.
10. Move Left is disabled or safe when active Cut is already first.
11. Move Right is disabled or safe when active Cut is already last.
12. New / Rename / Duplicate / Delete Cut actions still exist.
13. Undo / Redo remain reachable.
14. No drag/drop is added.
15. No Cut management panel or Conte Panel is added.
16. No cross-track Cut move is added.
17. No save/load or JSON schema behavior is changed.
18. No broad state-management framework is introduced.
19. dart format lib test completes.
20. flutter analyze passes.
21. flutter test passes.
22. git status is clean after commit.

Manual check guidance after merge:

This phase adds visible UI, so do a small Android Studio manual check.

Check:

- app launches
- existing drawing/timeline UI still appears
- Cut list still appears
- New / Rename / Duplicate / Delete still work
- Move Cut Left button is visible or reachable
- Move Cut Right button is visible or reachable
- Move Cut Left is disabled or harmless when active Cut is first
- Move Cut Right is disabled or harmless when active Cut is last
- selecting Cut 2 and moving left changes order while keeping Cut 2 active
- moving active Cut right changes order while keeping the same Cut active
- Undo restores the previous order
- Redo reapplies the order change
- no drag/drop reorder UI appears
- no full Cut management panel appears
- no Conte Panel appears yet