# Phase 38 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 38: Cut Switching Regression & Active-Cut Edit Safety.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 37 are complete.

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
* Minimal Cut switching between existing sample cuts

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
docs/Phase_37_Codex_Task.md
```

This task implements only Phase 38.

---

## Scope

Implement only:

```text
Phase 38: Cut Switching Regression & Active-Cut Edit Safety
```

This is a regression-test and safety-hardening phase.

The goal is to prove that after switching cuts, existing timeline/cell editing actions operate on the active cut only and do not accidentally mutate or display the other cut.

Prefer test-only changes.

Small production-code fixes are allowed only if a test reveals an active-cut scoping bug.

Do not add new user-facing features.

Do not add Storyboard Panel.

---

## Main Goal

Phase 37 introduced minimal Cut switching.

Phase 38 should add tests around the most important active-cut edit behaviors:

```text
- New Frame after switching to Cut 2 affects Cut 2 only.
- Blank / X after switching to Cut 2 affects Cut 2 only.
- Mark ● after switching to Cut 2 affects Cut 2 only.
- Exposure +/- after switching to Cut 2 affects the selected authored timeline entry in Cut 2 only.
- Copy/Paste Linked Frame remains scoped to the active cut/layer and does not silently create cross-cut linked behavior.
- Switching back to Cut 1 shows Cut 1 content unchanged except for explicitly performed Cut 1 edits.
```

The tests should focus on observable widget behavior and/or existing controller seams.

---

## Preferred Result

Preferred result:

```text
test-only changes
```

Expected likely files:

```text
test/widget_test.dart
test/controllers/layer_controller_test.dart
test/controllers/timeline_controller_test.dart
test/controllers/canvas_controller_test.dart
```

Only add production-code changes if necessary to fix a real bug.

If production code changes are needed, keep them minimal and explain exactly why.

---

## Part A: Add Widget Regression Tests For Active Cut Edits

Update or add tests around:

```text
test/widget_test.dart
```

Required widget-level coverage:

```text
1. Switch from Cut 1 to Cut 2.
2. Confirm Cut 2 is active.
3. Perform New Frame.
4. Confirm the visible Cut 2 timeline/layer context updates.
5. Switch back to Cut 1.
6. Confirm Cut 1 did not receive the Cut 2 new frame.
```

Also add one or more focused tests for:

```text
- Blank / X after switching to Cut 2 does not affect Cut 1.
- Mark ● after switching to Cut 2 does not affect Cut 1.
- Exposure +/- after switching to Cut 2 affects the selected authored timeline entry only.
```

Keep tests readable.

Do not make one huge brittle test that tries to cover everything at once if smaller tests are clearer.

Use existing helper functions in `test/widget_test.dart` if available, such as toolbar tap helpers.

---

## Part B: Add Controller-Level Active Cut Edit Safety Tests If Helpful

If widget tests become too brittle, add or extend controller tests instead.

Possible locations:

```text
test/controllers/layer_controller_test.dart
test/controllers/timeline_controller_test.dart
```

Recommended coverage:

```text
- TimelineController scoped to cut-a creates drawing frames in cut-a only.
- TimelineController scoped to cut-b creates blank/X entries in cut-b only.
- Exposure +/- through a cut-b scoped controller affects cut-b selected authored entry only.
- LayerController scoped to cut-a does not expose cut-b layers.
- LayerController scoped to cut-b does not expose cut-a layers.
```

Phase 29 already added some of this. Do not duplicate unnecessarily.

Add only missing safety coverage.

---

## Part C: Copy/Paste Linked Frame Safety

Add at least one test that protects the current policy:

```text
Same-layer linked paste is allowed.
Cross-cut linked paste is not implemented.
Cut switching should not silently turn copied frame state into cross-cut linked paste.
```

Preferred behavior for Phase 38:

```text
- Copy state should not survive active cut switching.
```

Phase 37 already clears `_copiedFrame` on cut switch.

Test this behavior if practical:

```text
1. Copy a frame in Cut 1.
2. Switch to Cut 2.
3. Confirm Paste Linked Frame is unavailable or does not paste the Cut 1 copied frame into Cut 2.
```

Use existing UI affordances/test helpers.

Do not implement cross-cut paste.

Do not implement project-level material pool.

---

## Part D: Undo / Redo Smoke Safety After Cut Switching

Add a light smoke test if practical:

```text
1. Switch to Cut 2.
2. Perform a simple edit, such as New Frame or Blank / X.
3. Trigger Undo.
4. Trigger Redo.
5. Confirm no crash and active cut context remains coherent.
```

Do not redesign Undo/Redo.

Do not attempt to persist UI selection across undo/redo unless already supported.

A simple no-crash regression test is enough.

---

## Part E: Preserve Existing Behavior

The app should continue to:

```text
- show Cut 1 and Cut 2
- keep Cut 1 active by default
- switch to Cut 2 when Cut 2 is clicked
- switch back to Cut 1 when Cut 1 is clicked
- keep canvas/layer/timeline behavior scoped to the active cut
```

No new visible UI should be added.

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
- Same-layer duplicate independent FrameIds with the same non-empty name should not be allowed.
- Rename conflict must offer Link / Cancel only.
- Rename-only must not be offered.
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
lib/src/controllers/layer_controller.dart
lib/src/controllers/timeline_controller.dart
lib/src/controllers/canvas_controller.dart
lib/src/services/project_repository.dart
test/widget_test.dart
test/controllers/layer_controller_test.dart
test/controllers/timeline_controller_test.dart
test/controllers/canvas_controller_test.dart
test/ui/cut_list_bar_test.dart
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut create behavior
- Cut delete behavior
- Cut rename behavior
- Cut duplicate behavior
- Cut management panel
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
- New visible toolbar actions
- New destructive controls
- Large Storyboard or Cut management panel
```

