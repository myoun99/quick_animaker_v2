# Phase 49 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 49: Cut Duplicate Deep Copy Helper MVP.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 48 are complete.

Recent completed work includes:

- TimelinePanel-based timeline/cell editing UI
- New Frame / Blank X / Mark ● / Rename / Delete / Exposure +/- actions
- Timeline marks
- X/null exposure
- Linked Frame Copy/Paste MVP
- Same-layer linked paste using shared `FrameId`
- Linked frames share drawing material/source but do not share exposure duration
- Exposure +/- operates on the selected authored timeline entry, not globally by `FrameId`
- Rename Frame conflict policy:
    - Same frame name means same material
    - Same-layer duplicate independent `FrameId`s with the same non-empty name should not be allowed
    - Conflict offers Link / Cancel only
    - Rename-only is intentionally not offered
- Compact production-tool-like timeline UI
- Product direction notes
- Cut / Conte direction notes
- Cut management policy notes
- Cut management command design notes
- Minimal Cut switching between existing sample cuts
- Active-cut edit safety regression tests
- Cut switching UX polish
- Cut deletion fallback helper
- Default Cut creation helper
- ProjectRepository Cut insert/remove/rename primitives
- Undoable Create Cut command
- Undoable Rename Cut command
- Undoable Delete Cut command

Read these documents before making changes:

- `docs/Architecture.md`
- `docs/ImplementationPlan.md`
- `docs/Product_Direction_Notes.md`
- `docs/Cut_Structure_Preparation.md`
- `docs/Cut_Structure_Audit.md`
- `docs/Active_Cut_State_Design.md`
- `docs/Id_Scope_Decision.md`
- `docs/Cut_Conte_Direction_Notes.md`
- `docs/Cut_Management_Policy.md`
- `docs/Cut_Management_Command_Design.md`
- `docs/Phase_42_Codex_Task.md`
- `docs/Phase_43_Codex_Task.md`
- `docs/Phase_44_Codex_Task.md`
- `docs/Phase_45_Codex_Task.md`
- `docs/Phase_46_Codex_Task.md`
- `docs/Phase_47_Codex_Task.md`
- `docs/Phase_48_Codex_Task.md`

This task implements only Phase 49.

---

## Scope

Implement only Phase 49: Cut Duplicate Deep Copy Helper MVP.

This is a small pure helper and unit-test phase.

The goal is to add a tested helper that creates an independent duplicate of a Cut.

This phase should not add Cut duplicate UI.

This phase should not add Cut management panel.

This phase should not add an undoable Cut duplicate command yet.

This phase should not add Cut reorder behavior.

This phase should not implement Linked Cut.

This phase should not implement Linked Layer.

This phase should not implement cross-cut linked paste.

This phase should not add project-level material pool.

This phase should not change save/load schema.

This phase should not add Conte Panel or Conte Layer.

---

## Main Goal

Add a pure helper that can create an independent deep copy of a source Cut.

Expected behavior:

- Source Cut is not mutated.
- Duplicate Cut receives a caller-provided new `CutId`.
- Duplicate Cut receives a caller-provided new name.
- Duplicate Layers receive caller-provided new `LayerId`s.
- Duplicate Frames receive caller-provided new `FrameId`s.
- Frame references inside layer timelines are remapped to the new `FrameId`s.
- Frame names are copied.
- Frame durations are copied.
- Stroke/material content is copied as independent content for this MVP.
- Timeline placement is copied as independent authored placement.
- Blank/X exposures remain blank/X exposures.
- Marks remain marks.
- Canvas size is copied.
- Cut duration is copied.
- The helper does not insert the duplicate into a Project.
- The helper does not mutate Project.
- The helper does not update activeCutId.
- The helper does not create undo history.

No UI should call this helper yet.

---

## Important Product Policy

Cut duplicate MVP policy from `docs/Cut_Management_Policy.md`:

- Initial Cut duplicate should be an independent deep copy.
- A duplicated Cut should receive a new `CutId`.
- Duplicated layers should receive new `LayerId`s.
- Duplicated frames should receive new `FrameId`s.
- The duplicate should not be linked by default.
- Timeline placement in the duplicate should be copied as independent authored placement.
- Strokes/material content may be copied as independent content for the MVP.

