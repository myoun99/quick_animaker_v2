# Phase 44 Codex Task

## Task Title

Implement QuickAnimaker v2.1 Phase 44: Cut Management Command Design Notes.

---

## Context

This repository is the Flutter/Dart project for QuickAnimaker v2.1.

Phase 0 through Phase 43 are complete.

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
docs/Phase_40_Codex_Task.md
docs/Phase_41_Codex_Task.md
docs/Phase_42_Codex_Task.md
docs/Phase_43_Codex_Task.md
```

This task implements only Phase 44.

---

## Scope

Implement only:

```text
Phase 44: Cut Management Command Design Notes
```

This is a docs-only phase.

The goal is to document how future Cut create/delete/rename/duplicate/reorder commands should be designed before implementing them.

Do not change runtime code.

Do not change tests.

Do not implement any new UI.

---

## Main Goal

Add a new design document:

```text
docs/Cut_Management_Command_Design.md
```

The document should explain how future Cut management commands should interact with:

```text
- ProjectRepository
- HistoryManager
- EditingSessionState
- activeCutId
- controller rebuild / retarget behavior
- cutDeletionFallbackFor
- createDefaultCut
- volatile undo/redo history
- lastActiveCutId metadata
```

This phase should only document the design.

---

## Required Document

Create:

```text
docs/Cut_Management_Command_Design.md
```

Suggested sections:

```text
# Cut Management Command Design

## Purpose

## Current State

## Command Design Principles

## Cut Create Command Direction

## Cut Rename Command Direction

## Cut Delete Command Direction

## Last Cut Delete Direction

## Cut Duplicate Command Direction

## Cut Reorder Command Direction

## Active Cut Selection Command Direction

## History / Undo / Redo Direction

## Session State And Controller Retargeting

## Save / Load Metadata Direction

## What Not To Implement Yet

