# Phase 42 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 42: Cut Deletion Fallback Helper MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 41 are complete.

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
* Cut / Conte direction notes
* Cut management policy notes
* Minimal Cut switching between existing sample cuts
* Active-cut edit safety regression tests
* Cut switching UX polish

Read these documents before making changes:

```text
docs/Architecture.md
docs/ImplementationPlan.md
docs/Product_Direction_Notes.md
docs/Cut_Structure_Preparation.md
docs/Cut_Structure_Audit.md
docs/Active_Cut_State_Design.md
docs/Id_Scope_Decision.md
docs/Cut_Conte_Direction_Notes.md
docs/Cut_Management_Policy.md
docs/Phase_34_Codex_Task.md
docs/Phase_35_Codex_Task.md
docs/Phase_36_Codex_Task.md
docs/Phase_37_Codex_Task.md
docs/Phase_38_Codex_Task.md
docs/Phase_39_Codex_Task.md
docs/Phase_40_Codex_Task.md
docs/Phase_41_Codex_Task.md
```

This task implements only Phase 42.

---

## Scope

Implement only:

```text
Phase 42: Cut Deletion Fallback Helper MVP
```

This is a small pure helper and test phase.

The goal is to prepare for future Cut delete behavior by adding a tested helper that determines which Cut should become active after deleting a Cut.

This phase should not add Cut delete UI.

This phase should not actually delete Cuts from the app UI.

This phase should not add Cut create/delete/rename/duplicate/reorder commands.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a small pure helper that can answer:

```text
If this Cut is deleted, what should the active Cut become?
```

Policy from `docs/Cut_Management_Policy.md`:

```text
When deleting the active Cut:
1. Prefer the previous Cut in project order.
2. If no previous Cut exists, use the next Cut.
3. If no Cut remains, create a new default empty Cut.
```

Because this phase should not create or delete actual Cuts yet, the helper should return a decision object rather than mutate the Project.

---

## Recommended File

Add:

```text
lib/src/controllers/cut_deletion_helpers.dart
test/controllers/cut_deletion_helpers_test.dart
```

Alternative acceptable names:

```text
lib/src/controllers/cut_management_helpers.dart
test/controllers/cut_management_helpers_test.dart
```

Prefer `cut_deletion_helpers.dart` if the file stays focused on delete fallback.

---

## Required Decision Model

Add a small immutable decision/value type.

Recommended shape:

```dart
enum CutDeletionFallbackKind {
  useExistingCut,
  createDefaultCut,
}
```

and:

```dart
class CutDeletionFallbackDecision {
  const CutDeletionFallbackDecision.useExistingCut(this.cutId)
      : kind = CutDeletionFallbackKind.useExistingCut;

  const CutDeletionFallbackDecision.createDefaultCut()
      : kind = CutDeletionFallbackKind.createDefaultCut,
        cutId = null;

  final CutDeletionFallbackKind kind;
  final CutId? cutId;
}
```

Adapt naming to project style.

The decision should be easy for a future command to consume.

---

## Required Helper Behavior

Add a helper similar to:

```dart
CutDeletionFallbackDecision cutDeletionFallbackFor(
  Project project, {
  required CutId deletingCutId,
})
```

Required behavior:

```text
- Treat project cut order as the order produced by project.tracks, then each track's cuts.
- If deletingCutId is not found, throw StateError.
- If there is a previous cut before deletingCutId in project order, return useExistingCut(previousCutId).
- If there is no previous cut but there is a next cut, return useExistingCut(nextCutId).
- If deletingCutId is the only cut in the project, return createDefaultCut().
- Empty tracks should be ignored.
- Multiple tracks should be handled in stable project order.
```

Important:

```text
The helper should not mutate Project.
The helper should not create a new Cut.
The helper should only return the decision.
```

---

## Optional Helper

If useful, add a small flattening helper:

```dart
List<CutId> cutIdsInProjectOrder(Project project)
```

or reuse existing `cutListEntriesFor`.

Preferred:

```text
Reuse cutListEntriesFor if it keeps the logic simple and consistent.
```

But avoid unnecessary coupling if a direct small helper is clearer.

---

## Part A: Add Pure Helper

Add:

```text
lib/src/controllers/cut_deletion_helpers.dart
```

The file should:

```text
- Import only model/helper classes it needs.
- Avoid Flutter imports.
- Avoid UI dependencies.
- Avoid ProjectRepository dependency.
- Avoid HistoryManager dependency.
- Avoid command dependencies.
- Avoid save/load dependencies.
```

Allowed imports are expected to be similar to:

```dart
import '../models/cut_id.dart';
import '../models/project.dart';
```

and optionally:

```dart
import 'cut_list_helpers.dart';
```

Keep implementation small.

---

## Part B: Add Unit Tests

Add:

```text
test/controllers/cut_deletion_helpers_test.dart
```

Required tests:

