# Phase 62 Codex Task - Cut Drag Reorder Hardening

Create this file first:

docs/Phase_62_Codex_Task.md

Paste this full Phase 62 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_62_Codex_Task.md
git commit -m "Add Phase 62 Codex task"
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

UI behavior hardening / contract test phase.

This is not a new feature phase.

Goal:

Harden the Phase 61 Cut list drag reorder MVP.

Phase 61 added drag reorder inside the existing CutListBar using Draggable / DragTarget and routed reorder through CutCommandCoordinator.reorderCut.

Phase 62 should strengthen the drag reorder contract so future multi-track projects, larger Cut lists, and future Conte / Storyboard UI work do not break the current behavior.

Do not add new user-facing features.

Do not add a Cut management panel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not implement cross-track moves.

Scope:

Improve and test the existing Cut drag reorder behavior.

Focus on:

- no-op drag behavior
- cross-track drop ignored behavior
- same-track multi-cut reorder behavior
- history entry prevention for ignored/no-op drops
- active Cut retention
- avoiding accidental selection during drag if currently present
- preserving existing Move Left / Move Right behavior
- preserving existing Cut actions

Do not redesign the UI.

Do not replace the existing drag reorder implementation unless a clear bug requires it.

Expected behavior:

1. Same-track drag reorder with 3 or more Cuts

Given one Track:

- Cut A
- Cut B
- Cut C

Dragging Cut C onto Cut A should reorder using track-local indexes.

Expected final order:

- Cut C
- Cut A
- Cut B

Dragging Cut A onto Cut C should reorder using track-local indexes.

Expected final order depends on the chosen drop semantics, but it must be deterministic and tested.

Use the current semantics consistently:

- Dropping a dragged Cut onto a target Cut means "move dragged Cut to the target Cut's current track-local index."

2. No-op drag

Dragging a Cut onto itself must:

- not change Cut order
- not create a history entry
- not change activeCutId
- not change CanvasView target CutId

3. Cross-track drop ignored

Dragging a Cut from Track A onto a Cut in Track B must:

- not change either Track's Cut order
- not create a history entry
- not change activeCutId
- not change CanvasView target CutId
- not throw

Important:

Do not implement cross-track Cut moves in this phase.

4. Missing dragged Cut ignored safely

If a drag reorder callback receives a dragged CutId that no longer exists:

- it should be ignored safely
- no command should be executed
- no history entry should be created
- no exception should escape to the UI

This can be covered at the planner level or HomePage-level helper if practical.

5. Active Cut retention

After any valid drag reorder:

- activeCutId remains the same CutId
- CanvasView still points to the same CutId
- active Cut tooltip still points to the same Cut

6. Undo / Redo

For a valid drag reorder:

- one undoable command is created
- Undo restores previous Cut order
- Redo reapplies reordered Cut order

For ignored/no-op drag:

- Undo stack should not change

7. Selection during drag

If dragging a Cut chip currently triggers selection accidentally, prevent it.

Expected:

- dragging a non-active Cut to reorder should not select it merely because drag started
- activeCutId should only change when the user taps/selects a Cut, not from drag start

If current implementation already behaves this way, add a regression test if practical.

Implementation guidance:

Likely files:

lib/src/services/commands/cut_reorder_planner.dart
lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/services/commands/cut_reorder_planner_test.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Prefer small changes.

The planner already has:

- CutDragReorderPlan
- planSameTrackDrop

Strengthen planner tests first.

Potential planner test additions:

1. planSameTrackDrop returns null for same Cut

Given:

Track A: A1, A2

draggedCutId: A1
targetTrackId: Track A
targetCutIndex: 0

Expected:

- null

2. planSameTrackDrop returns null for missing dragged Cut

Given:

Track A: A1

draggedCutId: missing
targetTrackId: Track A
targetCutIndex: 0

Expected:

- null

3. planSameTrackDrop returns null for cross-track drop

