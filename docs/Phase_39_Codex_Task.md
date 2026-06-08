# Phase 39 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 39: Cut Switching UX Polish MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 38 are complete.

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
* Active-cut edit safety regression tests

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
docs/Phase_38_Codex_Task.md
```

This task implements only Phase 39.

---

## Scope

Implement only:

```text
Phase 39: Cut Switching UX Polish MVP
```

This is a small UI polish and regression-test phase.

The goal is to make the existing `CutListBar` / Cut switching UI clearer and more production-tool-like without adding new Cut management features.

This phase should not add Cut create/delete/rename behavior.

This phase should not add Storyboard Panel.

This phase should not add a large Cut management panel.

---

## Main Goal

Phase 37 introduced minimal Cut switching.

Phase 38 added regression tests for active-cut edit safety.

Phase 39 should polish the current Cut UI so it is clearer that:

```text
- there are multiple cuts,
- one cut is active,
- inactive cuts can be selected,
- the UI remains compact and production-tool-like.
```

Do this with small visual/tooltip/semantics improvements only.

---

## Recommended UX Direction

Keep the UI compact.

Avoid long instructional text.

Prefer:

```text
- short labels
- clear active state
- compact chips/buttons
- useful tooltips
- stable keys for tests
```

Do not add tutorial-style hints.

Do not add a large panel.

Do not add a full Storyboard view.

Do not add cut management controls.

---

## Part A: Polish CutListBar Visual State

Update:

```text
lib/src/ui/cut/cut_list_bar.dart
```

Recommended small improvements:

```text
- Make the active cut chip visually more distinct.
- Make clickable inactive chips feel selectable without being visually noisy.
- Keep active and inactive styles consistent with the existing app theme.
- Preserve compact spacing.
- Preserve existing stable keys.
```

Possible implementation options:

```text
- Add a small active prefix/dot/icon inside the active chip.
- Add slightly stronger border/weight for active chip.
- Use Material + InkWell instead of raw GestureDetector when onCutSelected is provided.
- Add mouse cursor / hover affordance if simple and Flutter-supported.
```

Do not overdo the styling.

Do not introduce custom colors unless necessary.

Prefer theme-based colors.

---

## Part B: Improve Tooltip / Semantics

Update tooltip text to be short and production-tool-like.

Recommended examples:

```text
Active: Cut 1
Switch to Cut 2
```

Instead of long explanatory text.

If semantics labels are easy and low-risk, add simple semantics so tests and accessibility can identify active/selectable cuts.

Possible semantics labels:

```text
Active cut Cut 1
Switch to cut Cut 2
```

Keep labels short.

Do not add visible tutorial text.

---

## Part C: Keep HomePage Behavior The Same

`HomePage` should continue to:

```text
- create the same sample project with Cut 1 and Cut 2
- show CutListBar
- pass cutListEntriesFor data
- pass onCutSelected
- switch cuts through the existing minimal Phase 37 path
```

Do not add new HomePage layout sections.

Do not add a cut management toolbar.

Do not add cut create/delete/rename.

Only change HomePage if needed to keep tests passing after tooltip/semantics changes.

Preferred result:

```text
No HomePage behavior changes.
```

---

## Part D: Update Tests

Update existing tests for the polished UI.

Likely files:

```text
test/ui/cut_list_bar_test.dart
test/widget_test.dart
```

Required coverage:

```text
1. CutListBar still renders cut names.
2. Active cut is still visually/testably distinct.
3. Inactive cuts are selectable when onCutSelected is provided.
4. Tooltip or semantics text reflects active/selectable state.
5. HomePage still renders Cut 1 and Cut 2.
6. Cut switching still works.
7. Existing Phase 38 active-cut edit safety tests still pass.
```

Do not remove active-cut safety tests.

Do not weaken existing Cut switching tests.

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

No new project editing behavior should be added.

---

## Long-Term Storyboard Direction To Keep In Mind

The long-term product direction may include a dedicated Storyboard Panel.

Future possibilities include:

```text
- A separate Storyboard Panel similar in importance to TimelinePanel
- A mode switch from Timeline/X-sheet into Storyboard view
- A separate independent panel if that better fits production workflow
```

Do not decide or implement that in this phase.

For now, Phase 39 should only polish the current Cut switching UI.

Storyboard Panel should come later, after Cut switching and active-cut editing are stable.

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
lib/src/ui/cut/cut_list_bar.dart
lib/src/ui/home_page.dart
lib/src/controllers/cut_list_helpers.dart
lib/src/controllers/editing_session_state.dart
test/ui/cut_list_bar_test.dart
test/widget_test.dart
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

Do not implement Phase 40 or later.

---

## Allowed Changes

Allowed:

```text
- Small CutListBar visual polish.
- Small tooltip/semantics improvements.
- Test updates for the polished CutListBar.
- Minimal HomePage test expectation updates if tooltip/semantics strings change.
```

Preferred:

```text
No new app behavior beyond the existing Phase 37 Cut switching.
No new large UI layout.
```

---

## Expected User-Visible Behavior

After Phase 39:

```text
The app should look almost the same as Phase 38, but the CutListBar should be clearer and more polished.
```

Cut switching should still work.

No cut create/delete/rename UI should exist.

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

After merging and pulling Phase 39, run the app manually and verify:

```text
1. App launches normally.
2. `Cuts:`, `Cut 1`, and `Cut 2` are visible.
3. Cut 1 is active by default and visually clear.
4. Cut 2 looks selectable but not like a destructive/editing control.
5. Click Cut 2 and confirm Cut 2 becomes active.
6. Click Cut 1 and confirm Cut 1 becomes active again.
7. Canvas appears as before.
8. Layer/timeline content still changes according to the active cut.
9. New Frame still works on the active cut.
10. Blank / X still works on the active cut.
11. Mark ● still works on the active cut.
12. + Exposure / - Exposure still work on the active cut.
13. Undo / Redo does not crash after switching cuts.
14. No cut create/delete/rename UI was added.
15. No Storyboard Panel was added.
16. No large new panel or tab layout was added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. CutListBar active/inactive states are clearer than Phase 38.
2. CutListBar remains compact.
3. Cut switching still works.
4. Tooltip or semantics labels are short and useful.
5. Existing Cut switching tests still pass.
6. Existing active-cut edit safety tests still pass.
7. No cut create/delete/rename UI is added.
8. No Storyboard Panel is added.
9. No repository API redesign is added.
10. No command API redesign is added.
11. No JSON schema changes are made.
12. Existing linked-frame policies remain intact.
13. Existing user-visible behavior remains unchanged except small CutListBar polish.
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
Implemented Phase 39 Cut Switching UX Polish MVP.

Changed:
- Polished CutListBar active/selectable states.
- Improved CutListBar tooltip/semantics labels.
- Updated tests for the polished Cut switching UI.
- Existing Cut switching and active-cut edit safety behavior is unchanged.
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

Read `docs/Phase_39_Codex_Task.md` and implement Phase 39 only. Polish the existing CutListBar / Cut switching UI with small visual, tooltip, or semantics improvements so active/selectable cuts are clearer while keeping the UI compact. Preserve existing Cut switching behavior and active-cut edit safety tests. Do not add cut create/delete/rename, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo redesign, timeline/canvas redesign, Provider/Riverpod/Bloc/ChangeNotifier, large new panels, or Phase 40+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