```text
1. Deleting a middle cut falls back to the previous cut.
2. Deleting the first cut falls back to the next cut.
3. Deleting the last cut falls back to the previous cut.
4. Deleting the only cut returns createDefaultCut.
5. Deleting a cut from a later track can fall back to the previous cut from an earlier track if appropriate.
6. Deleting the first cut in a later track falls back to the previous track's last cut when that is previous in project order.
7. Empty tracks are ignored.
8. Missing deletingCutId throws StateError.
9. A project with no cuts and a missing deletingCutId throws StateError.
```

Use small pure model fixtures.

Do not use widget tests for this helper.

---

## Part C: Do Not Implement Cut Delete Yet

Do not update `HomePage` to delete Cuts.

Do not add buttons, menu items, shortcuts, toolbar actions, dialogs, or Cut management panel.

Do not mutate Project data.

Do not create actual default Cuts in production code.

This phase is only decision logic and tests.

---

## Part D: Preserve Existing Behavior

The app should continue to:

```text
- show Cut 1 and Cut 2
- keep Cut 1 active by default
- switch between Cut 1 and Cut 2
- keep active-cut editing scoped correctly
```

No user-visible behavior should change.

---

## Policy Requirements To Preserve

From `docs/Cut_Management_Policy.md`:

```text
- CutId is identity.
- Duplicate Cut names are allowed.
- Deleting active Cut should fall back previous → next → new default Cut.
- Deleting the last Cut should be allowed from user perspective, but should result in a new default editable Cut.
- Cut delete behavior is not implemented in this phase.
```

From linked-frame policy:

```text
- Linked frames share material/source only.
- Timeline placement remains independent.
- Cross-cut linked paste is not implemented.
```

Do not weaken these policies.

---

## Files To Inspect

Inspect at least:

```text
docs/Cut_Management_Policy.md
lib/src/controllers/cut_list_helpers.dart
lib/src/controllers/active_cut_helpers.dart
lib/src/models/project.dart
lib/src/models/track.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
test/controllers/cut_list_helpers_test.dart
test/controllers/active_cut_helpers_test.dart
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut delete behavior
- Cut delete UI
- Cut create behavior
- Cut rename behavior
- Cut duplicate behavior
- Cut reorder behavior
- Cut management panel
- Undoable active cut switch
- Save/load lastActiveCutId
- Persistent project open/close flow
- Linked Cut
- Linked Layer
- Cross-cut paste
- Cross-layer paste
- Project-level material pool
- Conte Panel
- Conte Layer
- Storyboard Panel
- Camera Layer
- Audio Layer behavior
- Layer type enum
- V/A track UI
- Repository API redesign
- Command API redesign
- JSON schema changes
- Save/load format changes
- Undo/Redo redesign
- Timeline behavior redesign
- Canvas behavior redesign
- Provider
- Riverpod
- Bloc
- ChangeNotifier
```

Do not implement Phase 43 or later.

---

## Allowed Changes

Allowed:

```text
- Add a pure Cut deletion fallback helper.
- Add a small decision value type.
- Add unit tests for fallback behavior.
```

Preferred result:

```text
No existing runtime behavior changes.
No HomePage changes.
No UI changes.
No JSON schema changes.
```

---

## Expected User-Visible Behavior

After Phase 42:

```text
The app should look and behave exactly the same as Phase 41.
```

The change is internal test-covered decision logic for future Cut delete behavior.

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

Manual app check is optional for this helper-only phase.

If performed, verify:

```text
1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No Cut delete UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Cut deletion fallback helper exists.
2. The helper does not mutate Project.
3. The helper returns previous Cut when deleting a non-first Cut.
4. The helper returns next Cut when deleting the first Cut.
5. The helper returns createDefaultCut when deleting the only Cut.
6. The helper handles multiple tracks in stable project order.
7. The helper ignores empty tracks.
8. The helper throws StateError for missing deletingCutId.
9. Unit tests cover the required fallback cases.
10. No Cut delete UI is added.
11. No Cut management panel is added.
12. No Project mutation command is added.
13. No JSON schema changes are made.
14. Existing user-visible behavior remains unchanged.
15. dart format lib test passes.
16. flutter analyze passes.
17. flutter test passes.
18. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 42 Cut Deletion Fallback Helper MVP.

Changed:
- Added a pure Cut deletion fallback decision helper.
- Added decision type for existing-cut fallback vs create-default-cut fallback.
- Added unit tests for previous/next/default fallback behavior.
- Existing user-visible behavior is unchanged.
- No Cut delete UI was added.
- No Cut management panel was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_42_Codex_Task.md` and implement Phase 42 only. Add a pure Cut deletion fallback helper that decides what active Cut should be used after deleting a Cut: previous Cut if available, otherwise next Cut, otherwise create-default-cut decision. Add unit tests. Do not mutate Project, do not implement Cut delete UI or commands, do not add Cut create/rename/duplicate/reorder, do not add Cut management panel, do not change JSON schema/save/load/undo/redo/timeline/canvas behavior, and do not implement Phase 43+. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
