# Phase 45 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 45: Cut Repository Mutation Primitives MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 44 are complete.

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
* Cut management command design notes
* Minimal Cut switching between existing sample cuts
* Active-cut edit safety regression tests
* Cut switching UX polish
* Cut deletion fallback helper
* Default Cut creation helper

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
docs/Cut_Management_Command_Design.md
docs/Phase_41_Codex_Task.md
docs/Phase_42_Codex_Task.md
docs/Phase_43_Codex_Task.md
docs/Phase_44_Codex_Task.md
```

This task implements only Phase 45.

---

## Scope

Implement only:

```text
Phase 45: Cut Repository Mutation Primitives MVP
```

This is a small repository/service primitive and unit-test phase.

The goal is to add minimal, tested project-data mutation primitives that future Cut management commands can use.

This phase should not add Cut management UI.

This phase should not add undoable commands yet.

This phase should not wire Cut create/delete/rename into `HomePage`.

This phase should not add save/load schema changes.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add small repository-level or service-level functions for future Cut management commands:

```text
- insert a Cut into a Track
- remove a Cut from a Track
- rename a Cut
```

These primitives should mutate project data safely through existing project mutation patterns.

They should be small and well tested.

They should not know about Flutter widgets.

They should not directly rebuild controllers.

They should not directly update `EditingSessionState`.

They should not manage undo/redo by themselves.

Future commands will coordinate these primitives with `HistoryManager`, `EditingSessionState`, and controller retargeting.

---

## Preferred Location

Inspect the current repository/service architecture before choosing the exact location.

Preferred file if consistent with existing style:

```text
lib/src/services/project_repository.dart
```

Alternative acceptable file if the existing repository should stay smaller:

```text
lib/src/services/cut_repository_helpers.dart
```

or:

```text
lib/src/controllers/cut_mutation_helpers.dart
```

Prefer `ProjectRepository` methods if existing project mutations already live there.

Prefer a helper file only if adding methods to `ProjectRepository` would conflict with current architecture.

---

## Required Mutation Primitives

Add the equivalent of the following behavior.

### Insert Cut

Recommended method shape:

```dart
void insertCut({
  required TrackId trackId,
  required Cut cut,
  int? index,
})
```

Required behavior:

```text
- Inserts `cut` into the target Track.
- If `index` is null, append to the end of the Track.
- If `index` is provided, insert at that index.
- Throw StateError if `trackId` is not found.
- Throw RangeError if index is out of range.
- Do not enforce unique Cut names.
- Do not generate IDs.
- Do not change activeCutId.
- Do not create undo history by itself.
```

### Remove Cut

Recommended method shape:

```dart
Cut removeCut({
  required CutId cutId,
})
```

or:

```dart
Cut removeCut({
  required TrackId trackId,
  required CutId cutId,
})
```

Choose the shape that best matches existing architecture.

Required behavior:

```text
- Removes the Cut identified by CutId.
- Returns the removed Cut so future commands can undo by reinserting it.
- Preserve enough behavior for tests to know it was removed from its original Track.
- Throw StateError if the Cut is not found.
- Do not choose active cut fallback here.
- Do not call cutDeletionFallbackFor here.
- Do not update activeCutId.
- Do not create default Cut here.
- Do not create undo history by itself.
```

If the method does not include `trackId`, it should find the Cut by project-wide CutId.

Current ID policy treats IDs as project-wide unique.

### Rename Cut

Recommended method shape:

```dart
void renameCut({
  required CutId cutId,
  required String name,
})
```

Required behavior:

```text
- Updates the Cut display name.
- Uses CutId, not current name.
- Allows duplicate Cut names.
- Allows empty name only if existing model conventions allow empty names.
- Throw StateError if CutId is not found.
- Do not change CutId.
- Do not change layers, frames, timeline, canvas size, or duration.
- Do not change activeCutId.
- Do not create undo history by itself.
```

If there is an existing convention for rejecting empty names, follow existing project style. Do not invent complex validation in this phase.

---

## Optional Helper For Original Position

Future undoable Cut delete needs to restore the Cut to its original location.

If useful, add a small value type:

```dart
class CutLocation {
  const CutLocation({
    required this.trackId,
    required this.cutIndex,
  });

