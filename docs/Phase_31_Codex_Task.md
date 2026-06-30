# Phase 31 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 31: Active Cut Lookup Helpers MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 30 are complete.

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
* Default active cut resolver in `HomePage`

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
```

This task implements only Phase 31.

---

## Scope

Implement only:

```text
Phase 31: Active Cut Lookup Helpers MVP
```

This is a small helper extraction and test phase.

The goal is to move active-cut lookup logic into a small testable helper without changing user-visible behavior.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Phase 30 added a private default active cut resolver inside `HomePage`.

Phase 31 should extract minimal active cut lookup behavior into a small helper so future active cut and cut switching work can reuse it safely.

Recommended output:

```text
lib/src/controllers/active_cut_helpers.dart
test/controllers/active_cut_helpers_test.dart
```

Alternative acceptable location:

```text
lib/src/utils/active_cut_helpers.dart
test/utils/active_cut_helpers_test.dart
```

Prefer `controllers` if the existing project treats active editing context as controller-level/session-level logic.

The helper should remain small and pure.

---

## Required Helper Behavior

Add small functions similar to:

```dart
CutId defaultActiveCutIdFor(Project project)
```

and optionally:

```dart
Cut? findCutById(Project project, CutId cutId)
Cut requireCutById(Project project, CutId cutId)
```

Adapt naming to existing project style.

Required behavior:

```text
- defaultActiveCutIdFor(project) returns the first cut in the first video track with cuts.
- If no video track has cuts, it returns the first cut in the first track with cuts.
- If the project has no cuts, it throws StateError.
- findCutById(project, cutId) returns the matching Cut or null.
- requireCutById(project, cutId) returns the matching Cut or throws StateError.
```

If adding all three helpers feels too broad, prioritize:

```text
1. defaultActiveCutIdFor
2. findCutById
```

But `requireCutById` is acceptable if it keeps future code cleaner.

---

## Part A: Add Active Cut Helper

Add a small helper file.

Recommended file:

```text
lib/src/controllers/active_cut_helpers.dart
```

The helper should:

```text
- Import only models it needs.
- Avoid Flutter imports.
- Avoid UI dependencies.
- Avoid ProjectRepository dependency.
- Avoid HistoryManager dependency.
- Avoid controller dependencies.
- Be pure functions over Project data.
```

Example style:

```dart
CutId defaultActiveCutIdFor(Project project) {
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

Adapt to existing `TrackType` API.

---

## Part B: Update HomePage To Use Helper

Update:

```text
lib/src/ui/home_page.dart
```

Replace the private `_defaultActiveCutIdFor` helper with the extracted helper.

Expected behavior:

```text
- HomePage still creates the sample project once.
- HomePage still resolves _activeCutId from that project.
- LayerController still receives _activeCutId.
- TimelineController still receives _activeCutId.
- CanvasView still receives _activeCutId.
- The existing sample project still resolves to CutId('sample-cut').
```

Remove the old private helper from `HomePage` if it becomes unused.

Do not otherwise rewrite `HomePage`.

---

## Part C: Add Helper Tests

Add tests for the helper.

Recommended file:

```text
test/controllers/active_cut_helpers_test.dart
```

Required test cases:

```text
1. defaultActiveCutIdFor returns the first cut from the first video track with cuts.
2. defaultActiveCutIdFor skips an empty video track and returns the next video track cut.
3. defaultActiveCutIdFor falls back to a non-video track if no video track has cuts.
4. defaultActiveCutIdFor throws StateError when the project has no cuts.
5. findCutById returns a cut from the first track.
6. findCutById returns a cut from a later track.
7. findCutById returns null for a missing cut.
```

If `requireCutById` is added, also test:

```text
8. requireCutById returns an existing cut.
9. requireCutById throws StateError for a missing cut.
```

Use small pure model fixtures.

Do not use Flutter widget tests for this helper.

---

## Part D: Preserve Existing Widget Regression

Existing widget tests from Phase 30 should continue to pass.

Do not remove the Phase 30 widget regression test.

It is acceptable to leave it as behavior-level coverage that the sample active cut still resolves correctly in the running app.

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
lib/src/models/cut_id.dart
test/widget_test.dart
test/controllers/
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
- Complex app-wide state management
- New toolbar actions
- New dialogs
- New menu items
- New visible UI controls
```

Do not implement Phase 32 or later.

---

## Allowed Changes

Allowed:

```text
- Add a small active cut helper file.
- Add pure unit tests for active cut helper behavior.
- Update HomePage to use the extracted helper.
- Keep the existing Phase 30 widget regression test.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 31:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
Default active cut lookup is now a small testable helper.
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

After merging and pulling Phase 31, run the app manually and verify:

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
1. Active cut lookup helper exists.
2. HomePage uses the extracted helper for default activeCutId resolution.
3. The sample project still resolves to the existing sample cut.
4. Helper tests cover video-track preference, fallback track behavior, missing-cut behavior, and cut lookup by id.
5. LayerController is still constructed/scoped from activeCutId.
6. TimelineController is still constructed/scoped from activeCutId.
7. CanvasView still receives activeCutId.
8. No Cut switching UI is added.
9. No Storyboard UI is added.
10. No repository API redesign is added.
11. No command API redesign is added.
12. No JSON schema changes are made.
13. Existing user-visible behavior remains unchanged.
14. dart format lib test passes.
15. flutter analyze passes.
16. flutter test passes.
17. git status is clean after commit.
18. Manual Android Studio run shows no behavior regression.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 31 Active Cut Lookup Helpers MVP.

Changed:
- Added active cut lookup helper.
- HomePage now uses the extracted helper to resolve default activeCutId.
- Added helper unit tests.
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

Read `docs/Phase_31_Codex_Task.md` and implement Phase 31 only. Extract default active cut lookup from `HomePage` into a small pure helper, add tests for default cut resolution and cut lookup by id, and keep existing user-visible behavior unchanged. Do not add Cut switching UI, multiple Cut editing UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc, or Phase 32+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
