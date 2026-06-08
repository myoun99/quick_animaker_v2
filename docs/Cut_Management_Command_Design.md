# Cut Management Command Design

## Purpose

This document records the future command design direction for Cut management before any Cut create, rename, delete, duplicate, or reorder commands are implemented.

Phase 44 is intentionally docs-only. It describes how later phases should coordinate project data mutation, editing-session selection, history, and active-cut controller retargeting without changing runtime behavior now.

The design goal is to keep the `Project -> Track -> Cut -> Layer -> Frame -> Stroke` hierarchy clear while making future Cut management actions safe, undoable where appropriate, and independent from Flutter UI widgets.

## Current State

The currently implemented Cut-management foundation is deliberately small:

- Cut switching exists between the sample `Cut 1` and `Cut 2`.
- `EditingSessionState` owns `activeCutId` as lightweight editing-session state.
- `HomePage` currently rebuilds or retargets active-cut-scoped controllers when `activeCutId` changes.
- `cutDeletionFallbackFor` exists and returns a deletion fallback decision without mutating `Project`.
- `createDefaultCut` exists and creates a default empty `Cut` without inserting it into `Project`.
- Cut create, delete, rename, duplicate, and reorder commands do not exist yet.
- Cut management UI does not exist yet.
- Undoable active Cut switch does not exist yet.
- Save/load of `lastActiveCutId` does not exist yet.

This state is sufficient for active-cut isolation and small switching polish, but it is not yet a full Cut management workflow.

## Command Design Principles

Future Cut management commands should follow these principles:

- Commands should keep `Project` data and `EditingSessionState` coordinated.
- Commands that mutate `Project` data should go through `HistoryManager`.
- Commands that mutate `EditingSessionState` may also go through `HistoryManager` when they are user-level editing actions.
- Active Cut selection must never point to a missing `Cut` after a command completes, after undo, or after redo.
- Commands should be small and testable.
- Commands should avoid UI dependencies.
- Commands should avoid Flutter widget dependencies.
- Commands should avoid introducing Provider, Riverpod, Bloc, ChangeNotifier, or other app-wide state-management frameworks.
- Commands should preserve linked-frame policies: linked frames may share drawing material/source identity, but timeline placement, exposure, marks, blank/X positions, and selected cell state remain per authored timeline entry and per Cut.

Ownership should remain explicit:

- `ProjectRepository` owns `Project` data mutation.
- `EditingSessionState` owns `activeCutId` and other lightweight editing-session selection state.
- `HistoryManager` records volatile undoable/redoable command history for the active editing session.
- Controller rebuild/retarget logic belongs near the session/controller boundary, not inside pure model objects.

A future command may therefore need collaborators such as:

- `ProjectRepository`, to insert, remove, rename, duplicate, or reorder Cuts.
- `HistoryManager`, to execute and reverse undoable commands.
- `EditingSessionState`, to update `activeCutId` when the command changes which Cut should be visible/editable.
- A small controller retarget callback or coordinator, to rebuild active-cut-scoped controllers after `activeCutId` changes.

Commands should coordinate those collaborators without becoming UI classes.

## Cut Create Command Direction

Future Cut create should create a new default Cut and insert it into the project through an undoable command.

Expected direction:

- Use `createDefaultCut` or an equivalent small helper to build the new `Cut`.
- The caller or a future ID allocator should provide the new `CutId` and initial `LayerId`.
- Do not add random, timestamp, UUID, or global counter ID generation as part of the command unless a later phase explicitly designs ID allocation.
- The first implementation should likely insert the new Cut after the active Cut, or at the end of the active track if that is simpler and more deterministic.
- The newly created Cut should probably become active after creation.
- Creation should be undoable/redoable through `HistoryManager`.
- Undo should remove the created Cut and restore the previous active Cut.
- Redo should recreate or reinsert the Cut in its intended position and make it active again.
- If controller instances are scoped to `activeCutId`, create redo should retarget/rebuild controllers after restoring the created Cut as active.

Do not implement Cut create in Phase 44. Do not add an ID generator in Phase 44.

## Cut Rename Command Direction

Future Cut rename should change only the Cut display name.

Expected direction:

- Rename should mutate project data through `ProjectRepository` and be recorded by `HistoryManager`.
- Rename should only change `Cut.name` or its future display-label equivalent.
- `CutId` remains the real identity.
- Cut names are user-facing labels and may be duplicated.
- Rename should not be blocked by duplicate Cut names.
- Undo should restore the previous name.
- Redo should restore the new name.
- Rename should not change `activeCutId` unless the renamed Cut was already active; even then the active identity is still the same `CutId`.
- Rename should not rebuild active-cut-scoped controllers unless the UI read model needs a label refresh; drawing/timeline controllers should not retarget because identity did not change.

