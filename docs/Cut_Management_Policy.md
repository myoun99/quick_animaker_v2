# Cut Management Policy

## Purpose

This document records the product and technical policy for future Cut management work in QuickAnimaker v2.1.

It is intentionally policy-only. It does not implement or require runtime behavior, UI, repository APIs, command APIs, save/load schema changes, undo/redo implementation changes, timeline behavior changes, or canvas behavior changes.

The goal is to make future Cut create/delete/rename/duplicate/reorder phases safer by documenting the intended behavior before implementation.

## Cut Identity And Names

`CutId` is the real identity of a Cut.

A Cut name is a user-facing display label. It is not the identity of the Cut and should not be used as the durable reference for project operations.

Cut name policy:

- Duplicate Cut names are allowed.
- Cut name duplication should not block rename.
- Cut selection, editing, deletion, duplication, and future ordering should be based on `CutId`, not the display name.
- Future UI may show duplicate-name warnings, filters, disambiguation details, or a compact duplicate-name list/button.
- Duplicate-name UI, if added later, should help users navigate; it should not change the fact that `CutId` is identity.

This policy is intentionally different from frame name/material policy.

Frame name/material policy:

- Same frame name means same material within the same layer.
- Duplicate independent `FrameId`s with the same non-empty frame name in the same layer should not be allowed.
- Rename conflict resolution should preserve the rule that same name means same material.

Cut name policy:

- Same Cut name does not mean same Cut.
- Duplicate Cut names are allowed.
- `CutId`, not Cut name, identifies the Cut.

Future Cut management work must not weaken the existing frame name/material policy. Cut names are display labels, while frame names currently participate in material identity semantics inside a layer.

## Cut Deletion Policy

Future Cut deletion should keep the active Cut valid after the delete operation completes.

When deleting the active Cut, active Cut fallback should be:

1. Prefer the previous Cut in project order.
2. If no previous Cut exists, use the next Cut.
3. If no Cut remains, create a new default empty Cut.

Required invariants after a delete operation completes:

- `EditingSessionState.activeCutId` should not remain pointed at a missing Cut.
- The app should maintain at least one editable Cut after the operation completes.
- The temporary internal delete operation should not leave the app in a long-lived zero-Cut state.
- Active-cut-scoped controllers and views should be rebuilt or retargeted to the selected fallback Cut when the active Cut changes.

This section documents future intended behavior only. It does not implement Cut deletion.

## Last Cut Deletion Policy

Deleting the last Cut should be allowed from the user's perspective.

From the user's perspective, the delete command can remove the final visible Cut. Internally, deleting the last Cut should immediately create a new default empty Cut so the final result is a valid project with one editable Cut.

The intended result after deleting the last Cut is:

- The previous final Cut is gone.
- A new default empty Cut exists.
- The new default Cut is editable.
- The active Cut points to the new default Cut.
- The project is not left in a persistent zero-Cut state.

This phase does not implement last-Cut deletion behavior.

## Cut Duplication Policy

The MVP Cut duplicate behavior should be an independent deep copy.

Initial Cut duplicate policy:

- A duplicated Cut should receive a new `CutId`.
- Duplicated layers should receive new `LayerId`s.
- Duplicated frames should receive new `FrameId`s.
- The duplicate should not be linked to the source Cut by default.
- Timeline placement in the duplicate should be copied as independent authored placement.
- Strokes/material content may be copied as independent content for the MVP.
- Editing the duplicated Cut should not mutate the original Cut.
- Editing the original Cut should not mutate the duplicated Cut.

The first Cut duplicate implementation should not introduce:

- Linked Cut.
- Linked Layer.
- Cross-cut linked frames.
- Cross-cut paste.
- Project-level material pool.
- Shared timeline placement.

Independent duplication is the safer MVP because it preserves current active-Cut isolation and avoids introducing shared material/source semantics before the data model is ready.

## Future Linked Cut Direction

Linked Cut is a long-term idea for shared-use cuts / 겸용컷 workflows.

Possible future uses:

- Output planning.
- Timesheet workflow.
- Cut relationship tracking.
- Shared-use Cut relationships where a Cut is intentionally reused or referenced in more than one production context.

A future Linked Cut may behave like a higher-level relationship that can automatically create or manage linked layers. However, Linked Cut should not mean timeline placement is globally shared by default.

Important separation of concepts:

- Material/source sharing and timeline placement sharing must remain separate concepts.
- Linked material/source does not automatically mean shared timing.
- Linked Cut, if introduced later, must not make authored exposure duration, marks, blank/X placement, selected cell state, or other timing decisions globally shared unless that behavior is explicitly designed and approved.

Linked Cut should be designed later, after Linked Layer and project-level material/source direction are clearer.

This phase does not implement Linked Cut.

## Undo / Redo Policy

