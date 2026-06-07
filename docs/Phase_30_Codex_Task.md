# Phase 30 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 30: Default Active Cut Resolution MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 29 are complete.

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
```

This task implements only Phase 30.

---

## Scope

Implement only:

```text
Phase 30: Default Active Cut Resolution MVP
```

This is a small runtime refactor and test phase.

The goal is to make the default active cut selection deterministic from the current `Project` data instead of relying only on directly assigning the sample cut id.

This phase should preserve current user-visible behavior.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Phase 28 introduced an explicit `activeCutId` in `HomePage`.

Phase 30 should make its default initialization more intentional.

Recommended direction:

```text
- Create the sample project first.
- Resolve the default active cut id from that project.
- Set _activeCutId from that resolver.
- Use _activeCutId to construct LayerController and TimelineController.
- Pass _activeCutId to CanvasView.
```

The default resolver should pick a deterministic cut.

Recommended policy:

```text
Default active cut = the first available cut in the first video track that has at least one cut.
```

If the current model/test helpers make TrackType access awkward, use the first track with at least one cut for this phase, but prefer the first video track if `TrackType.video` is available and already used.

The current sample project should still resolve to:

```text
CutId('sample-cut')
```

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
lib/src/models/project.dart
lib/src/models/track.dart
lib/src/models/cut.dart
test/widget_test.dart
test/ui/
test/controllers/
```

Only change files necessary for the minimal default-active-cut resolver.

---

## Part A: Add Default Active Cut Resolver

Update:

```text
lib/src/ui/home_page.dart
```

Add a small private helper.

Suggested shape:

```dart
CutId _defaultActiveCutIdFor(Project project) {
  for (final track in project.tracks) {
    if (track.type != TrackType.video) {
      continue;
    }

    if (track.cuts.isNotEmpty) {
      return track.cuts.first.id;
    }
  }

  for (final track in project.tracks) {
    if (track.cuts.isNotEmpty) {
      return track.cuts.first.id;
    }
  }

  throw StateError('Project has no cuts.');
}
```

Adapt to the existing model API.

Important:

```text
- Keep this helper private.
- Keep it small.
- Do not add a new service or controller yet.
- Do not introduce ProjectSessionController or EditingSessionController.
- Do not add Provider/Riverpod/Bloc.
```

If the codebase already has an appropriate helper, use it instead of duplicating logic.

---

## Part B: Use Resolver In HomePage initState

Update `initState()` so the sample project is created once and used to initialize both repository and active cut.

Expected direction:

```dart
final project = _createSampleProject();
_activeCutId = _defaultActiveCutIdFor(project);
_repository = ProjectRepository(initialProject: project);
```

Then construct:

```text
LayerController(... cutId: _activeCutId ...)
TimelineController(... cutId: _activeCutId ...)
CanvasView(... cutId: _activeCutId ...)
```

Current user-visible behavior must remain unchanged.

The sample project should still contain the same sample cut.

---

## Part C: Add Tests For Default Active Cut Resolution

Add or update minimal tests.

Preferred location:

```text
test/ui/home_page_test.dart
```

or an existing HomePage/widget test file if one exists.

Required test coverage:

```text
- HomePage still builds successfully.
- The sample project default active cut resolves to the existing sample cut.
```

If the helper is private and not directly testable, test through visible behavior:

```text
- Pump HomePage/App.
- Verify existing sample layers/timeline/canvas still appear.
```

If direct testing is better, a small `@visibleForTesting` helper may be considered, but avoid exposing broad production API just for tests.

Preferred approach:

```text
Keep helper private and test behavior.
```

Do not add Cut switching UI tests.

Do not add multi-cut UI tests.

---

## Part D: Optional Two-Cut Resolver Test

If practical without exposing too much API, add a small test that verifies the resolver chooses the first available cut deterministically.

This is optional.

Do not add a large new test architecture.

Do not introduce new public app state only for this test.

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

Do not implement Phase 31 or later.

---

## Allowed Changes

Allowed:

```text
- Small private default active cut resolver.
- Small HomePage initState cleanup to create project once and derive activeCutId from it.
- Minimal tests proving HomePage still builds and default active cut behavior is stable.
```

If production code changes, keep it limited to the resolver and initialization flow.

---

## Expected User-Visible Behavior

After Phase 30:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
The default active cut is resolved deterministically from the current project data.
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

After merging and pulling Phase 30, run the app manually and verify:

```text
1. App launches normally.
2. Canvas appears as before.
3. Timeline / X-sheet appears as before.
4. Layer panel appears as before.
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
1. HomePage derives the default activeCutId from the current Project data.
2. The sample project still resolves to the existing sample cut.
3. LayerController is still constructed/scoped from activeCutId.
4. TimelineController is still constructed/scoped from activeCutId.
5. CanvasView still receives activeCutId.
6. No Cut switching UI is added.
7. No Storyboard UI is added.
8. No repository API redesign is added.
9. No command API redesign is added.
10. No JSON schema changes are made.
11. Existing user-visible behavior remains unchanged.
12. Tests are added or updated only as needed for this minimal resolver.
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
Implemented Phase 30 Default Active Cut Resolution MVP.

Changed:
- HomePage now resolves the default activeCutId from the current Project data.
- The sample project still resolves to the existing sample cut.
- LayerController, TimelineController, and CanvasView remain scoped from activeCutId.
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

Read `docs/Phase_30_Codex_Task.md` and implement Phase 30 only. Add a small default active cut resolver so `HomePage` derives `_activeCutId` from the current `Project` data instead of directly assigning the sample cut id. Preserve existing user-visible behavior. Do not add Cut switching UI, multiple Cut editing UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc, or Phase 31+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