Important distinction: frame rename policies are stricter because frame names can participate in material/link identity decisions. Cut rename is different. Cut names are labels, and duplicate Cut labels should be allowed.

Do not implement Cut rename in Phase 44.

## Cut Delete Command Direction

Future Cut delete should remove a Cut while guaranteeing that active Cut selection remains valid.

Expected direction:

- Delete should first compute a fallback by calling `cutDeletionFallbackFor(project, deletingCutId: ...)` before mutating the project.
- If `cutDeletionFallbackFor` returns `useExistingCut`, the delete command should switch `activeCutId` to that existing Cut when the deleted Cut was active.
- If the deleted Cut was not active, the command may leave `activeCutId` unchanged as long as it still points to an existing Cut.
- Delete should mutate project data through `ProjectRepository` and be recorded by `HistoryManager`.
- Delete should preserve enough removed-Cut data and original position information to support undo.
- Undo should reinsert the deleted Cut at its original location and restore the prior active Cut selection when appropriate.
- Redo should remove the Cut again and apply the same fallback selection behavior.
- Controller retargeting should happen after the project has a valid replacement active Cut, not while `activeCutId` points to the removed Cut.

`cutDeletionFallbackFor` is a decision helper only. It should remain pure: it should not mutate `Project`, should not create a Cut, and should not update `EditingSessionState`.

Do not implement Cut delete in Phase 44.

## Last Cut Delete Direction

Deleting the final Cut in a project needs special handling because the application should not end a command with no valid active Cut.

Expected direction:

- When `cutDeletionFallbackFor` returns `createDefaultCut`, the command should use `createDefaultCut` or an equivalent helper to build a replacement default Cut.
- The command should insert that default Cut into the project as part of the same undoable user action that removes the last existing Cut.
- The replacement default Cut should receive caller-provided or allocator-provided IDs.
- `activeCutId` should become the replacement default Cut's `CutId` after the command completes.
- Undo should remove the replacement default Cut and restore the original deleted Cut and original active Cut selection.
- Redo should remove the original Cut again, recreate or reinsert the replacement default Cut, and make the replacement active.

This keeps the invariant that the active Cut never points to a missing Cut and that the editor always has a valid Cut context.

Do not implement last-Cut deletion behavior in Phase 44.

## Cut Duplicate Command Direction

Future Cut duplicate MVP should create an independent deep copy of the selected source Cut.

Expected direction for the MVP:

- Duplicate should copy the source Cut's canvas size, duration, layers, timeline entries, authored frame placement, marks, blank/X exposures, and drawing content into a new Cut identity.
- The duplicate should receive a new `CutId`.
- Every copied Layer should receive a new `LayerId`.
- Every copied independent Frame should receive a new `FrameId` unless a later phase explicitly designs cross-Cut linked material identity.
- Stroke/content data should be copied so the duplicate is independent from the source Cut.
- Editing the duplicate after the command should not mutate the source Cut.
- Editing the source Cut after the command should not mutate the duplicate.
- The duplicated Cut should likely be inserted after the source Cut and become active.
- Duplicate should be undoable/redoable through `HistoryManager`.
- Undo should remove the duplicated Cut and restore the previous active Cut.
- Redo should reinsert the duplicate and make it active again.

Do not implement Linked Cut behavior in the duplicate MVP. A future Linked Cut feature would need a separate design because it could intentionally share source material across Cuts.

Do not implement Cut duplicate in Phase 44.

## Cut Reorder Command Direction

Future Cut reorder should change Cut order within the project without changing Cut identity or drawing content.

Expected direction:

- Reorder should mutate project data through `ProjectRepository` and be recorded by `HistoryManager`.
- Reorder should preserve each Cut's `CutId`, name, canvas size, layers, frames, timeline, and content.
- Reorder should move a Cut within its current track first; cross-track moves should be a separate later design if needed.
- Reorder should be deterministic and should store enough previous-position and new-position data for undo/redo.
- Undo should restore the previous order.
- Redo should restore the new order.
- If the active Cut is reordered, `activeCutId` should remain the same because identity did not change.
- Controller retargeting is usually unnecessary for same-Cut reorder because the active Cut identity and content are unchanged, though Cut list UI read models may need refresh.

Do not implement Cut reorder in Phase 44.

## Active Cut Selection Command Direction

Active Cut switching is an `EditingSessionState` mutation, not a `Project` data mutation.

Current switching can remain lightweight, but later active Cut selection switch should become undoable/redoable if the product treats Cut switching as a user-level editing navigation action.

Expected future direction:

- A future active Cut selection command should update `EditingSessionState.activeCutId`.
- It should not mutate `Project` content.
- It should validate that the target `CutId` exists before switching.
- Undo should restore the previous active Cut.
- Redo should restore the selected active Cut.
- Controller rebuild/retarget should occur after each switch, undo, or redo.
- The command should be small and free of Flutter widget dependencies.