Do not implement Phase 39 or later.

---

## Allowed Changes

Allowed:

```text
- Add active-cut edit safety tests.
- Add widget regression tests for Cut 1 / Cut 2 switching and editing.
- Add controller-level tests if widget tests are too brittle.
- Add minimal production-code fixes only if an active-cut scoping bug is discovered.
```

Preferred:

```text
No production code changes.
No UI changes.
```

---

## Expected User-Visible Behavior

After Phase 38:

```text
The app should look and behave the same as Phase 37.
```

No new visible UI should appear.

The improvement is regression coverage and active-cut edit safety.

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

After merging and pulling Phase 38, run the app manually and verify:

```text
1. App launches normally.
2. `Cuts:`, `Cut 1`, and `Cut 2` are visible.
3. Cut 1 is active by default.
4. Click Cut 2 and confirm Cut 2 becomes active.
5. On Cut 2, use New Frame and confirm the edit appears in Cut 2.
6. Switch back to Cut 1 and confirm the Cut 2 edit did not appear in Cut 1.
7. Switch to Cut 2 again and confirm the Cut 2 edit remains there.
8. On Cut 2, test Blank / X and confirm it affects Cut 2 only.
9. On Cut 2, test Mark ● and confirm it affects Cut 2 only.
10. On Cut 2, test + Exposure / - Exposure and confirm it affects the active Cut 2 selected cell only.
11. Copy a frame in Cut 1, switch to Cut 2, and confirm Paste Linked Frame is not available or does not paste cross-cut.
12. Undo / Redo after switching cuts does not crash.
13. No cut create/delete/rename UI was added.
14. No Storyboard Panel was added.
15. No large new panel or tab layout was added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Tests cover active-cut edit behavior after switching.
2. Tests confirm edits performed in Cut 2 do not appear in Cut 1.
3. Tests confirm switching back to Cut 1 works.
4. Tests protect against accidental cross-cut linked paste through copied frame state.
5. Undo/Redo after cut switching has at least smoke coverage if practical.
6. No cut create/delete/rename UI is added.
7. No Storyboard Panel is added.
8. No repository API redesign is added.
9. No command API redesign is added.
10. No JSON schema changes are made.
11. Existing linked-frame policies remain intact.
12. Existing user-visible behavior remains unchanged except already-existing Phase 37 cut switching.
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
Implemented Phase 38 Cut Switching Regression & Active-Cut Edit Safety.

Changed:
- Added regression tests for active-cut edit safety after switching.
- Verified Cut 2 edits do not leak into Cut 1.
- Verified copied linked frame state does not silently become cross-cut paste.
- Added Undo/Redo smoke coverage after cut switching if practical.
- Existing user-visible behavior is unchanged.
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

Read `docs/Phase_38_Codex_Task.md` and implement Phase 38 only. Add regression tests proving that after switching between Cut 1 and Cut 2, existing edit actions remain scoped to the active cut and do not leak across cuts. Prefer test-only changes. Cover New Frame, Blank/X or Mark where practical, copied linked frame state not becoming cross-cut paste, and Undo/Redo smoke behavior after cut switching if practical. Do not add cut create/delete/rename, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo redesign, timeline/canvas redesign, Provider/Riverpod/Bloc/ChangeNotifier, large new panels, or Phase 39+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
