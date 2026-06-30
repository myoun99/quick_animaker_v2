# Phase 28 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 28: Minimal Active Cut State MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 27 are complete.

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

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Phase_27_Codex_Task.md
```

This task implements only Phase 28.

---

## Scope

Implement only:

```text
Phase 28: Minimal Active Cut State MVP
```

This is a small runtime refactor phase.

The goal is to make the current single-cut editing target explicit as `activeCutId` while preserving the current user-visible single-cut behavior.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Currently, `HomePage` effectively edits one hard-coded sample cut.

Phase 28 should make that implicit active cut explicit.

Recommended direction:

```text
- HomePage owns an explicit activeCutId field/state.
- The default activeCutId is the existing sample cut id.
- LayerController is constructed/scoped using activeCutId.
- TimelineController is constructed/scoped using activeCutId.
- CanvasView receives activeCutId.
- Existing single-cut behavior remains unchanged.
```

The app should behave the same after this phase.

---

## Important Design Decisions To Preserve

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
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/controllers/canvas_controller.dart
lib/src/ui/canvas/
lib/src/ui/timeline/
test/ui/
test/controllers/
test/widget_test.dart
```

Only change files necessary for the minimal active-cut-state refactor.

---

## Part A: Make Active Cut Explicit In HomePage

Update:

```text
lib/src/ui/home_page.dart
```

Current behavior likely uses a static or hard-coded sample `CutId`.

Refactor this so HomePage has an explicit active cut selection field/state.

Recommended simple direction:

```dart
static const CutId _sampleCutId = CutId('sample-cut');

late CutId _activeCutId;
```

or another small equivalent approach.

Expected behavior:

```text
- _activeCutId defaults to the existing sample cut id.
- Existing sample project creation still creates the same sample cut.
- LayerController and TimelineController are initialized using _activeCutId.
- CanvasView receives _activeCutId instead of a hard-coded cut id.
```

Do not add UI to change active cut.

Do not add menus, buttons, dropdowns, tabs, panels, or dialogs.

---

## Part B: Preserve Existing Controller Behavior

LayerController and TimelineController already appear to accept a `CutId`.

Use the explicit activeCutId flow from HomePage.

Do not broadly rewrite controller architecture.

Acceptable small cleanup:

```text
- Rename local variables to make active cut intent clearer.
- Ensure constructor arguments clearly come from activeCutId.
- Add small private helper in HomePage if it reduces duplication.
```

Not allowed:

```text
- Replacing controllers with new state management architecture.
- Adding ProjectSessionController.
- Adding EditingSessionController.
- Adding Provider/Riverpod/Bloc.
- Changing repository APIs.
- Changing command APIs.
```

---

## Part C: CanvasView Should Use Active Cut

Ensure the canvas view receives the explicit active cut id.

Expected direction:

```text
CanvasView(... cutId: _activeCutId ...)
```

or equivalent.

Do not change painting behavior.

Do not change stroke behavior.

Do not change canvas layout.

Do not start using Cut.canvasSize for layout in this phase.

---

## Part D: Tests

Add or update minimal tests proving the refactor preserved behavior and made the active cut explicit.

Preferred tests:

```text
- HomePage still renders the timeline/canvas/layer UI with the default active cut.
- Existing widget tests still pass.
- If practical, add a small test that verifies the sample active cut path still produces visible sample layers/timeline cells.
```

If existing tests already cover the behavior well, update only what is necessary.

Do not add multi-cut switching tests yet unless they can be added without introducing new UI or runtime behavior.

Do not add tests that require a Cut switching UI.

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
- Repository API changes
- Command API changes
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

Do not implement Phase 29 or later.

---

## Expected User-Visible Behavior

After Phase 28:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
The current edited cut is now represented by an explicit activeCutId instead of being only an implicit hard-coded cut reference.
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

## Completion Criteria

This phase is complete only when:

```text
1. HomePage has an explicit activeCutId or equivalent active cut selection field/state.
2. The default active cut is the existing sample cut.
3. LayerController is constructed/scoped from activeCutId.
4. TimelineController is constructed/scoped from activeCutId.
5. CanvasView receives activeCutId.
6. No Cut switching UI is added.
7. No Storyboard UI is added.
8. No repository API changes are made.
9. No command API changes are made.
10. No JSON schema changes are made.
11. Existing user-visible behavior remains unchanged.
12. Tests are added or updated only as needed for this minimal refactor.
13. dart format lib test passes.
14. flutter analyze passes.
15. flutter test passes.
16. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 28 Minimal Active Cut State MVP.

Changed:
- HomePage now owns an explicit activeCutId for the current single-cut editing context.
- LayerController, TimelineController, and CanvasView are scoped from activeCutId.
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

Read `docs/Phase_28_Codex_Task.md` and implement Phase 28 only. Make the current single-cut editing target explicit as `activeCutId` in `HomePage`, defaulting to the existing sample cut. Ensure `LayerController`, `TimelineController`, and `CanvasView` are scoped from that active cut id. Preserve existing user-visible behavior. Do not add Cut switching UI, Storyboard Panel, repository API changes, command API changes, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc, or Phase 29+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
