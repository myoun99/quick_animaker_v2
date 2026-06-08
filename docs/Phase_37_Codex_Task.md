# Phase 37 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 37: Minimal Cut Switching MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 36 are complete.

Recent completed work includes:

* TimelinePanel-based timeline/cell editing UI
* New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
* Timeline marks
* X/null exposure
* Linked Frame Copy/Paste MVP
* Same-layer linked paste using shared `FrameId`
* Linked frames share drawing material/source but do not share exposure duration
* Exposure +/- operates on the selected authored timeline entry, not globally by `FrameId`
* Rename conflict policy:

    * Same frame name means same material
    * Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed
    * Conflict offers Link / Cancel only
    * Rename-only is intentionally not offered
* Compact production-tool-like timeline UI
* Product direction notes
* Cut structure preparation notes
* Cut structure audit notes
* Active Cut state design notes
* ID scope decision notes
* Minimal explicit `activeCutId` flow in `HomePage`
* Active Cut isolation tests using two-cut fixtures
* Default active cut resolver
* Active cut lookup helper extraction
* `EditingSessionState` owns `activeCutId`
* `HomePage` controller construction clearly derives from `EditingSessionState.activeCutId`
* `CutListEntry` / `cutListEntriesFor` read model helper
* Passive `CutListBar` UI using `cutListEntriesFor`
* Optional `CutListBar.onCutSelected` callback for selection intent

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Phase_28_Codex_Task.md
docs/Phase_29_Codex_Task.md
docs/Phase_30_Codex_Task.md
docs/Phase_31_Codex_Task.md
docs/Phase_32_Codex_Task.md
docs/Phase_33_Codex_Task.md
docs/Phase_34_Codex_Task.md
docs/Phase_35_Codex_Task.md
docs/Phase_36_Codex_Task.md
```

This task implements only Phase 37.

---

## Scope

Implement only:

```text
Phase 37: Minimal Cut Switching MVP
```

This is the first very small real Cut switching phase.

The goal is to allow switching between existing cuts by clicking the existing `CutListBar`.

This phase should not add Cut create/delete/rename behavior.

This phase should not add Storyboard Panel.

This phase should not add multiple Cut editing UI beyond switching the active cut.

---

## Main Goal

When the user clicks a cut in `CutListBar`:

```text
- EditingSessionState.activeCutId changes to the selected CutId.
- LayerController is rebuilt/scoped for the new active cut.
- TimelineController is rebuilt/scoped for the new active cut.
- CanvasView receives the new active cut id.
- The CutListBar active mark updates.
- The visible layer/timeline/canvas context changes to the selected cut.
```

Keep the behavior minimal.

Do not implement cross-cut linked paste.

Do not implement cut creation, deletion, or rename.

Do not implement Storyboard Panel.

---

## Sample Project Requirement

To make switching testable and manually visible, update the sample project to contain two cuts.

Current sample behavior should remain familiar.

Recommended sample structure:

```text
Project
 └ Video Track
    ├ Cut 1 / sample-cut
    │  ├ Layer 1
    │  └ Layer 2
    └ Cut 2 / sample-cut-2
       └ Layer A or Cut 2 Layer
