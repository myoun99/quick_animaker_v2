# Phase 32 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 32: Active Cut Session State MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 31 are complete.

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
```

This task implements only Phase 32.

---

## Scope

Implement only:

```text
Phase 32: Active Cut Session State MVP
```

This is a small internal state extraction and test phase.

The goal is to move the current active Cut selection into a tiny session-state object while preserving the existing single-cut behavior.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Phase 28 introduced `_activeCutId` directly inside `HomePage`.

Phase 31 extracted pure helper functions for active cut lookup.

Phase 32 should introduce a very small app/session-level state object that owns the current active `CutId`.

Recommended output:

```text
lib/src/controllers/editing_session_state.dart
test/controllers/editing_session_state_test.dart
```

Alternative acceptable name:

```text
lib/src/controllers/active_cut_session.dart
test/controllers/active_cut_session_test.dart
```

Prefer `EditingSessionState` if it is likely to later own selected `TrackId`, `LayerId`, `FrameId`, or timeline selection state.

Keep the object small.

---

## Required Behavior

Add a small class similar to:

```dart
class EditingSessionState {
  EditingSessionState({required CutId activeCutId})
    : _activeCutId = activeCutId;

  CutId get activeCutId => _activeCutId;

  CutId _activeCutId;

  void setActiveCutId(CutId cutId) {
    _activeCutId = cutId;
  }
}
```

Adapt to existing project style.

Important:

```text
- This object should not extend ChangeNotifier.
- This object should not use Provider, Riverpod, Bloc, or Stream.
- This object should not depend on Flutter.
- This object should not depend on ProjectRepository.
- This object should not mutate Project data.
- This object should only represent lightweight session/UI editing state.
```

If using immutable style is preferred, a simple immutable value object with `copyWith` is acceptable, but avoid overengineering.

Recommended for this phase:

```text
A tiny mutable session object is acceptable because HomePage already owns mutable UI state.
```

---

## Part A: Add Editing Session State

Add:

```text
lib/src/controllers/editing_session_state.dart
```

The class should own:

```text
CutId activeCutId
```

It may optionally include:

```text
factory EditingSessionState.forProject(Project project)
```

that uses:

```text
defaultActiveCutIdFor(project)
```

This factory is allowed if it keeps HomePage cleaner.

Recommended shape:

```dart
class EditingSessionState {
  EditingSessionState({required CutId activeCutId})
    : _activeCutId = activeCutId;

  factory EditingSessionState.forProject(Project project) {
    return EditingSessionState(
      activeCutId: defaultActiveCutIdFor(project),
    );
  }

  CutId _activeCutId;

  CutId get activeCutId => _activeCutId;

  void setActiveCutId(CutId cutId) {
    _activeCutId = cutId;
  }
}
```

Keep it small.

Do not add layer/frame/timeline selection yet.

---

## Part B: Update HomePage To Use EditingSessionState

Update:

```text
lib/src/ui/home_page.dart
```

Replace direct `_activeCutId` ownership with the session object.

Expected direction:

```dart
late final EditingSessionState _editingSession;
```

In `initState()`:

```dart
final project = _createSampleProject();
_editingSession = EditingSessionState.forProject(project);
_repository = ProjectRepository(initialProject: project);
```

Then use:

```dart
_editingSession.activeCutId
```

when constructing:

```text
LayerController
TimelineController
CanvasView
```

Keep user-visible behavior unchanged.

Do not add UI for changing active cut.

Do not call `setActiveCutId` from UI yet unless tests need it directly on the session object.

---

## Part C: Add Session State Tests

Add:

```text
test/controllers/editing_session_state_test.dart
```

Required tests:

```text
1. EditingSessionState stores the initial activeCutId.
2. setActiveCutId updates activeCutId.
3. EditingSessionState.forProject uses defaultActiveCutIdFor behavior.
4. forProject resolves the sample-style first video cut.
5. forProject throws StateError if the project has no cuts.
```

Use small pure model fixtures.

Do not use widget tests for this session object.

---

## Part D: Preserve Active Cut Helper Tests

Do not remove or weaken:

```text
test/controllers/active_cut_helpers_test.dart
```

Phase 31 helper tests should continue to pass.

---

## Part E: Preserve Existing Widget Regression

Do not remove the Phase 30 widget regression test.

The running app should still show the existing sample cut content.

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
lib/src/controllers/active_cut_helpers.dart
lib/src/ui/home_page.dart
lib/src/models/project.dart
lib/src/models/cut_id.dart
test/controllers/active_cut_helpers_test.dart
test/widget_test.dart
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

Do not implement Phase 33 or later.

---

## Allowed Changes

Allowed:

```text
- Add a tiny EditingSessionState or ActiveCutSession class.
- Add pure unit tests for that class.
- Update HomePage to read activeCutId from the session object.
- Keep existing active cut helper tests and widget regression tests.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 32:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
Active Cut selection is now owned by a small session-state object instead of directly by HomePage.
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

After merging and pulling Phase 32, run the app manually and verify:

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
1. Editing session state object exists.
2. The object owns activeCutId.
3. The object can initialize activeCutId from a Project through the existing default active cut helper.
4. HomePage uses the session object instead of owning activeCutId directly.
5. The sample project still resolves to the existing sample cut.
6. LayerController is still constructed/scoped from the active cut id.
7. TimelineController is still constructed/scoped from the active cut id.
8. CanvasView still receives the active cut id.
9. Session state tests cover initialization, update, forProject behavior, and no-cut error.
10. No Cut switching UI is added.
11. No Storyboard UI is added.
12. No repository API redesign is added.
13. No command API redesign is added.
14. No JSON schema changes are made.
15. Existing user-visible behavior remains unchanged.
16. dart format lib test passes.
17. flutter analyze passes.
18. flutter test passes.
19. git status is clean after commit.
20. Manual Android Studio run shows no behavior regression.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 32 Active Cut Session State MVP.

Changed:
- Added EditingSessionState for lightweight activeCutId session ownership.
- HomePage now reads activeCutId from EditingSessionState.
- Added session state unit tests.
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

Read `docs/Phase_32_Codex_Task.md` and implement Phase 32 only. Add a tiny editing/session state object that owns the current activeCutId, initialize it from the existing default active cut helper, update HomePage to read activeCutId from that object, and add pure unit tests. Preserve existing user-visible behavior. Do not add Cut switching UI, multiple Cut editing UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc/ChangeNotifier, or Phase 33+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
