# Phase 36 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 36: Cut Selection Intent Wiring MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 35 are complete.

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
```

This task implements only Phase 36.

---

## Scope

Implement only:

```text
Phase 36: Cut Selection Intent Wiring MVP
```

This is a small UI event-wiring preparation phase.

The goal is to let `CutListBar` optionally report that a cut was selected, without actually switching cuts in the app yet.

This phase should not add real Cut switching behavior.

This phase should not change `activeCutId` from the UI.

This phase should not rebuild or retarget controllers.

This phase should not add Storyboard Panel.

---

## Main Goal

Phase 35 added a passive read-only `CutListBar`.

Phase 36 should add an optional selection intent callback to the widget:

```dart
final ValueChanged<CutId>? onCutSelected;
```

or equivalent.

When provided, tapping/clicking a cut chip should call:

```dart
onCutSelected(entry.cutId)
```

When not provided, the UI should remain passive/read-only.

Important:

```text
HomePage should not wire this callback yet.
```

The app should continue to display the cut list passively, with no actual cut switching.

---

## Required Behavior

Update `CutListBar` so that:

```text
- It accepts an optional onCutSelected callback.
- If onCutSelected is null, it remains non-interactive/passive.
- If onCutSelected is provided, each cut chip can be tapped/clicked.
- Tapping a cut chip calls onCutSelected with that entry's CutId.
- Tapping should not change entry.isActive by itself.
- Tapping should not mutate EditingSessionState.
- Tapping should not rebuild controllers.
- Tapping should not change ProjectRepository data.
```

This is only selection intent reporting.

---

## Part A: Update CutListBar

Update:

```text
lib/src/ui/cut/cut_list_bar.dart
```

Recommended shape:

```dart
class CutListBar extends StatelessWidget {
  const CutListBar({
    super.key,
    required this.entries,
    this.onCutSelected,
  });

  final List<CutListEntry> entries;
  final ValueChanged<CutId>? onCutSelected;
}
```

Update private chip widget similarly:

```dart
class _CutListChip extends StatelessWidget {
  const _CutListChip({
    required this.entry,
    required this.onSelected,
  });

  final CutListEntry entry;
  final ValueChanged<CutId>? onSelected;
}
```

Implementation guidance:

```text
- If onSelected is null, render the same passive visual chip as Phase 35.
- If onSelected is non-null, wrap the chip in a small Material/InkWell or GestureDetector.
- Keep visual style compact.
- Do not add large hover/selected UI.
- Preserve the existing active styling.
- Preserve tooltips.
```

Use keys so tests can tap entries.

Existing keys should remain stable if possible:

```text
cut-list-bar
cut-list-entry-<cutId>
cut-list-entry-label-<cutId>
```

Do not break existing tests if avoidable.

---

## Part B: Do Not Wire HomePage Yet

Update `HomePage` only if needed to satisfy constructor changes.

Expected result:

```dart
CutListBar(entries: cutEntries)
```

No callback.

Do not add:

```text
onCutSelected: ...
```

to `HomePage`.

Do not call:

```text
_editingSession.setActiveCutId(...)
```

from UI.

Do not recreate:

```text
LayerController
TimelineController
CanvasController
```

Do not add controller retargeting logic.

---

## Part C: Add / Update Widget Tests

Update:

```text
test/ui/cut_list_bar_test.dart
```

Required test coverage:

```text
1. Existing passive rendering tests still pass.
2. When onCutSelected is null, the widget remains passive.
3. When onCutSelected is provided, tapping a cut chip calls the callback with the correct CutId.
4. Tapping an inactive cut does not visually mark it active unless entries are rebuilt with isActive true.
5. Empty entries still render safely.
```

Also update:

```text
test/widget_test.dart
```

only if constructor changes require it.

Existing app shell test should still confirm that the passive Cut indicator appears.

Do not add tests for real app-level Cut switching because it does not exist yet.

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
- show the passive Cut list/indicator
```

There should be no user-visible cut switching.

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
- Real Cut switching behavior
- Calling EditingSessionState.setActiveCutId from HomePage
- Controller rebuild/retargeting on cut click
- Multiple Cut editing UI
- Cut create behavior
- Cut delete behavior
- Cut rename behavior
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

Do not implement Phase 37 or later.

---

## Allowed Changes

Allowed:

```text
- Add optional onCutSelected callback to CutListBar.
- Make Cut chips clickable only when the callback is provided.
- Add widget tests for callback behavior.
- Keep HomePage passive by not passing the callback.
```

Keep production changes minimal.

---

## Expected User-Visible Behavior

After Phase 36:

```text
The app should look the same as Phase 35.
```

The Cut list in `HomePage` should remain passive.

No cut switching should occur.

The new callback behavior should be tested only at the widget level.

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

After merging and pulling Phase 36, run the app manually and verify:

```text
1. App launches normally.
2. The small Cut indicator/list is visible.
3. `Cuts:` and `Cut 1` are visible.
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
16. No real Cut switching behavior was added.
17. No Storyboard Panel was added.
18. No large new panel or tab layout was added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. CutListBar accepts an optional onCutSelected callback.
2. Cut chips report selection intent when the callback is provided.
3. Cut chips remain passive when the callback is not provided.
4. HomePage does not pass onCutSelected yet.
5. HomePage does not call EditingSessionState.setActiveCutId from UI.
6. Controllers are not rebuilt/retargeted on cut click.
7. Existing passive Cut indicator still appears.
8. Existing canvas/layer/timeline behavior remains unchanged.
9. Widget tests cover passive and callback behavior.
10. No real Cut switching behavior is added.
11. No Storyboard UI is added.
12. No repository API redesign is added.
13. No command API redesign is added.
14. No JSON schema changes are made.
15. dart format lib test passes.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.
19. Manual Android Studio run shows no behavior regression.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 36 Cut Selection Intent Wiring MVP.

Changed:
- Added optional onCutSelected callback to CutListBar.
- Cut chips can report selection intent when a callback is provided.
- HomePage remains passive and does not switch cuts.
- Existing canvas/layer/timeline behavior is unchanged.
- No real Cut switching behavior was added.
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

Read `docs/Phase_36_Codex_Task.md` and implement Phase 36 only. Add an optional `onCutSelected` callback to `CutListBar` so cut chips can report selection intent when the callback is provided. Keep `HomePage` passive by not passing the callback. Do not implement real Cut switching, do not call `EditingSessionState.setActiveCutId` from UI, do not rebuild/retarget controllers, and do not add Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc/ChangeNotifier, large new panel layout, or Phase 37+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