## Suggested Future Phase Order
```

Adapt headings if needed, but preserve the intent.

---

## Current State

Document the current implemented state:

```text
- Cut switching exists between sample Cut 1 and Cut 2.
- EditingSessionState owns activeCutId.
- HomePage currently rebuilds or retargets active-cut-scoped controllers when activeCutId changes.
- cutDeletionFallbackFor exists and returns a deletion fallback decision without mutating Project.
- createDefaultCut exists and creates a default empty Cut without inserting it into Project.
- Cut create/delete/rename/duplicate/reorder commands do not exist yet.
- Cut management UI does not exist yet.
- Undoable active cut switch does not exist yet.
- save/load lastActiveCutId does not exist yet.
```

---

## Command Design Principles

Document these principles:

```text
- Commands should keep Project data and EditingSessionState coordinated.
- Commands that mutate Project data should go through HistoryManager.
- Commands that mutate EditingSessionState may also go through HistoryManager when they are user-level editing actions.
- Active cut must never point to a missing Cut after a command completes.
- Commands should be small and testable.
- Commands should avoid UI dependencies.
- Commands should avoid Flutter widget dependencies.
- Commands should avoid introducing Provider/Riverpod/Bloc/ChangeNotifier.
- Commands should preserve linked-frame policies.
```

Clarify:

```text
ProjectRepository owns project data mutation.
EditingSessionState owns activeCutId.
HistoryManager records undoable/redoable command history.
```

---

## Cut Create Command Direction

Document future intended behavior:

```text
- Future Cut create should create a new default Cut.
- It should use createDefaultCut or equivalent.
- Caller or future ID allocator should provide CutId and LayerId.
- Initial implementation should likely insert the new Cut after the active Cut or at the end of the active track.
- The new Cut should probably become active after creation.
- Creation should be undoable/redoable.
- Undo should remove the created Cut and restore the previous active Cut.
- Redo should recreate/reinsert the Cut and make it active again.
```

Clarify:

```text
Do not implement Cut create in this phase.
Do not add an ID generator in this phase.
```

---

## Cut Rename Command Direction

Document future intended behavior:

```text
- Future Cut rename should change only the Cut display name.
- Cut names may be duplicated.
- Rename should not be blocked by duplicate Cut names.
- CutId remains the real identity.
- Cut rename should be undoable/redoable.
- Undo should restore the previous name.
- Redo should restore the new name.
```

Important distinction:

```text
Cut rename policy is different from Frame rename policy.
Frame rename can imply material identity/linking within the same layer.
Cut rename is only a display label change.
```

Do not weaken existing frame rename/material policy.

---

## Cut Delete Command Direction

Document future intended behavior:

```text
- Future Cut delete should remove the target Cut.
- If the deleted Cut is active, fallback should use cutDeletionFallbackFor.
- Fallback order is previous Cut, then next Cut, then create default Cut.
- If fallback decision is useExistingCut, activeCutId should become that CutId.
- If fallback decision is createDefaultCut, command should create and insert a new default Cut, then make it active.
- Active-cut-scoped controllers should be rebuilt or retargeted after activeCutId changes.
- Delete should be undoable/redoable.
```

Undo/redo direction:

```text
- Undo should restore the deleted Cut at its original position.
- Undo should restore activeCutId appropriately.
- Redo should delete it again and apply fallback again.
```

Clarify:

```text
Do not implement Cut delete in this phase.
```

---

## Last Cut Delete Direction

Document:

```text
- Deleting the last Cut should be allowed from the user's perspective.
- The command should produce a valid Project with one new default empty Cut.
- This should use createDefaultCut or equivalent.
- Undo should restore the original last Cut and remove the auto-created default Cut if appropriate.
- Redo should delete the original Cut again and recreate/apply the default Cut fallback.
```

This is design only.

---

## Cut Duplicate Command Direction

Document future MVP behavior:

```text
- Future Cut duplicate MVP should be an independent deep copy.
- The duplicated Cut should receive a new CutId.
- Duplicated Layers should receive new LayerIds.
- Duplicated Frames should receive new FrameIds.
- It should not create Linked Cut.
- It should not create Linked Layer.
- It should not create cross-cut linked frames.
- Timeline placement should be copied as independent authored placement.
- Strokes/material should be copied as independent content for the MVP.
- The duplicate should probably be inserted after the source Cut.
- The duplicate should probably become active.
- Duplicate should be undoable/redoable.
```

Clarify:

```text
Linked Cut is a long-term direction only.
```

---

## Cut Reorder Command Direction

Document future intended behavior:

```text
- Future Cut reorder should change the order of Cuts inside a Track or across Tracks if later supported.
- Reorder should be based on CutId, not Cut name.
- Reorder should be undoable/redoable.
- Active cut should remain the same CutId after reorder if that Cut still exists.
- Reorder should not mutate Cut material/source.
- Reorder should not change timeline placement inside the Cut.
```

Do not implement reorder in this phase.

---

## Active Cut Selection Command Direction

Document the agreed policy:

```text
- Active cut selection switch should be undoable/redoable during the current session.
- Cut switch is an EditingSessionState mutation, not a Project data mutation.
- Undoing cut switch should restore the previous activeCutId.
- Redoing cut switch should restore the selected activeCutId.
- Undo/redo of cut switch should rebuild or retarget active-cut-scoped controllers.
- Cut switch history is volatile and should not be saved.
```

Clarify:

```text
This command is future work.
Current Phase 37 cut switching is not yet undoable.
```

---

## History / Undo / Redo Direction

Document:

```text
- Undo/Redo is project editing session history.
- It may include project data mutations and editing session state mutations.
- It is time-ordered.
- It is volatile.
- It must not be serialized into project files.
- It is cleared when the app closes or project closes.
- Opening a saved project starts with empty undo/redo history.
- A future user-configurable max history count should limit memory use.
```

Mention example:

```text
Example maximum history count can be 500, but default should be decided later.
```

---

## Session State And Controller Retargeting

Document:

```text
- EditingSessionState owns activeCutId.
- ProjectRepository should not own activeCutId.
- When activeCutId changes, active-cut-scoped controllers/views must be rebuilt or retargeted.
- LayerController and TimelineController are active-cut-scoped.
- CanvasView receives active cut id.
- Cut management commands that affect activeCutId must trigger retarget/rebuild behavior.
```

Do not introduce state management frameworks.

---

## Save / Load Metadata Direction

Document:

```text
- Undo/redo stacks are not saved.
- lastActiveCutId should be saved as lightweight project metadata later.
- Reopening a project should restore lastActiveCutId by default.
- If lastActiveCutId is invalid or missing, fallback to defaultActiveCutIdFor(project).
- If the project has no Cuts and future project creation policy supports it, create a default empty Cut.
```

Clarify:

```text
Do not implement save/load lastActiveCutId in this phase.
Do not change JSON schema in this phase.
```

---

## What Not To Implement Yet

Document that this phase should not implement:

```text
- Cut create command
- Cut delete command
- Cut rename command
- Cut duplicate command
- Cut reorder command
- Undoable active cut switch
- Cut create/delete/rename UI
- Cut management panel
- Save/load lastActiveCutId
- Persistent project open/close flow
- Linked Cut
- Linked Layer
- Cross-cut linked paste
- Project-level material pool
- Conte Panel
- Conte Layer
```

---

## Very Important Restrictions

Do not implement any of the following:

```text
- Runtime code changes
- Test changes
- Cut create behavior
- Cut delete behavior
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
- Renderer changes
- Brush engine changes
- Provider
- Riverpod
- Bloc
- ChangeNotifier
- Stream-based session state
- Complex app-wide state management
```

Do not implement Phase 45 or later.

---

## Allowed Changes

Allowed:

```text
- Add docs/Cut_Management_Command_Design.md.
- Optionally add a short cross-reference from docs/Cut_Management_Policy.md.
```

Preferred result:

```text
docs-only changes
```

---

## Expected User-Visible Behavior

After Phase 44:

```text
The app should look and behave exactly the same as Phase 43.
```

No runtime behavior should change.

---

## Tests / Validation

Since this is docs-only:

```bash
flutter analyze
flutter test
git status
```

Do not run `dart format` on Markdown files.

Do not run `dart format` on docs.

---

## Manual Check In Android Studio

Manual app check is optional for this docs-only phase.

If performed, verify:

```text
1. App launches normally.
2. Cut 1 / Cut 2 switching still works.
3. No new UI appeared.
4. No Cut management panel appeared.
5. No Conte Panel appeared.
```

---

## Completion Criteria

This phase is complete only when:

```text
1. docs/Cut_Management_Command_Design.md exists.
2. The document explains future Cut create command direction.
3. The document explains future Cut rename command direction.
4. The document explains future Cut delete command direction using cutDeletionFallbackFor.
5. The document explains last-Cut delete behavior using createDefaultCut.
6. The document explains independent Cut duplicate MVP.
7. The document explains future Cut reorder command direction.
8. The document explains undoable active cut selection switch as future work.
9. The document explains volatile undo/redo history.
10. The document explains lastActiveCutId save/load metadata direction.
11. No runtime code changed.
12. No tests changed.
13. No JSON schema changed.
14. No UI was added.
15. flutter analyze passes.
16. flutter test passes.
17. git status is clean after commit.
```

---

## Suggested Final Response From Codex

After completing the task, summarize:

```text
Implemented Phase 44 Cut Management Command Design Notes.

Changed:
- Added docs/Cut_Management_Command_Design.md.
- Documented future Cut create/delete/rename/duplicate/reorder command direction.
- Documented active cut selection command direction.
- Documented undo/redo and session-state coordination policy.
- Documented save/load lastActiveCutId metadata direction.

Validation:
- flutter analyze
- flutter test
- git status

This phase was docs-only.
No runtime code changed.
No tests changed.
No UI changed.
```

If Flutter is not available in the Codex environment, clearly say so and report the exact error.

---

## Short Instruction For Codex

Read `docs/Phase_44_Codex_Task.md` and implement Phase 44 only. This phase is docs-only. Add `docs/Cut_Management_Command_Design.md` documenting future Cut create/delete/rename/duplicate/reorder command design, active cut selection command direction, undo/redo/session-state coordination, use of `cutDeletionFallbackFor`, use of `createDefaultCut`, volatile undo/redo history, and future `lastActiveCutId` metadata restore. Do not change runtime code, tests, UI, JSON schema, save/load, repository APIs, command APIs, undo/redo implementation, timeline/canvas behavior, or implement Phase 45+. Run `flutter analyze`, `flutter test`, and `git status`.
