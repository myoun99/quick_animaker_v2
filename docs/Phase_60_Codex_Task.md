# Phase 60 Codex Task - Cut Reorder Planning Helper Extraction

Create this file first:

docs/Phase_60_Codex_Task.md

Paste this full Phase 60 task document into that file.

After creating the document, commit and push it before asking Codex to implement the phase.

Recommended local commands for creating and pushing this task document:

git status
git add docs/Phase_60_Codex_Task.md
git commit -m "Add Phase 60 Codex task"
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

Small refactor / planning helper phase.

This is not a feature phase.

Goal:

Extract Cut reorder planning logic out of HomePage into a small pure helper so future drag/drop and Premiere-Pro-like Conte / Storyboard editing can reuse the same planning rules.

Phase 59 added basic UI actions:

- Move Cut Left
- Move Cut Right

Those actions currently require HomePage to know:

- where the active Cut is
- which Track owns it
- whether it can move left
- whether it can move right
- what target index to use

This logic should not keep growing inside HomePage.

Phase 60 should extract the pure calculation logic into a testable helper.

Do not change user-visible behavior.

Do not add new UI.

Do not add drag/drop.

Do not add Conte Panel.

Do not add Storyboard Panel.

Scope:

Add a pure helper that can resolve a Cut's position and calculate move-left / move-right planning results.

Suggested file:

lib/src/services/commands/cut_reorder_planner.dart

Alternative location is acceptable if it better matches the existing architecture, but keep it outside UI.

Suggested public types:

class CutPosition

Fields:

- TrackId trackId
- CutId cutId
- int cutIndex
- int cutCount

class CutReorderPlanner

Suggested methods:

CutPosition? findCutPosition({
required Project project,
required CutId cutId,
})

CutPosition requireCutPosition({
required Project project,
required CutId cutId,
})

bool canMoveLeft(CutPosition position)

bool canMoveRight(CutPosition position)

int moveLeftTargetIndex(CutPosition position)

int moveRightTargetIndex(CutPosition position)

Or equivalent names that fit the project style.

Required behavior:

1. findCutPosition

Given a Project and CutId:

- returns the TrackId, CutId, cutIndex, and cutCount for the Cut
- returns null if the Cut does not exist

2. requireCutPosition

Given a Project and CutId:

- returns the position if found
- throws StateError if not found

3. canMoveLeft

Returns true only when:

- cutIndex > 0

4. canMoveRight

Returns true only when:

- cutIndex < cutCount - 1

5. moveLeftTargetIndex

Returns:

- cutIndex - 1

Should fail clearly if the Cut cannot move left.

Preferred failure:

- StateError or RangeError with a clear message

6. moveRightTargetIndex

Returns:

- cutIndex + 1

Should fail clearly if the Cut cannot move right.

Preferred failure:

- StateError or RangeError with a clear message

Refactor HomePage:

Update HomePage to use the new planner instead of owning the full reorder-position logic directly.

Current HomePage behavior must remain unchanged:

- Move Cut Left disabled when active Cut is first
- Move Cut Right disabled when active Cut is last
- Move Cut Left calls CutCommandCoordinator.reorderCut
- Move Cut Right calls CutCommandCoordinator.reorderCut
- activeCutId remains unchanged
- _refreshAfterCutCommand still happens after move
- existing tests remain meaningful

HomePage may still contain small UI-level glue methods such as:

- _canMoveActiveCutLeft
- _canMoveActiveCutRight
- _moveActiveCutLeftFromList
- _moveActiveCutRightFromList

But the actual position lookup and target-index calculation should come from the helper.

Do not duplicate the planner logic in HomePage.

Do not move UI concerns into the planner.

Planner must not know about:

- BuildContext
- Widgets
- Controllers
- HistoryManager
- CutCommandCoordinator
- EditingSessionState
- CanvasController
- active Cut selection mutation
- UI refresh

Planner should be pure and deterministic.

Export task:

If the project has a command barrel or service barrel where planning helpers belong, export the new planner.

Suggested file if appropriate:

