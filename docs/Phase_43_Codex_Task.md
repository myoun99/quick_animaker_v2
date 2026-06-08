# Phase 43 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 43: Default Cut Creation Helper MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 42 are complete.

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
* Cut deletion fallback helper

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
docs/Phase_42_Codex_Task.md
```

This task implements only Phase 43.

---

## Scope

Implement only:

```text
Phase 43: Default Cut Creation Helper MVP
```

This is a small pure helper and unit-test phase.

The goal is to prepare for future Cut create/delete behavior by adding a tested helper that can construct a default empty Cut.

This phase should not add Cut create UI.

This phase should not add Cut delete UI.

This phase should not add Cut create/delete/rename/duplicate/reorder commands.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a small pure helper that can answer:

```text
What should a newly created default empty Cut look like?
```

This helper will be useful later for:

```text
- New project default Cut creation
- Last Cut deletion fallback
- Future Cut create command
```

The helper should construct a valid default `Cut` object but should not insert it into a `Project`.

---

## Recommended File

Add:

```text
lib/src/controllers/default_cut_helpers.dart
test/controllers/default_cut_helpers_test.dart
```

Alternative acceptable names:

```text
lib/src/controllers/cut_creation_helpers.dart
test/controllers/cut_creation_helpers_test.dart
```

Prefer `default_cut_helpers.dart` if the file stays focused on default Cut creation.

---

## Required Helper Behavior

Add a helper similar to:

```dart
Cut createDefaultCut({
  required CutId cutId,
  required String name,
  required LayerId layerId,
  CanvasSize canvasSize = const CanvasSize(width: 1280, height: 720),
})
```

Adapt the signature to existing model style if needed.

Required behavior:

```text
- Returns a new Cut.
- Uses the provided CutId.
- Uses the provided Cut name.
- Uses the provided LayerId for a default first layer.
- Uses the provided CanvasSize or a stable default CanvasSize.
- The Cut has duration 1 unless existing model conventions suggest otherwise.
- The Cut has exactly one default Layer.
- The default Layer name should be `Layer 1`.
- The default Layer should have empty frames.
- The default Layer should have empty timeline.
- The helper should not create strokes.
- The helper should not create initial authored frames.
- The helper should not mutate Project.
- The helper should not depend on Flutter.
- The helper should not depend on ProjectRepository.
- The helper should not depend on HistoryManager.
```

If the existing model requires additional fields, fill them with the minimal safe defaults already used elsewhere in the project.

---

## ID Policy

This helper should receive IDs from the caller.

Do not add a global ID generator in this phase.

Do not add timestamp/random ID generation in this phase.

Expected:

```text
Caller supplies:
- CutId
- LayerId
```

Do not introduce:

```text
- Project-wide ID allocator
- UUID package
- Random ID generation
- Counter service
- Repository-based ID generation
```

---

## Naming Policy

Default Cut name should be caller-provided.

Do not enforce uniqueness.

From `docs/Cut_Management_Policy.md`:

```text
- CutId is the real identity.
- Cut names are display labels.
- Duplicate Cut names are allowed.
```

The helper may be called with `Cut 1`, `Cut 2`, or any future UI-provided name.

Do not reject duplicate names.

---

## Part A: Add Pure Helper

Add:

```text
lib/src/controllers/default_cut_helpers.dart
```

The file should:

```text
- Import only model classes it needs.
- Avoid Flutter imports.
- Avoid UI dependencies.
- Avoid ProjectRepository dependency.
- Avoid HistoryManager dependency.
- Avoid command dependencies.
- Avoid save/load dependencies.
```

Allowed imports are expected to be similar to:

```dart
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
```

Keep implementation small.

---

## Part B: Add Unit Tests

Add:

```text
test/controllers/default_cut_helpers_test.dart
```

Required tests:

```text
1. Creates a Cut with the provided CutId.
2. Creates a Cut with the provided name.
3. Uses default canvas size when no canvas size is provided.
4. Uses custom canvas size when provided.
5. Creates exactly one default Layer.
6. Default Layer uses the provided LayerId.
7. Default Layer name is `Layer 1`.
8. Default Layer has empty frames.
9. Default Layer has empty timeline.
10. Cut duration is 1.
11. Helper does not mutate any Project because it does not accept a Project.
12. Allows duplicate names by construction because uniqueness is not checked here.
```

Use small pure model assertions.

Do not use widget tests.

---

## Part C: Do Not Wire UI Or Commands Yet

Do not update `HomePage` to create Cuts.

Do not add Cut create/delete buttons.

Do not add Cut management UI.

Do not connect this helper to `cutDeletionFallbackFor`.

Do not add project mutation commands.

Do not add repository APIs.

Do not add save/load schema changes.

This phase is only default Cut construction helper and tests.

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
- Deleting the last Cut should eventually create a new default empty Cut.
- Cut create/delete behavior is not implemented in this phase.
```

From `docs/Cut_Conte_Direction_Notes.md`:

```text
- Conte Panel is not implemented yet.
- Conte Layer is not implemented yet.
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
lib/src/controllers/cut_deletion_helpers.dart
lib/src/controllers/cut_list_helpers.dart
lib/src/models/cut.dart
lib/src/models/cut_id.dart
lib/src/models/layer.dart
lib/src/models/layer_id.dart
lib/src/models/canvas_size.dart
test/controllers/cut_deletion_helpers_test.dart
test/controllers/cut_list_helpers_test.dart
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Cut create behavior
- Cut create UI
- Cut delete behavior
- Cut delete UI
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

Do not implement Phase 44 or later.

---

## Allowed Changes

Allowed:

```text
- Add a pure default Cut creation helper.
- Add unit tests for default Cut creation behavior.
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

After Phase 43:

```text
The app should look and behave exactly the same as Phase 42.
```

The change is internal test-covered construction logic for future Cut create/delete behavior.

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
3. No Cut create/delete UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. Default Cut creation helper exists.
2. The helper returns a Cut.
3. The helper uses caller-provided CutId.
4. The helper uses caller-provided Cut name.
5. The helper uses caller-provided LayerId.
6. The helper creates exactly one default layer.
7. The default layer is named Layer 1.
8. The default layer has empty frames.
9. The default layer has empty timeline.
10. The default cut has duration 1.
11. The helper supports default and custom canvas sizes.
12. The helper does not mutate Project.
13. Unit tests cover required default Cut behavior.
14. No Cut create/delete UI is added.
15. No Cut management panel is added.
16. No Project mutation command is added.
17. No JSON schema changes are made.
18. Existing user-visible behavior remains unchanged.
19. dart format lib test passes.
20. flutter analyze passes.
21. flutter test passes.
22. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 43 Default Cut Creation Helper MVP.

Changed:
- Added a pure default Cut creation helper.
- Added unit tests for default Cut construction.
- Existing user-visible behavior is unchanged.
- No Cut create/delete UI was added.
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

Read `docs/Phase_43_Codex_Task.md` and implement Phase 43 only. Add a pure helper that constructs a default empty Cut from caller-provided CutId, name, LayerId, and optional CanvasSize. It should create one default Layer named `Layer 1` with empty frames and empty timeline, and should not mutate Project. Add unit tests. Do not add Cut create/delete UI or commands, do not add Cut management panel, do not change JSON schema/save/load/undo/redo/timeline/canvas behavior, and do not implement Phase 44+. Run `dart format lib test`, `flutter analyze`, `flutter test`, and `git status`.
