# Phase 35 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 35: Passive Cut List UI MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 34 are complete.

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
```

This task implements only Phase 35.

---

## Scope

Implement only:

```text
Phase 35: Passive Cut List UI MVP
```

This is a small UI display phase.

The goal is to show a compact, read-only Cut list / active Cut indicator using the existing `cutListEntriesFor` read model.

This phase should not add Cut switching behavior.

This phase should not add Cut create/delete/rename behavior.

This phase should not add Storyboard Panel.

---

## Main Goal

Add a small passive Cut list UI that lets the user see the current Cut context without changing it.

Expected behavior:

```text
- Display the current project cuts in a compact UI area.
- Mark the active cut.
- Use `cutListEntriesFor(project, activeCutId: _editingSession.activeCutId)`.
- The UI is read-only.
- Clicking a cut should not switch cuts in this phase.
```

This is preparation for future Cut switching.

---

## Recommended UI Direction

The UI should stay compact and professional.

Avoid long explanatory text.

Prefer short labels and tooltips.

Recommended display style:

```text
Cuts: [Cut 1]
```

or a compact horizontal row:

```text
Cut 1
```

For the active cut, use a subtle selected/highlighted style.

Do not add large tutorial text.

Do not add a large panel yet.

Do not add a Storyboard Panel yet.

---

## Suggested Placement

Add the passive Cut list near the existing top-level editing context area.

Preferred options:

```text
- Near the existing toolbar/header area in HomePage
- Above or near the TimelinePanel
- In a compact row where it does not add visual noise
```

Do not significantly restructure the app layout.

Do not replace TimelinePanel.

Do not add tabs yet.

Do not add a new major panel yet.

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

For now, Phase 35 should only prepare the Cut list context.

Storyboard Panel should come later, after Cut selection/switching is stable.

---

## Part A: Add Passive Cut List Widget

Add a small widget.

Recommended file:

```text
lib/src/ui/cut/cut_list_bar.dart
```

Alternative acceptable file:

```text
lib/src/ui/cut/cut_list_panel.dart
```

Recommended widget shape:

```dart
class CutListBar extends StatelessWidget {
  const CutListBar({
    super.key,
    required this.entries,
  });

  final List<CutListEntry> entries;

  @override
  Widget build(BuildContext context) {
    ...
  }
}
```

The widget should:

```text
- Accept `List<CutListEntry>`.
- Render nothing or a compact placeholder if the list is empty.
- Render cut names in stable order.
- Visually indicate `entry.isActive`.
- Be read-only.
- Not expose onTap switching behavior yet.
```

If an `onTap` callback is added for future-proofing, do not use it in `HomePage` yet and do not switch cuts.

Preferred for this phase:

```text
No onTap.
```

---

## Part B: Wire It Into HomePage Read-Only

Update:

```text
lib/src/ui/home_page.dart
```

Use:

```dart
final cutEntries = cutListEntriesFor(
  _repository.requireProject(),
  activeCutId: _editingSession.activeCutId,
);
```

Pass entries into the new widget.

Important:

```text
- Do not call setActiveCutId from the UI.
- Do not rebuild controllers for another cut.
- Do not add cut switching behavior.
- Do not add cut creation behavior.
- Do not add cut deletion behavior.
- Do not add cut rename behavior.
```

Keep layout changes minimal.

---

## Part C: Add Widget Tests

Add or update widget tests.

Recommended new file:

```text
test/ui/cut_list_bar_test.dart
```

or existing widget test file if that is more consistent.

Required test coverage:

```text
1. CutListBar renders cut names.
2. CutListBar visually marks the active cut in a testable way.
3. CutListBar handles an empty entry list without crashing.
4. HomePage still renders the sample cut UI.
5. HomePage still renders existing sample layer/timeline content.
```

For testable active state, prefer one of:

```text
- Key on active cut chip/container
- Semantics label
- Text style difference if easy to test
```

Do not test Cut switching because it does not exist yet.

---

## Part D: Preserve Existing Behavior

The app should continue to:

```text
- create the same sample project
- resolve the same sample cut
- construct LayerController for the active cut
- construct TimelineController for the active cut
- pass the active cut to CanvasView
- show the same canvas/layer/timeline UI
```

The only visible change should be a small passive Cut indicator/list.

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
lib/src/controllers/cut_list_helpers.dart
lib/src/controllers/editing_session_state.dart
lib/src/ui/home_page.dart
lib/src/ui/timeline/
test/controllers/cut_list_helpers_test.dart
test/widget_test.dart
test/ui/
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut switching behavior
- Multiple Cut editing UI
- Cut create behavior
- Cut delete behavior
- Cut rename behavior
- Cut tabs with switching
- Cut dropdown with switching
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
- New destructive controls
- Large new panel layout
```

Do not implement Phase 36 or later.

---

## Allowed Changes

Allowed:

```text
- Add a small read-only CutListBar/CutListPanel widget.
- Wire the widget into HomePage as a passive display.
- Use cutListEntriesFor for UI data.
- Add widget tests for passive rendering.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 35:

```text
The app should look almost the same as before, except for a small passive Cut indicator/list.
```

The Cut list should be display-only.

Clicking should not switch cuts.

No new project editing behavior should exist.

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

After merging and pulling Phase 35, run the app manually and verify:

```text
1. App launches normally.
2. A small passive Cut indicator/list is visible.
3. The active cut is shown, likely as Cut 1.
4. Clicking or interacting with the Cut indicator does not switch cuts.
5. Canvas appears as before.
6. Layer 1 / Layer 2 appear as before.
7. Timeline / X-sheet appears as before.
8. Existing sample cut content appears unchanged.
9. New Frame still works.
10. Blank / X still works.
11. Mark ● still toggles.
12. Rename Frame still works.
13. Copy Frame / Paste Linked Frame still works.
14. + Exposure / - Exposure still work.
15. Undo / Redo still work.
16. No Cut switching behavior was added.
17. No Storyboard Panel was added.
18. No large new panel or tab layout was added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Passive Cut list/indicator UI exists.
2. It uses cutListEntriesFor or equivalent read model data.
3. It displays the current cut name.
4. It marks the active cut in a compact way.
5. It does not switch cuts.
6. It does not create/delete/rename cuts.
7. It does not add Storyboard Panel.
8. Existing canvas/layer/timeline behavior remains unchanged.
9. Widget tests cover passive rendering.
10. No repository API redesign is added.
11. No command API redesign is added.
12. No JSON schema changes are made.
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
Implemented Phase 35 Passive Cut List UI MVP.

Changed:
- Added a read-only Cut list/indicator widget.
- Wired it into HomePage using cutListEntriesFor.
- Added widget tests for passive Cut list rendering.
- Existing canvas/layer/timeline behavior is unchanged.
- No Cut switching behavior was added.
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

Read `docs/Phase_35_Codex_Task.md` and implement Phase 35 only. Add a small read-only Cut list/indicator UI using the existing cutListEntriesFor read model, wire it into HomePage as a passive display, and add widget tests. Do not add Cut switching behavior, Cut create/delete/rename, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc/ChangeNotifier, large new panel layout, or Phase 36+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