```

Requirements:

```text
- Keep the existing sample cut id and content as the default active cut.
- Add a second cut with a distinct CutId.
- Give the second cut a visibly distinct cut name, such as `Cut 2`.
- Give the second cut at least one visibly distinct layer name, such as `Cut 2 Layer`.
- The second cut should have at least one frame/timeline cell if practical.
```

Do not change save/load schema.

Do not add project creation UI.

---

## Part A: Add A Small Controller Rebuild Helper In HomePage

Update:

```text
lib/src/ui/home_page.dart
```

Currently `HomePage` initializes controllers once from `_editingSession.activeCutId`.

For Phase 37, add a small private method that constructs/reconstructs active-cut-scoped controllers.

Recommended direction:

```dart
void _rebuildActiveCutControllers() {
  final activeCutId = _editingSession.activeCutId;

  _layerController = LayerController(
    repository: _repository,
    historyManager: _historyManager,
    cutId: activeCutId,
    frameId: _frameId,
  );

  _timelineController = TimelineController(
    repository: _repository,
    historyManager: _historyManager,
    cutId: activeCutId,
  );

  _canvasController = CanvasController(
    repository: _repository,
    historyManager: _historyManager,
  );
}
```

Adapt to existing constructor signatures and lifecycle.

Important:

```text
- Keep the method small.
- Reuse the existing ProjectRepository and HistoryManager.
- Do not create a new ProjectRepository on cut switch.
- Do not reset or replace the Project data.
- Do not introduce Provider/Riverpod/Bloc/ChangeNotifier.
```

If rebuilding `CanvasController` is not necessary because it resolves by `cutId` at render time, it is acceptable to leave it as-is, but be explicit and keep tests passing.

---

## Part B: Wire CutListBar Selection In HomePage

Update the `CutListBar` call in `HomePage`.

Expected direction:

```dart
CutListBar(
  entries: cutEntries,
  onCutSelected: _handleCutSelected,
)
```

Add a private handler:

```dart
void _handleCutSelected(CutId cutId) {
  if (cutId == _editingSession.activeCutId) {
    return;
  }

  setState(() {
    _editingSession.setActiveCutId(cutId);
    _rebuildActiveCutControllers();
  });
}
```

Important:

```text
- Ignore selecting the already active cut.
- Switch only to existing cuts from the UI entries.
- Do not add dialogs.
- Do not add menu items.
- Do not add cut create/delete/rename.
```

If additional safety is easy, use `requireCutById` or `findCutById` to verify the cut exists before switching.

Do not throw from normal UI tap behavior unless the state is impossible.

---

## Part C: Preserve Selection / Timeline Policy

Switching cuts should not imply shared timeline state.

Important product rules:

```text
- Timeline placement remains independent per cut.
- Linked frames share material/source only.
- Linked frames do not share timeline placement, authored exposure duration, mark position, blank/X position, or selected cell state.
```

For this phase, do not implement cross-cut linked frames.

Do not attempt to preserve selected cell across cuts unless existing controller behavior already does so safely.

It is acceptable for selected layer/frame/cell UI state to reset on cut switch in this MVP.

---

## Part D: Update / Add Tests

Add or update widget tests.

Recommended locations:

```text
test/widget_test.dart
test/ui/cut_list_bar_test.dart
```

Required coverage:

```text
1. HomePage renders both Cut 1 and Cut 2 in the CutListBar.
2. Cut 1 is active by default.
3. Clicking Cut 2 updates the active cut indicator to Cut 2.
4. Clicking Cut 2 shows the second cut's distinct layer/timeline context.
5. Clicking Cut 1 switches back to the first cut.
6. Cut switching does not add Storyboard Panel or other new UI.
```

Also preserve existing `CutListBar` callback tests from Phase 36.

If testing full canvas behavior is hard, focus on visible layer/timeline text and active cut indicator.

Do not add integration-heavy tests that are brittle.

---

## Part E: Manual UI Behavior

After Phase 37:

```text
- The user should see both Cut 1 and Cut 2.
- Clicking Cut 2 should make Cut 2 active.
- Layer/timeline content should update to Cut 2's content.
- Clicking Cut 1 should return to Cut 1.
```

This is now real cut switching, but only among existing sample cuts.

---

## Important Design Policies To Preserve

From Phase 27:

```text
- Active Cut state should be explicit.
- Active Cut state should initially be lightweight app/session/controller-level state.
- Active Cut state should not be stored in ProjectRepository.
- ProjectRepository should remain focused on project data mutations.
- Controllers should be constructed with or intentionally receive active CutId.
- IDs should be treated as project-wide unique values.
- Even with project-wide unique IDs, edit APIs should carry enough active Cut context to avoid ambiguous behavior.
```

From linked-frame policy:

```text
- Same frame name means same material within the same layer.
- Linked frames share material/source only.
- Linked frames share FrameId, strokes/material, and frame name.
- Linked frames do not share timeline placement.
- Linked frames do not share authored exposure duration.
- Linked frames do not share mark position.
- Linked frames do not share blank/X position.
- Linked frames do not share selected cell state.
- Exposure +/- operates on the selected authored timeline entry, not every use of the same FrameId.
- Timeline placement must remain independent per cut.
```

Do not weaken these policies.

---

## Files To Inspect

Inspect at least:

```text
lib/src/ui/home_page.dart
lib/src/ui/cut/cut_list_bar.dart
lib/src/controllers/editing_session_state.dart
lib/src/controllers/active_cut_helpers.dart
lib/src/controllers/cut_list_helpers.dart
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/controllers/canvas_controller.dart
test/widget_test.dart
test/ui/cut_list_bar_test.dart
test/controllers/
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut create behavior
- Cut delete behavior
- Cut rename behavior
- Cut duplicate behavior
- Multiple Cut editing UI beyond switching active cut
- Storyboard Panel
- Storyboard Layer
- Camera Layer
- Audio Layer behavior
- Layer type enum
- Linked Layer
- Cross-layer paste
- Cross-cut paste
- Project-level material pool
- Global FrameId refactor
- ID generation refactor
- Repository API redesign
- Command API redesign
- JSON schema changes
- Save/load format changes
- Undo/Redo redesign
- Timeline behavior redesign
- Timeline placement sharing
- Canvas painting behavior redesign
- Canvas layout redesign
- Cut.canvasSize UI/layout usage
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier
- Stream-based session state
- Complex app-wide state management
- New destructive controls
- Large Storyboard or Cut management panel
```

Do not implement Phase 38 or later.

---

## Allowed Changes

Allowed:

```text
- Add a second sample cut.
- Wire CutListBar.onCutSelected in HomePage.
- Update EditingSessionState.activeCutId on cut selection.
- Rebuild/recreate active-cut-scoped controllers on cut switch.
- Add small tests for minimal cut switching.
- Keep CutListBar callback tests.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 37:

```text
The app now shows at least Cut 1 and Cut 2.
Clicking an existing cut switches the active cut.
Canvas/layer/timeline context changes to the selected cut.
```

No cut creation/deletion/rename UI should exist.

No Storyboard Panel should exist.

---

## Tests / Validation

Run:

```bash
dart format lib test
flutter analyze
flutter test
git status
```

Do not run `dart format` on Markdown files.

---

## Manual Check In Android Studio

After merging and pulling Phase 37, run the app manually and verify:

```text
1. App launches normally.
2. The small Cut indicator/list is visible.
3. `Cuts:`, `Cut 1`, and `Cut 2` are visible.
4. Cut 1 is active by default.
5. Clicking Cut 2 makes Cut 2 active.
6. Layer/timeline content changes to Cut 2's content.
7. Clicking Cut 1 switches back to Cut 1.
8. Layer/timeline content returns to Cut 1's content.
9. New Frame works on the active cut.
10. Blank / X works on the active cut.
11. Mark ● toggles on the active cut.
12. Rename Frame works on the active cut.
13. Copy Frame / Paste Linked Frame still works within the active cut/layer only.
14. + Exposure / - Exposure works on the active cut.
15. Undo / Redo does not crash after switching cuts.
16. No cut create/delete/rename UI was added.
17. No Storyboard Panel was added.
18. No large new panel or tab layout was added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. The sample project has at least two cuts.
2. CutListBar displays both cuts.
3. Cut 1 remains the default active cut.
4. Clicking Cut 2 updates EditingSessionState.activeCutId.
5. Active-cut-scoped controllers are rebuilt or otherwise retargeted safely.
6. CanvasView receives the selected active cut id.
7. Visible layer/timeline context changes when the active cut changes.
8. Switching back to Cut 1 works.
9. Cut create/delete/rename UI is not added.
10. Storyboard Panel is not added.
11. No repository API redesign is added.
12. No command API redesign is added.
13. No JSON schema changes are made.
14. Existing linked-frame policies remain intact.
15. dart format lib test passes.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.
19. Manual Android Studio run shows no behavior regression except intended cut switching.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 37 Minimal Cut Switching MVP.

Changed:
- Added a second sample cut.
- Wired CutListBar selection into HomePage.
- Updating activeCutId now rebuilds/retargets active-cut-scoped controllers.
- Cut 1 and Cut 2 can be switched from the CutListBar.
- Existing canvas/layer/timeline behavior is preserved for the active cut.
- No cut create/delete/rename UI was added.
- No Storyboard Panel was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_37_Codex_Task.md` and implement Phase 37 only. Add a second sample cut and wire `CutListBar.onCutSelected` in `HomePage` so clicking an existing cut updates `EditingSessionState.activeCutId` and safely rebuilds/retargets active-cut-scoped controllers. Keep this as a minimal cut switching MVP. Do not add cut create/delete/rename, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo redesign, timeline/canvas redesign, Provider/Riverpod/Bloc/ChangeNotifier, large new panels, or Phase 38+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
