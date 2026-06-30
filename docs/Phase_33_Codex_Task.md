# Phase 33 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 33: Controller Construction From Editing Session Cleanup.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 32 are complete.

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
```

This task implements only Phase 33.

---

## Scope

Implement only:

```text
Phase 33: Controller Construction From Editing Session Cleanup
```

This is a small internal cleanup and regression-test phase.

The goal is to make `HomePage` controller construction clearly derive from `EditingSessionState.activeCutId`, while preserving existing user-visible behavior.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Phase 32 introduced:

```text
EditingSessionState
```

and updated `HomePage` to read:

```text
_editingSession.activeCutId
```

when constructing:

```text
LayerController
TimelineController
CanvasView
```

Phase 33 should slightly clean up the construction flow so the active cut id is captured once during initialization and used intentionally.

Recommended direction:

```dart
final activeCutId = _editingSession.activeCutId;
```

inside `initState()`, then pass `activeCutId` to:

```text
LayerController
TimelineController
```

and continue passing `_editingSession.activeCutId` or a clearly named getter to `CanvasView`.

The goal is clarity and future cut-switching readiness, not new behavior.

---

## Part A: Clean Up HomePage Controller Construction

Update:

```text
lib/src/ui/home_page.dart
```

Recommended small cleanup:

```dart
final project = _createSampleProject();
_editingSession = EditingSessionState.forProject(project);
final activeCutId = _editingSession.activeCutId;

_repository = ProjectRepository(initialProject: project);
_historyManager = HistoryManager();

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
```

If useful, add a tiny private getter:

```dart
CutId get _activeCutId => _editingSession.activeCutId;
```

Then use:

```dart
cutId: _activeCutId
```

for `CanvasView`.

This is acceptable because it makes the UI/build code clearer while keeping `EditingSessionState` as the owner.

Do not reintroduce a standalone mutable `_activeCutId` field.

Do not make the getter settable.

Do not add UI to change active cut.

---

## Part B: Preserve Existing Behavior

The app should continue to:

```text
- create the same sample project
- resolve the same sample cut
- construct LayerController for the active cut
- construct TimelineController for the active cut
- pass the active cut to CanvasView
- show the same canvas/layer/timeline UI
```

No user-visible behavior should change.

---

## Part C: Add or Update Small Regression Tests

Add or update minimal tests only if needed.

Preferred:

```text
test/widget_test.dart
```

Keep the existing Phase 30 widget regression test.

If it already covers the behavior, do not add unnecessary duplicate tests.

Acceptable small test update:

```text
- Verify the app still renders the sample layer/timeline cells after the session cleanup.
```

Do not add Cut switching UI tests.

Do not add multi-cut UI tests.

---

## Part D: Preserve Existing Session/Helper Tests

Do not remove or weaken:

```text
test/controllers/active_cut_helpers_test.dart
test/controllers/editing_session_state_test.dart
```

They should continue to pass.

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
lib/src/controllers/editing_session_state.dart
lib/src/controllers/active_cut_helpers.dart
test/widget_test.dart
test/controllers/editing_session_state_test.dart
test/controllers/active_cut_helpers_test.dart
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut switching UI
- Multiple Cut editing UI
- Cut list UI
- Cut tabs
- Cut dropdown
- Storyboard Panel
- Storyboard Layer
- Camera Layer
- Audio Layer
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
- Undo/Redo behavior changes
- Timeline behavior changes
- Timeline placement sharing
- Canvas painting behavior changes
- Canvas layout changes
- Cut.canvasSize UI/layout usage
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier
- Stream-based session state
- Complex app-wide state management
- New toolbar actions
- New dialogs
- New menu items
- New visible UI controls
```

Do not implement Phase 34 or later.

---

## Allowed Changes

Allowed:

```text
- Small HomePage cleanup around controller construction.
- Optional private activeCutId getter that reads from EditingSessionState.
- Minimal widget regression test update if needed.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 33:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
HomePage controller construction is clearer and explicitly based on EditingSessionState.
```

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

After merging and pulling Phase 33, run the app manually and verify:

```text
1. App launches normally.
2. Canvas appears as before.
3. Layer 1 / Layer 2 appear as before.
4. Timeline / X-sheet appears as before.
5. Existing sample cut content appears unchanged.
6. New Frame still works.
7. Blank / X still works.
8. Mark ● still toggles.
9. Rename Frame still works.
10. Copy Frame / Paste Linked Frame still works.
11. + Exposure / - Exposure still work.
12. Undo / Redo still work.
13. No Cut switching UI was added.
14. No Storyboard Panel was added.
15. No new visible buttons, dropdowns, tabs, or dialogs were added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. HomePage controller construction clearly derives from EditingSessionState.activeCutId.
2. HomePage does not reintroduce a standalone mutable _activeCutId field.
3. LayerController is still constructed/scoped from the active cut id.
4. TimelineController is still constructed/scoped from the active cut id.
5. CanvasView still receives the active cut id.
6. Existing sample project behavior is unchanged.
7. No Cut switching UI is added.
8. No Storyboard UI is added.
9. No repository API redesign is added.
10. No command API redesign is added.
11. No JSON schema changes are made.
12. Existing user-visible behavior remains unchanged.
13. dart format lib test passes.
14. flutter analyze passes.
15. flutter test passes.
16. git status is clean after commit.
17. Manual Android Studio run shows no behavior regression.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 33 Controller Construction From Editing Session Cleanup.

Changed:
- Cleaned up HomePage controller construction to derive from EditingSessionState.activeCutId.
- Existing user-visible behavior is unchanged.
- No Cut switching UI was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_33_Codex_Task.md` and implement Phase 33 only. Clean up `HomePage` controller construction so `LayerController`, `TimelineController`, and `CanvasView` clearly derive their cut id from `EditingSessionState.activeCutId`. Preserve existing user-visible behavior. Do not add Cut switching UI, multiple Cut editing UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc/ChangeNotifier, new visible UI controls, or Phase 34+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