Important:

- Do not implement Linked Cut.
- Do not implement Linked Layer.
- Do not implement cross-cut linked frames.
- Do not introduce project-level material/source pool.
- Do not share timeline placement.
- Do not share active selection state.

---

## Important Design Boundary

This phase should implement pure duplication logic, not command-level behavior and not UI behavior.

The helper may depend on model classes such as:

- `Cut`
- `CutId`
- `Layer`
- `LayerId`
- `Frame`
- `FrameId`
- `TimelineExposure`
- `Stroke`

The helper should not depend on:

- Flutter widgets
- `HomePage`
- `CutListBar`
- `ProjectRepository`
- `HistoryManager`
- `EditingSessionState`
- save/load services
- renderer
- canvas UI
- brush engine

Reason:

- This helper should only produce a duplicated `Cut`.
- Future duplicate command can insert the returned Cut through `ProjectRepository`.
- Future UI can call a future command, not this helper directly.

---

## Files To Inspect

Inspect at least:

- `lib/src/models/cut.dart`
- `lib/src/models/cut_id.dart`
- `lib/src/models/layer.dart`
- `lib/src/models/layer_id.dart`
- `lib/src/models/frame.dart`
- `lib/src/models/frame_id.dart`
- `lib/src/models/stroke.dart`
- `lib/src/models/timeline_exposure.dart`
- `lib/src/controllers/default_cut_helpers.dart`
- `lib/src/services/commands/create_cut_command.dart`
- `lib/src/services/commands/delete_cut_command.dart`
- `test/controllers/default_cut_helpers_test.dart`
- `test/services/create_cut_command_test.dart`
- `test/services/delete_cut_command_test.dart`

Adapt file placement to the existing architecture.

---

## Recommended File

Preferred new helper file:

- `lib/src/controllers/cut_duplicate_helpers.dart`

Recommended test file:

- `test/controllers/cut_duplicate_helpers_test.dart`

If existing architecture prefers another focused helper location, use that style.

---

## Required Helper API Direction

Add a helper equivalent to:

`duplicateCutAsIndependentCopy(...)`

Recommended conceptual signature:

- source `Cut`
- new `CutId`
- new Cut name
- layer id mapping
- frame id mapping

The exact Dart signature may be adapted to project style.

Recommended value types if useful:

- `LayerDuplicateIdMapping`
- `FrameDuplicateIdMapping`
- `CutDuplicateIdMapping`

Keep any new value types small and focused.

The helper must not generate IDs.

The caller must provide all new IDs.

---

## Required ID Policy

Do not add global ID generation.

Do not add random IDs.

Do not add UUID package.

Do not add repository-based ID allocator.

Do not add timestamp-based IDs.

Caller must provide:

- new duplicate `CutId`
- new `LayerId` for every source Layer
- new `FrameId` for every source Frame that needs a new independent copy

If required mappings are missing, the helper should throw `StateError` or `ArgumentError`.

Choose error type consistent with existing project style.

---

## Layer Duplication Requirements

For each source Layer:

- Duplicate layer should use the mapped new `LayerId`.
- Duplicate layer name should be copied.
- Duplicate layer visibility should be copied.
- Duplicate layer opacity should be copied.
- Duplicate layer marks should be copied if marks exist on Layer model.
- Duplicate layer timeline should be copied with remapped frame references.
- Duplicate layer frames should be copied with remapped `FrameId`s.
- Duplicate layer object should not be identical to source layer object if equality/identity can be tested reasonably.

Do not create linked layers.

Do not preserve source `LayerId`.

---

## Frame Duplication Requirements

For each source Frame:

- Duplicate frame should use the mapped new `FrameId`.
- Duplicate frame name should be copied.
- Duplicate frame duration should be copied.
- Duplicate frame strokes/material content should be copied as independent content for MVP.
- Duplicate frame should not preserve source `FrameId`.

If the Frame model has additional fields, copy them unless doing so would preserve identity IDs incorrectly.

Do not link frames across cuts in this phase.

Do not create shared project-level material.

---

## Timeline Exposure Duplication Requirements

For each Layer timeline entry:

- Drawing exposures referencing old `FrameId`s should reference the mapped new `FrameId`s.
- Blank/X/null exposures should remain blank/X/null exposures.
- Timeline keys/positions should be copied exactly.
- Authored exposure placement should be copied as independent placement.
- Marks should be copied if they are part of the layer/timeline model.
- Selection state should not be copied if selection state exists outside the model.

If a timeline references a `FrameId` that is not present in source frames and no mapping is provided, throw an error.

Do not allow timeline entries in the duplicate to reference source `FrameId`s.

---

## Cut Duplication Requirements

The duplicated Cut should:

- Use the caller-provided new `CutId`.
- Use the caller-provided new Cut name.
- Copy source Cut duration.
- Copy source Cut canvas size.
- Copy source Cut layers using new `LayerId`s.
- Copy source layer frames using new `FrameId`s.
- Copy source layer timelines with remapped frame references.
- Preserve layer order.
- Preserve frame order.
- Preserve timeline placement.
- Preserve blank/X/null entries.
- Preserve marks if present in the model.
- Not share CutId, LayerId, or FrameId with the source.
- Not mutate the source Cut.

---

## Error Behavior

Required behavior:

- Missing layer id mapping should throw.
- Missing frame id mapping should throw.
- Timeline reference to a source frame without mapping should throw.
- Duplicate should not be partially returned on error.
- Source Cut should remain unchanged on error.
- Empty layer list should be supported.
- Empty frame list should be supported.
- Empty timeline should be supported.

Do not over-engineer validation beyond what is necessary for safe duplication.

---

## Part A: Add Pure Helper

Add the cut duplicate helper.

The helper should:

- accept a source Cut
- accept caller-provided new IDs
- return a duplicated Cut
- remap LayerIds
- remap FrameIds
- remap timeline drawing references
- copy blank/X/null exposures
- copy duration/canvas size/name as specified
- avoid ProjectRepository
- avoid HistoryManager
- avoid EditingSessionState
- avoid UI dependencies

Keep it small and testable.

---

## Part B: Add Unit Tests

Add helper tests.

Required test coverage:

1. duplicates Cut with provided new CutId.
2. duplicates Cut with provided new name.
3. copies Cut duration.
4. copies Cut canvas size.
5. preserves layer order.
6. remaps every LayerId.
7. copies layer names.
8. copies layer visibility/opacity/marks if applicable.
9. preserves frame order within layers.
10. remaps every FrameId.
11. copies frame names.
12. copies frame durations.
13. copies stroke/material content as independent content where testable.
14. remaps drawing timeline exposures to new FrameIds.
15. preserves blank/X/null exposures.
16. preserves timeline positions.
17. does not leave duplicate timeline references pointing at source FrameIds.
18. supports empty layers.
19. supports layers with empty frames.
20. supports layers with empty timeline.
21. throws when a LayerId mapping is missing.
22. throws when a FrameId mapping is missing.
23. throws when timeline references an unmapped FrameId.
24. does not mutate source Cut.
25. does not require ProjectRepository.
26. does not update activeCutId.

Use unit tests, not widget tests.

Do not require Android Studio manual tests for this helper-only phase.

---

## Part C: Do Not Wire Command Or UI

Do not update:

- `lib/src/ui/home_page.dart`
- `lib/src/ui/cut/cut_list_bar.dart`

Do not add:

- Duplicate Cut command
- Duplicate Cut button
- Delete Cut button
- Rename Cut button
- New Cut button
- Cut management panel
- dialogs
- menus
- toolbar actions
- shortcuts

This helper should be available for a future Duplicate Cut command but not used by the app yet.

---

## Part D: Preserve Existing Behavior

The app should continue to:

- show Cut 1 and Cut 2
- keep Cut 1 active by default
- switch between Cut 1 and Cut 2
- keep active-cut editing scoped correctly

No user-visible behavior should change.

---

## Policy Requirements To Preserve

From `docs/Cut_Management_Policy.md`:

- Cut duplicate MVP should be an independent deep copy.
- Duplicated Cut should receive new `CutId`.
- Duplicated Layers should receive new `LayerId`s.
- Duplicated Frames should receive new `FrameId`s.
- The duplicate should not be linked by default.
- Timeline placement should be copied as independent authored placement.
- Linked Cut is long-term only.