Because Cut switching is session state, the command should not be confused with Cut reorder, rename, create, delete, or duplicate commands, which mutate project data.

Do not implement undoable active Cut switching in Phase 44.

## History / Undo / Redo Direction

Undo/redo is volatile project editing-session history.

Expected direction:

- `HistoryManager` should hold the undo/redo stacks for the currently running editing session.
- Commands that mutate project data should be executed through `HistoryManager`.
- Commands that represent user-level editing-session changes, such as future undoable active Cut switch, may also be executed through `HistoryManager`.
- Undo/redo commands must restore both project data and active Cut selection when the original command affected both.
- Undo/redo should not silently retarget a command to whichever Cut is active at playback time. Each command should carry or resolve the Cut context it originally intended to mutate.
- Undo/redo stacks must not be saved into project files.
- Undo/redo stacks must not be added to the JSON schema as part of Cut management.
- Persistent or archiveable history is a separate long-term feature and should not be introduced by Cut command MVPs.

This means future Cut commands should store only the command-local data needed to undo/redo safely during the current process/session.

## Session State And Controller Retargeting

Future commands should coordinate session state and controllers explicitly.

Expected direction:

- `EditingSessionState` remains responsible for `activeCutId`.
- `ProjectRepository` remains responsible for project data mutation.
- A command that changes the active Cut should update `EditingSessionState` after ensuring the target Cut exists in the project.
- A command that deletes the active Cut should choose and install a fallback active Cut before controller retargeting occurs.
- Active-cut-scoped controllers should be rebuilt or retargeted in one small, explicit place after `activeCutId` changes.
- Commands should not depend directly on Flutter widgets.
- Commands may call a narrow callback/coordinator such as `onActiveCutChanged` in a later implementation if controller retargeting cannot live entirely outside the command.
- Controller retargeting should happen after the repository and session state agree on a valid active Cut.

This coordination prevents timeline, canvas, and layer edits from continuing to target a deleted or stale Cut.

## Save / Load Metadata Direction

Future `lastActiveCutId` should be saved and restored only as lightweight metadata, not as project content.

Expected direction:

- `lastActiveCutId` may be stored in a future project metadata/workspace metadata field so reopening a project can restore the user's last visible Cut.
- `lastActiveCutId` should not be treated as part of the core `Project -> Track -> Cut -> Layer -> Frame -> Stroke` content hierarchy.
- Loading should validate that `lastActiveCutId` still exists.
- If the saved ID is missing or invalid, load should fall back to a deterministic existing Cut.
- Saving `lastActiveCutId` should not imply saving undo/redo stacks.
- Undo/redo history must remain volatile and should not be serialized into project files.
- JSON schema changes for `lastActiveCutId` should be designed in a later phase, not as part of command design notes.

Do not implement save/load of `lastActiveCutId` in Phase 44.

## What Not To Implement Yet

Phase 44 must not implement:

- Runtime code changes.
- Test changes.
- UI changes.
- JSON schema changes.
- Save/load changes.
- Repository API changes.
- Command API changes.
- Undo/redo implementation changes.
- Timeline behavior changes.
- Canvas behavior changes.
- Cut create commands.
- Cut delete commands.
- Cut rename commands.
- Cut duplicate commands.
- Cut reorder commands.
- Cut management UI.
- Undoable active Cut switch.
- Save/load of `lastActiveCutId`.
- Linked Cut behavior.
- Conte Panel.
- Conte Layer.
- Phase 45 or later work.

## Suggested Future Phase Order

A safe future order would be:

1. Add repository-level Cut insertion/removal/rename/reorder primitives with tests, if existing repository APIs are insufficient.
2. Add an undoable Cut create command that uses `createDefaultCut`, inserts a Cut, switches active selection, and retargets controllers.
3. Add an undoable Cut rename command with duplicate Cut names allowed.
4. Add an undoable Cut delete command using `cutDeletionFallbackFor` and last-Cut replacement through `createDefaultCut`.
5. Add an undoable Cut duplicate MVP as an independent deep copy.
6. Add an undoable Cut reorder command for same-track ordering.
7. Add undoable/redoable active Cut selection switching if the product chooses to treat navigation as history.
8. Add minimal Cut management UI on top of the tested commands.
9. Add lightweight `lastActiveCutId` save/load metadata after command behavior and fallback semantics are stable.
10. Design Linked Cut separately after independent Cut duplicate behavior is stable.
11. Defer Conte Panel, Conte Layer, and Phase 45+ work until Cut management commands are implemented and tested.

Each future phase should remain small, keep the app runnable, and preserve the separation between project data, editing-session state, volatile history, and UI/controller retargeting.