Undo/Redo is project editing session history.

Undo/Redo may include both project data mutations and editing session state mutations. The history stack is a time-ordered editing-session concept, not a saved-project payload.

Future undoable/redoable Cut commands should include:

- Cut create.
- Cut delete.
- Cut rename.
- Cut duplicate.
- Cut reorder.
- Active Cut selection switch during the current session.

Active Cut selection switch policy:

- Active Cut selection switch should be undoable/redoable during the current session.
- Active Cut selection switch is an editing-session history command.
- Undoing/redoing active Cut selection should restore `EditingSessionState.activeCutId`.
- Undoing/redoing active Cut selection should rebuild or retarget active-Cut-scoped controllers.
- Cut switch itself should not mutate Project data by itself.

Cut management mutation policy:

- Cut create/delete/rename/duplicate/reorder are project mutation history commands.
- Cut management mutation commands and active Cut selection commands can live in the same time-ordered `HistoryManager` stack.
- Commands that mutate project data may also need to update editing session state when the active Cut is affected.

This phase does not implement undoable active Cut switching or any Cut management command.

## Volatile Undo / Redo History

Undo/Redo stack volatility is a hard policy.

Volatile history policy:

- Undo/Redo stack is volatile.
- Undo/Redo stack must not be serialized into project save files.
- Undo stack must not be saved into project files.
- Redo stack must not be saved into project files.
- Undo/Redo stack is cleared when the app closes.
- Undo/Redo stack is cleared when the project closes.
- Opening a saved project starts with an empty undo/redo stack.

Save/load schema policy:

- Save/load schema should not include undo stack data.
- Save/load schema should not include redo stack data.
- Restoring a project file should restore project data and lightweight project metadata, not the previous volatile editing history.

Future preference:

- The maximum undo history count should be user-configurable later.
- An example history count is 500, but the default value can be decided later.

## Last Active Cut Restore Policy

The current/last active Cut id should be saved as lightweight project metadata.

Last active Cut restore policy:

- Last active Cut id should be saved/restored as lightweight project metadata.
- Reopening a project should restore the last active Cut by default.
- Restoring the last active Cut should be default behavior, not an optional setting for now.
- If the saved last active Cut id no longer exists, the app should fall back to default active Cut resolution.

Recommended future fallback order:

1. Try the saved `lastActiveCutId`.
2. If missing or invalid, use `defaultActiveCutIdFor(project)`.
3. If the project has no Cuts and future project policy supports it, create a default empty Cut.

Important distinction:

- Save the last active Cut id.
- Do not save undo/redo stack.
- Restoring the last active Cut does not restore prior undoable Cut-switch commands.
- Opening a saved project should start with an empty undo/redo stack even if the last active Cut is restored.

This phase does not implement save/load metadata for `lastActiveCutId`.

## Sample Project Direction

The current hardcoded `Cut 1` / `Cut 2` data is temporary development/demo data.

Current purpose:

- It exists to test Cut switching.
- It exists to test active-Cut edit safety.
- It provides visible sample data while Cut structure and active-Cut flow are being stabilized.

Long-term product direction:

- Hardcoded sample Cuts should not be the normal startup project in the final product.
- Later project creation/opening flow should replace the hardcoded sample project.
- A new project may start with one default empty Cut.
- A demo/sample project can exist separately as a template or development-only fixture.
- The hardcoded sample project can be removed when real project creation/open/save flow is ready.

This phase does not remove sample data.

## What Not To Implement Yet

The following remain intentionally not implemented by this policy phase:

- Cut create UI.
- Cut delete UI.
- Cut rename UI.
- Cut duplicate UI.
- Cut reorder UI.
- Cut management panel.
- Linked Cut.
- Linked Layer.
- Cross-cut linked paste.
- Cross-layer linked paste.
- Project-level material pool.
- Save/load `lastActiveCutId`.
- Undoable active Cut switch.
- Persistent project open/close flow.
- Conte Panel.
- Conte Layer.

This policy phase also must not introduce runtime code changes, test changes, UI changes, JSON schema changes, save/load changes, repository API changes, command API changes, undo/redo implementation changes, timeline behavior changes, or canvas behavior changes.

## Suggested Future Phase Order

This advisory order is conservative and non-binding:

1. Document Cut management policy.
2. Add pure helper tests for Cut deletion fallback.
3. Add command/service design for Cut create/delete/rename.
4. Add undoable active Cut switch command.
5. Add minimal Cut rename UI.
6. Add minimal Cut create UI.
7. Add minimal Cut delete UI with previous/next/new fallback.
8. Add Cut duplicate as independent deep copy.
9. Add save/load metadata for `lastActiveCutId`.
10. Remove hardcoded sample project when real project creation/opening flow is ready.
11. Design Linked Layer / Linked Cut later.