From `docs/Cut_Management_Command_Design.md`:

- Future Cut duplicate MVP should be an independent deep copy.
- It should not create Linked Cut.
- It should not create Linked Layer.
- It should not create cross-cut linked frames.
- Timeline placement should be copied as independent authored placement.
- Strokes/material should be copied as independent content for the MVP.

From linked-frame policy:

- Linked frames share material/source only.
- Timeline placement remains independent.
- Cross-cut linked paste is not implemented.

Do not weaken these policies.

---

## Very Important Restrictions

Do not implement any of the following:

- Cut duplicate UI
- Cut duplicate command
- Cut delete UI
- Cut rename UI
- Cut create UI
- Cut reorder UI
- Cut management panel
- Undoable Cut duplicate command
- Undoable Cut reorder command
- Undoable active cut switch
- Save/load `lastActiveCutId`
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
- Global `FrameId` refactor
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

Do not implement Phase 50 or later.

---

## Allowed Changes

Allowed:

- Add a pure independent Cut duplicate helper.
- Add small focused mapping value types if needed.
- Add unit tests for duplication/remapping behavior.

Preferred result:

- No existing user-visible behavior changes.
- No `HomePage` changes.
- No UI changes.
- No repository mutation changes unless absolutely necessary.
- No command changes.
- No JSON schema changes.
- No save/load changes.

---

## Expected User-Visible Behavior

After Phase 49:

The app should look and behave exactly the same as Phase 48.

The change is internal test-covered helper support for future Cut duplicate command.

---

## Tests / Validation

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`

Do not run `dart format` on Markdown files.

---

## Manual Check In Android Studio

Manual app check is optional for this helper-only phase.

If performed, verify:

1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No Cut create/delete/rename/duplicate UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.

---

## Completion Criteria

This phase is complete only when:

1. Cut duplicate helper exists.
2. Helper returns a duplicated Cut.
3. Duplicate Cut uses caller-provided new `CutId`.
4. Duplicate Cut uses caller-provided new name.
5. Duplicate Cut copies duration and canvas size.
6. Duplicate Cut preserves layer order.
7. Duplicate layers use new mapped `LayerId`s.
8. Duplicate frames use new mapped `FrameId`s.
9. Timeline drawing exposures are remapped to new `FrameId`s.
10. Blank/X/null exposures are preserved.
11. Timeline positions are preserved.
12. Source Cut is not mutated.
13. Missing LayerId mapping throws.
14. Missing FrameId mapping throws.
15. No ID generator is added.
16. No Cut duplicate command is added.
17. No Cut duplicate UI is added.
18. No Cut management panel is added.
19. No JSON schema changes are made.
20. No save/load changes are made.
21. Existing user-visible behavior remains unchanged.
22. `dart format lib test` passes.
23. `flutter analyze` passes.
24. `flutter test` passes.
25. `git status` is clean after commit.

---

## Suggested Final Response From Codex

After completing the task, summarize:

Implemented Phase 49 Cut Duplicate Deep Copy Helper MVP.

Changed:

- Added pure independent Cut duplicate helper.
- Helper duplicates Cut with caller-provided CutId.
- Helper remaps LayerIds and FrameIds.
- Helper remaps timeline drawing exposures.
- Helper preserves independent timeline placement, blank/X/null exposures, duration, and canvas size.
- Added tests for duplication/remapping behavior.
- Existing user-visible behavior is unchanged.
- No Cut duplicate command or UI was added.

Validation:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_49_Codex_Task.md` and implement Phase 49 only.

Add a pure helper that creates an independent deep copy of a Cut for future Cut duplicate command work. The duplicate must use caller-provided new `CutId`, mapped new `LayerId`s, and mapped new `FrameId`s. It must remap timeline drawing exposures to the new `FrameId`s, preserve blank/X/null exposures and timeline positions, copy duration and canvas size, and not mutate the source Cut.

Do not add ID generation.

Do not add Cut duplicate command, Cut duplicate UI, Cut management panel, Linked Cut, Linked Layer, cross-cut linked paste, project-level material pool, save/load changes, JSON schema changes, Conte Panel, or Phase 50+ work.

Run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`
- `git status`