  final TrackId trackId;
  final int cutIndex;
}
```

and a helper/method:

```dart
CutLocation locationOfCut(CutId cutId)
```

or return both removed cut and location from remove.

Only add this if it stays small and useful.

Do not over-engineer.

---

## Important Design Boundary

These primitives should mutate Project data only.

They should not coordinate the full user action.

Do not implement command-level behavior yet.

For example, `removeCut` should not do this:

```text
- decide fallback active cut
- update EditingSessionState
- create a new default Cut
- rebuild controllers
- push to HistoryManager
```

Those are future command responsibilities.

This phase only provides project mutation building blocks.

---

## Part A: Add Repository/Mutation Primitives

Inspect:

```text
lib/src/services/project_repository.dart
```

and existing tests around project repository.

Add the smallest consistent implementation for:

```text
- insert cut
- remove cut
- rename cut
```

Keep methods deterministic and simple.

Use immutable-copy style if the repository currently uses immutable updates.

Use in-place mutation only if that is already the existing repository style.

Do not perform broad refactors.

---

## Part B: Add Unit Tests

Add or update tests.

Preferred file:

```text
test/services/project_repository_test.dart
```

Alternative if repository tests are elsewhere:

```text
test/controllers/cut_mutation_helpers_test.dart
```

Required test coverage:

```text
1. insertCut appends a Cut when index is null.
2. insertCut inserts at a specific index.
3. insertCut throws StateError for missing TrackId.
4. insertCut throws RangeError for invalid index.
5. insertCut allows duplicate Cut names.
6. removeCut removes the target Cut by CutId.
7. removeCut returns the removed Cut.
8. removeCut throws StateError for missing CutId.
9. removeCut does not create fallback Cut.
10. removeCut does not remove other Cuts.
11. renameCut changes only the Cut name.
12. renameCut allows duplicate Cut names.
13. renameCut throws StateError for missing CutId.
14. renameCut does not change CutId, layers, frames, timeline, duration, or canvas size.
```

If `CutLocation` is added, also test:

```text
15. locationOfCut returns the correct TrackId and cut index.
16. removeCut can preserve enough location data for future undo.
```

Use small pure fixtures.

Avoid widget tests.

---

## Part C: Do Not Wire Commands Or UI

Do not update:

```text
lib/src/ui/home_page.dart
```

except if absolutely necessary, which should not be necessary.

Do not update `CutListBar`.

Do not add buttons, dialogs, menus, toolbar actions, shortcuts, or panels.

Do not connect these primitives to `HistoryManager`.

Do not connect these primitives to `EditingSessionState`.

Do not rebuild controllers in these primitives.

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
- Cut names are display labels.
- Duplicate Cut names are allowed.
- Cut rename should not be blocked by duplicate Cut names.
- Cut deletion fallback is previous → next → new default Cut, but fallback is future command behavior.
```

From `docs/Cut_Management_Command_Design.md`:

```text
- ProjectRepository owns project data mutation.
- EditingSessionState owns activeCutId.
- HistoryManager records volatile undoable/redoable command history.
- Repository mutation primitives should not themselves coordinate session state, history, or controller retargeting.
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
docs/Cut_Management_Command_Design.md
lib/src/services/project_repository.dart
lib/src/controllers/cut_deletion_helpers.dart
lib/src/controllers/default_cut_helpers.dart
lib/src/models/project.dart
lib/src/models/track.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
lib/src/models/track_id.dart
test/services/
test/controllers/
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut create UI
- Cut delete UI
- Cut rename UI
- Cut duplicate UI
- Cut reorder UI
- Cut management panel
- Undoable Cut create command
- Undoable Cut delete command
- Undoable Cut rename command
- Undoable Cut duplicate command
- Undoable Cut reorder command
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
- Global FrameId refactor
- ID generation refactor
- JSON schema changes
- Save/load format changes
- Undo/Redo redesign
- Timeline behavior redesign
- Timeline placement sharing
- Canvas painting behavior redesign
- Canvas layout redesign
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier
```

Do not implement Phase 46 or later.

---

## Allowed Changes

Allowed:

```text
- Add small Cut mutation primitives to ProjectRepository or a focused helper/service.
- Add optional CutLocation value type if useful.
- Add unit tests for insert/remove/rename behavior.
```

Preferred result:

```text
No existing user-visible behavior changes.
No HomePage changes.
No UI changes.
No JSON schema changes.
No undo/redo command changes.
```

---

## Expected User-Visible Behavior

After Phase 45:

```text
The app should look and behave exactly the same as Phase 44.
```

The change is internal test-covered repository mutation support for future Cut management commands.

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

Manual app check is optional for this internal primitive phase.

If performed, verify:

```text
1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No Cut create/delete/rename UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Cut insert primitive exists.
2. Cut remove primitive exists.
3. Cut rename primitive exists.
4. Insert can append and insert at index.
5. Insert allows duplicate Cut names.
6. Remove returns the removed Cut.
7. Remove does not choose active-cut fallback.
8. Remove does not create a default Cut.
9. Rename uses CutId and allows duplicate Cut names.
10. Rename changes only the Cut display name.
11. Missing TrackId/CutId cases throw appropriate errors.
12. Unit tests cover required behavior.
13. No Cut management UI is added.
14. No undoable command is added.
15. No session-state coordination is added.
16. No JSON schema changes are made.
17. Existing user-visible behavior remains unchanged.
18. dart format lib test passes.
19. flutter analyze passes.
20. flutter test passes.
21. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 45 Cut Repository Mutation Primitives MVP.

Changed:
- Added small Cut insert/remove/rename mutation primitives.
- Added tests for Cut insertion, removal, rename, duplicate-name allowance, and missing-id errors.
- Existing user-visible behavior is unchanged.
- No Cut management UI was added.
- No undoable Cut command was added.

Validation:
- dart format lib test
- flutter analyze
- flutter test
- git status
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_45_Codex_Task.md` and implement Phase 45 only. Add small repository/service-level Cut mutation primitives for insert, remove, and rename. These should mutate project data only and should not update EditingSessionState, HistoryManager, controllers, UI, save/load, or undo/redo. Cut names may be duplicated. Remove should return the removed Cut and should not choose active-cut fallback or create a default Cut. Add unit tests. Do not add Cut management UI, undoable commands, JSON schema changes, Conte Panel, or Phase 46+ work. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