lib/src/services/commands/cut_commands.dart

Do not export it if existing style keeps helpers private to imports.

Follow project conventions.

Testing requirements:

Add focused unit tests for the planner.

Suggested file:

test/services/commands/cut_reorder_planner_test.dart

Required test coverage:

1. finds Cut position in first Track

Given a Project with Track A containing Cuts A, B, C:

- find Cut B
- expect trackId is Track A
- expect cutId is Cut B
- expect cutIndex is 1
- expect cutCount is 3

2. finds Cut position in later Track

Given multiple Tracks:

- Track A has Cut A
- Track B has Cut B and Cut C
- find Cut C
- expect trackId is Track B
- expect cutIndex is 1
- expect cutCount is 2

3. missing Cut

- findCutPosition returns null
- requireCutPosition throws StateError

4. canMoveLeft / canMoveRight

For a list of 3 Cuts:

- first Cut: canMoveLeft false, canMoveRight true
- middle Cut: canMoveLeft true, canMoveRight true
- last Cut: canMoveLeft true, canMoveRight false

5. target index calculation

For a middle Cut at index 1:

- moveLeftTargetIndex returns 0
- moveRightTargetIndex returns 2

6. edge target index failures

For first Cut:

- moveLeftTargetIndex fails clearly

For last Cut:

- moveRightTargetIndex fails clearly

Existing widget tests:

Existing widget tests from Phase 59 should still pass.

Do not remove meaningful UI tests.

Do not weaken Move Left / Move Right tests.

Do not skip tests.

Out of scope:

Do not add new UI.

Do not add drag/drop.

Do not add reorder handles.

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

Do not implement Phase 61 or later.

Architecture rules:

ProjectRepository owns project data mutation.

ProjectRepository must not own activeCutId.

CutReorderPlanner must not mutate project data.

CutReorderPlanner must not manage undo/redo.

CutReorderPlanner must not know about UI.

EditingSessionState owns activeCutId.

HistoryManager owns undo/redo command history.

CutCommandCoordinator is still the entry point for executing reorder commands from UI.

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
lib/src/ui/home_page.dart
test/services/commands/cut_reorder_planner_test.dart
test/widget_test.dart

Possibly changed files:

lib/src/services/commands/cut_commands.dart
test/services/commands/cut_commands_export_test.dart

Avoid touching unrelated files.

Do not change command/repository behavior unless a clear bug is found.

Required checks for Codex:

Because this is a code/test refactor phase, run:

dart format lib test
flutter analyze
flutter test
git status

Required Codex report:

After implementation, report:

- changed files
- confirmation that this is a planner extraction/refactor only
- confirmation that no new UI was added
- confirmation that no drag/drop was added
- confirmation that no Cut management panel or Conte Panel was added
- confirmation that cross-track Cut move was not added
- confirmation that no save/load or JSON schema changes were made
- confirmation that no broad state-management framework was added
- analyze result
- test result
- git status summary

Acceptance criteria:

Phase 60 is complete when:

1. Cut reorder position lookup is extracted from HomePage.
2. A pure planner/helper exists for Cut reorder planning.
3. Planner can find a Cut's TrackId, CutId, index, and count.
4. Planner supports canMoveLeft.
5. Planner supports canMoveRight.
6. Planner supports move-left target index calculation.
7. Planner supports move-right target index calculation.
8. Missing Cut behavior is tested.
9. Edge target-index failure behavior is tested.
10. HomePage uses the planner for Move Cut Left / Move Cut Right enablement and target index calculation.
11. Existing Move Cut Left / Move Cut Right behavior remains unchanged.
12. Existing undo/redo behavior remains unchanged.
13. No new UI is added.
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

This phase should not change visible behavior.

After merge and local checks, a short manual check is enough:

- app launches
- existing Cut list still appears
- Move Cut Left still works
- Move Cut Right still works
- edge disabled behavior still works
- Undo / Redo still work after Cut reorder
- no drag/drop UI appears
- no Cut management panel appears
- no Conte Panel appears yet