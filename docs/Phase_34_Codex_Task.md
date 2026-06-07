# Phase 34 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 34: Cut List Read Model MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 33 are complete.

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
```

This task implements only Phase 34.

---

## Scope

Implement only:

```text
Phase 34: Cut List Read Model MVP
```

This is a small pure helper/read-model and test phase.

The goal is to prepare for a future Cut list / Cut switching UI by adding a tested way to enumerate cuts from the current `Project`.

This phase should not add Cut switching UI.

This phase should not add multiple Cut editing UI.

This phase should not add Storyboard Panel.

---

## Main Goal

Add a small pure helper that can produce a stable list of cuts from a `Project`.

The future UI will need to display something like:

```text
Track 1 / Cut 1
Track 1 / Cut 2
Track 2 / Cut 1
```

and know which one is currently active.

Phase 34 should prepare only the data/read-model side.

Recommended output:

```text
lib/src/controllers/cut_list_helpers.dart
test/controllers/cut_list_helpers_test.dart
```

Alternative acceptable location:

```text
lib/src/controllers/cut_list_read_model.dart
test/controllers/cut_list_read_model_test.dart
```

Prefer `cut_list_helpers.dart` if it stays as small pure helpers.

---

## Required Read Model

Add a small immutable value class similar to:

```dart
class CutListEntry {
  const CutListEntry({
    required this.trackId,
    required this.trackName,
    required this.trackIndex,
    required this.trackType,
    required this.cutId,
    required this.cutName,
    required this.cutIndex,
    required this.isActive,
  });

  final TrackId trackId;
  final String trackName;
  final int trackIndex;
  final TrackType trackType;
  final CutId cutId;
  final String cutName;
  final int cutIndex;
  final bool isActive;
}
```

Adapt naming to existing project style.

The read model should include enough information for a future compact Cut selector UI, but it should not create any UI in this phase.

---

## Required Helper Behavior

Add a helper similar to:

```dart
List<CutListEntry> cutListEntriesFor(
  Project project, {
  CutId? activeCutId,
})
```

Required behavior:

```text
- It returns cuts in stable project order.
- Track order follows `project.tracks`.
- Cut order follows each track's `cuts`.
- Each entry includes track id, track name, track index, track type, cut id, cut name, cut index.
- `isActive` is true only when `entry.cutId == activeCutId`.
- If `activeCutId` is null, all entries have `isActive == false`.
- Empty tracks produce no entries.
- A project with no cuts returns an empty list.
```

Do not mutate project data.

Do not depend on Flutter.

Do not depend on `ProjectRepository`.

Do not depend on `HistoryManager`.

Do not depend on UI widgets.

---

## Part A: Add Cut List Helper

Add:

```text
lib/src/controllers/cut_list_helpers.dart
```

or equivalent.

The file should import only the model classes it needs.

Allowed imports are expected to be similar to:

```dart
import '../models/cut_id.dart';
import '../models/project.dart';
import '../models/track.dart';
import '../models/track_id.dart';
```

Add `CutListEntry` and `cutListEntriesFor`.

Keep the helper pure and small.

Do not add a controller with state.

Do not add ChangeNotifier, Stream, Provider, Riverpod, or Bloc.

---

## Part B: Add Cut List Helper Tests

Add:

```text
test/controllers/cut_list_helpers_test.dart
```

Required test coverage:

```text
1. Returns an empty list for a project with no tracks.
2. Returns an empty list for tracks with no cuts.
3. Returns cuts in project track/cut order.
4. Includes track id, track name, track index, track type, cut id, cut name, and cut index.
5. Marks the active cut when activeCutId is provided.
6. Marks no cuts active when activeCutId is null.
7. Marks no cuts active when activeCutId is not found.
8. Handles multiple tracks with multiple cuts.
9. Preserves audio/video track type in entries.
```

Use small pure model fixtures.

Do not use widget tests for this helper.

---

## Part C: Do Not Wire UI Yet

Do not update `HomePage` to render a cut list.

Do not add a Cut selector.

Do not add buttons, dropdowns, tabs, panels, menus, chips, or dialogs.

Do not change `EditingSessionState` unless a tiny import-free test need appears, but the preferred result is no change to session state.

This phase prepares the data shape only.

---

## Part D: Preserve Existing Behavior

Existing app behavior must remain unchanged.

The app should continue to:

```text
- create the same sample project
- resolve the same sample cut
- construct LayerController for the active cut
- construct TimelineController for the active cut
- pass the active cut to CanvasView
- show the same canvas/layer/timeline UI
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
lib/src/models/project.dart
lib/src/models/track.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
lib/src/models/track_id.dart
lib/src/controllers/active_cut_helpers.dart
lib/src/controllers/editing_session_state.dart
test/controllers/active_cut_helpers_test.dart
test/controllers/editing_session_state_test.dart
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
- Cut panel
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
- New toolbar actions
- New dialogs
- New menu items
- New visible UI controls
```

Do not implement Phase 35 or later.

---

## Allowed Changes

Allowed:

```text
- Add a small CutListEntry read model.
- Add a pure cutListEntriesFor helper.
- Add unit tests for cut list read model behavior.
```

Preferred result:

```text
No existing runtime behavior changes.
No HomePage changes.
No UI changes.
```

---

## Expected User-Visible Behavior

After Phase 34:

```text
The app should look and behave the same as before.
```

The change is internal:

```text
The project now has a tested pure helper for future Cut list UI data.
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

After merging and pulling Phase 34, run the app manually and verify:

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
14. No Cut list UI was added.
15. No Storyboard Panel was added.
16. No new visible buttons, dropdowns, tabs, or dialogs were added.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Cut list read model/helper exists.
2. The helper returns stable project-order cut entries.
3. Entries include track/cut identity and display information.
4. Entries can mark the active cut.
5. Helper tests cover empty project, empty tracks, multiple tracks, multiple cuts, active cut, missing active cut, and track type.
6. No Cut switching UI is added.
7. No Cut list UI is added.
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
Implemented Phase 34 Cut List Read Model MVP.

Changed:
- Added CutListEntry read model.
- Added cutListEntriesFor helper.
- Added cut list helper unit tests.
- Existing user-visible behavior is unchanged.
- No Cut switching UI or Cut list UI was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_34_Codex_Task.md` and implement Phase 34 only. Add a small pure Cut list read model/helper that enumerates project cuts in stable order and can mark the active cut. Add unit tests. Do not add Cut switching UI, Cut list UI, Storyboard Panel, repository API redesign, command API redesign, JSON schema changes, save/load changes, undo/redo changes, timeline behavior changes, canvas behavior changes, Provider/Riverpod/Bloc/ChangeNotifier, new visible UI controls, or Phase 35+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