Given:

Track A: A1
Track B: B1

draggedCutId: A1
targetTrackId: Track B
targetCutIndex: 0

Expected:

- null

4. planSameTrackDrop uses target track-local index

Given:

Track A: A1, A2
Track B: B1, B2, B3

draggedCutId: B3
targetTrackId: Track B
targetCutIndex: 0

Expected plan:

- trackId: Track B
- cutId: B3
- newIndex: 0

5. planSameTrackDrop supports later target index in same Track

Given:

Track B: B1, B2, B3

draggedCutId: B1
targetTrackId: Track B
targetCutIndex: 2

Expected plan:

- newIndex: 2

Potential CutListBar test additions:

- dragging a Cut onto itself does not call onCutReordered
- dragging Cut C onto Cut A emits draggedCutId C, targetTrackId Track A, targetCutIndex 0
- callback uses entry.cutIndex, not flattened list index, in a multi-track entries list

Potential app-level widget test additions:

Use existing QuickAnimakerApp fixture where practical.

If the default app only has two Cuts and one Track, keep app-level tests focused on:

- valid drag reorder still works
- active Cut retention
- undo/redo

For multi-track or 3-Cut behavior, prefer planner/controller-level tests if creating a full app fixture is too heavy.

Do not make tests overly brittle.

Prefer stable keys.

Avoid pixel-perfect layout assumptions.

Do not use warnIfMissed: false as the main fix.

Do not skip tests.

Do not remove existing tests.

Do not weaken Phase 59 Move Left / Move Right tests.

Do not weaken Phase 61 drag reorder tests.

Out of scope:

Do not add new UI controls.

Do not add full Cut management panel.

Do not add Conte Panel.

Do not add Storyboard Panel.

Do not add Premiere-style panel UI yet.

Do not implement cross-track Cut moves.

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

Do not implement Phase 63 or later.

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

lib/src/services/commands/cut_reorder_planner.dart
lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
test/services/commands/cut_reorder_planner_test.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart

Possibly changed files:

test/services/commands/cut_command_coordinator_test.dart

Avoid touching unrelated files.

Do not change repository/command behavior unless a clear bug is found.

Required checks for Codex:

Because this is a UI/test hardening phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is Cut drag reorder hardening only
- confirmation that no new user-facing feature was added
- confirmation that no Cut management panel or Conte Panel was added
- confirmation that no Storyboard Panel was added
- confirmation that cross-track Cut move was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 62 is complete when:

1. Same-track drag reorder behavior is covered beyond the two-Cut happy path.
2. Planner tests cover track-local index behavior.
3. Planner tests cover missing dragged Cut behavior.
4. Planner tests cover same-Cut no-op behavior.
5. Planner tests cover cross-track ignored behavior.
6. CutListBar tests cover callback target index using entry.cutIndex, not flattened index.
7. CutListBar tests cover no callback on dragging a Cut onto itself, if practical.
8. Existing app-level drag reorder tests still pass.
9. Existing Move Cut Left / Move Cut Right tests still pass.
10. Existing New/Rename/Duplicate/Delete tests still pass.
11. No ignored/no-op drag creates a command or history entry in tested layers.
12. activeCutId remains unchanged after valid drag reorder.
13. CanvasView remains targeted to the same active Cut after valid drag reorder.
14. Undo/Redo still work after valid drag reorder.
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

This phase should not change visible UI much, but drag behavior should still be checked.

Check:

- app launches
- existing Cut list appears
- drag Cut 2 before Cut 1
- active Cut remains active after drag
- Undo restores order
- Redo reapplies order
- dragging a Cut onto itself does not visibly break anything
- Move Cut Left still works
- Move Cut Right still works
- New Cut still works
- Rename Cut still works
- Duplicate Cut still works
- Delete Cut still works
- no full Cut management panel appears
- no Conte Panel appears
- no Storyboard Panel appears