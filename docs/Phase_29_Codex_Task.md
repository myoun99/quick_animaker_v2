# Phase 29 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 29: Active Cut Isolation Tests MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 28 are complete.

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
```

This task implements only Phase 29.

---

## Scope

Implement only:

```text
Phase 29: Active Cut Isolation Tests MVP
```

This is a test-focused phase.

The goal is to add focused tests proving that the existing controller/repository seams can operate on a selected cut without accidentally using another cut.

This phase should not add Cut switching UI.

This phase should not add new user-visible behavior.

This phase should not broadly refactor controller or repository APIs.

---

## Main Goal

Phase 28 made the current edited cut explicit as `activeCutId` in `HomePage`.

Phase 29 should add tests that prepare for future multi-cut work by proving active-cut scoping assumptions around existing controllers.

Recommended focus:

```text
- LayerController constructed with CutId A sees and edits Cut A layers.
- LayerController constructed with CutId B sees and edits Cut B layers.
- TimelineController constructed with CutId A resolves timeline/frame data from Cut A.
- TimelineController constructed with CutId B resolves timeline/frame data from Cut B.
- CanvasController.layerFramesForCut(CutId A) resolves paintable layers from Cut A.
- CanvasController.layerFramesForCut(CutId B) resolves paintable layers from Cut B.
```

The tests should use a project fixture containing at least two cuts.

---

## Important Design Policies To Preserve

From Phase 27:

```text
- Active Cut state should be explicit.
- Active Cut state should initially be app/session/controller-level state.
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
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/controllers/canvas_controller.dart
lib/src/services/project_repository.dart
lib/src/models/
test/controllers/
test/ui/
test/widget_test.dart
```

Only change tests unless a tiny production-code seam is absolutely necessary.

Prefer test-only changes.

---

## Part A: Add Two-Cut Test Fixtures

Create or update controller tests with a project fixture containing:

```text
Project
 └ Track
    ├ Cut A
    │  └ Layer A
    │     └ Frame A
    └ Cut B
       └ Layer B
          └ Frame B
```

Use distinct IDs:

```text
CutId('cut-a')
CutId('cut-b')
LayerId('layer-a')
LayerId('layer-b')
FrameId('frame-a')
FrameId('frame-b')
```

The two cuts should have distinguishable data, such as:

```text
- different layer names
- different frame names
- different timeline entries
- optionally different strokes
```

Do not rely on duplicate IDs in this phase.

Phase 27 decided that IDs should be treated as project-wide unique values.

---

## Part B: LayerController Active Cut Isolation Tests

Add or update tests in:

```text
test/controllers/layer_controller_test.dart
```

Required test coverage:

```text
- A LayerController constructed with cut-a exposes only Cut A layers.
- A LayerController constructed with cut-b exposes only Cut B layers.
- Adding a layer through a controller scoped to cut-a adds the layer to Cut A, not Cut B.
- Adding a layer through a controller scoped to cut-b adds the layer to Cut B, not Cut A.
```

Keep the tests small.

Do not change LayerController behavior unless a test reveals an actual bug that can be fixed with a minimal scoped change.

---

## Part C: TimelineController Active Cut Isolation Tests

Add or update tests in:

```text
test/controllers/timeline_controller_test.dart
```

Required test coverage:

```text
- A TimelineController constructed with cut-a resolves timeline state from Cut A.
- A TimelineController constructed with cut-b resolves timeline state from Cut B.
- Creating a new drawing frame through a controller scoped to cut-a updates Cut A only.
- Creating a blank/X exposure through a controller scoped to cut-b updates Cut B only.
```

If the existing public API makes some of these awkward, choose equivalent public operations already used by existing tests.

Do not add new runtime APIs only for tests unless absolutely necessary.

---

## Part D: CanvasController Cut Resolution Tests

Add or update tests in:

```text
test/controllers/canvas_controller_test.dart
```

Required test coverage:

```text
- layerFramesForCut(cut-a) returns paintable layer/frame data from Cut A.
- layerFramesForCut(cut-b) returns paintable layer/frame data from Cut B.
- Cut A and Cut B can have different visible frame names or stroke counts and the returned data remains cut-specific.
```

Do not change painting behavior.

Do not change CanvasView.

---

## Part E: Optional HomePage Regression Test

If practical and low-risk, update:

```text
test/widget_test.dart
```

or an existing UI test to confirm:

```text
- HomePage still renders after Phase 28 activeCutId refactor.
- Existing single-cut sample UI still appears.
```

Do not add new UI.

Do not test Cut switching UI because it does not exist yet.

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
- Complex app-wide state management
- New toolbar actions
- New dialogs
- New menu items
- New visible UI controls
```

Do not implement Phase 30 or later.

---

## Allowed Changes

Allowed:

```text
- Add test fixtures.
- Add controller tests for two-cut isolation.
- Add canvas controller cut-resolution tests.
- Add minimal helper functions inside test files.
- Make tiny production-code fixes only if required to make existing intended cut scoping work.
```

If production code must change, keep it minimal and explain why.

Preferred result:

```text
test-only changes.
```

---

## Expected User-Visible Behavior

After Phase 29:

```text
The app should look and behave the same as before.
```

The change is primarily test coverage.

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

## Completion Criteria

This phase is complete only when:

```text
1. Tests use a project fixture with at least two cuts.
2. LayerController tests prove cut-a and cut-b layer isolation.
3. TimelineController tests prove cut-a and cut-b timeline/edit isolation.
4. CanvasController tests prove layerFramesForCut resolves cut-specific paintable data.
5. No Cut switching UI is added.
6. No Storyboard UI is added.
7. No repository API redesign is added.
8. No command API redesign is added.
9. No JSON schema changes are made.
10. Existing user-visible behavior remains unchanged.
11. dart format lib test passes.
12. flutter analyze passes.
13. flutter test passes.
14. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 29 Active Cut Isolation Tests MVP.

Changed:
- Added two-cut controller test fixtures.
- Added LayerController cut isolation tests.
- Added TimelineController cut isolation tests.
- Added CanvasController cut resolution tests.
- No Cut switching UI was added.
- Existing user-visible behavior is unchanged.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_29_Codex_Task.md` and implement Phase 29 only. Add focused tests using a two-cut project fixture to prove `LayerController`, `TimelineController`, and `CanvasController.layerFramesForCut` remain scoped to the intended `CutId`. Prefer test-only changes. Do not add Cut switching UI, multiple Cut editing UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc, or Phase 30+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
