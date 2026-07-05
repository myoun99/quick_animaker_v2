# Current Cut Management Architecture

## Status

This is the current source-of-truth policy for Cut selection and future Cut create/delete/switch management. It consolidates the current rules from the old active-cut and cut-management notes without restoring those obsolete non-phase docs.

## Cut identity

`CutId` is the real identity of a Cut. Cut names are user-facing display labels and may duplicate; Cut selection, editing, deletion, duplication, and future ordering must be based on `CutId`, not the display name.

Cut name policy is intentionally different from frame name/material policy. Same Cut name does not mean same Cut, while same frame name means same drawing material inside the relevant layer.

## activeCutId ownership

`activeCutId` is application/session/controller state, not persisted project structure. The selected Cut is UI/session context rather than project content.

Recommended ownership remains near the UI/controller boundary or in a small editing-session state object. In the current editor `EditorSessionManager` (a narrowly scoped `ChangeNotifier`) holds `activeCutId` via `EditingSessionState` and drives targeted rebuilds. Do not introduce Provider, Riverpod, Bloc, hidden globals, or a broad app-wide state-management package for active Cut selection unless a future phase explicitly designs it; keep any `ChangeNotifier` / `ValueNotifier` use lightweight and editor-local rather than app-wide.

`ProjectRepository` should remain focused on project data mutations, not UI selection state. Controllers and edit commands should carry enough Cut context to make their target explicit and avoid ambiguous repository-wide searches.

## lastActiveCutId metadata candidate

`activeCutId` remains volatile editing/session state and must not be treated as persisted project structure.

A separate future `lastActiveCutId` may be persisted as lightweight project-open metadata if a future save/load phase explicitly implements it. This metadata would restore the last viewed/edited Cut when reopening a project, but it must remain separate from the live editing-session `activeCutId` and must not imply persisting undo/redo history.

If implemented, `lastActiveCutId` restore must validate that the Cut still exists. If the saved id is missing or invalid, project opening should fall back to the default active-Cut selection policy rather than leaving the editor pointed at a missing Cut.

## Valid active Cut invariant

Create, delete, and switch Cut flows must keep `activeCutId` valid. Deleting a Cut must not leave the editor pointing at a missing Cut.

When deleting the active Cut, active Cut fallback must be:

1. Previous Cut in project order.
2. If no previous Cut exists, next Cut.
3. If no Cut remains, create a new default empty Cut and make it active.

Required invariants after Cut deletion completes:

- `activeCutId` does not point at a missing Cut.
- At least one editable Cut exists after the operation completes.
- The app is not left in a persistent zero-Cut state.
- Active-Cut-scoped controllers and views are rebuilt or retargeted to the fallback Cut when active Cut changes.

## Cut switching

Cut switching changes editing-session selection. It must not mutate project data by itself. Future undoable Cut switching, if implemented, should be treated as editing-session history rather than saved project payload.

Undo/redo history remains volatile and must not be serialized into project save files. Opening a project starts with an empty undo/redo stack.

## Mutation isolation

Cut management must not mutate unrelated timeline, canvas, brush, cache, or storage state. Create/delete/switch/rename/duplicate/reorder flows may update Cut data and the editing-session active Cut selection when needed, but they must not silently retarget timeline edits, canvas edits, brush payloads, playback caches, or unrelated layer/frame state.

Timeline placement remains independent per Cut. Linked frames may share material/source identity, but not timing, placement, marks, blank/X position, selected cell state, or other authored timeline entry state.

## Future duplication direction

The MVP Cut duplicate behavior should be an independent deep copy: new `CutId`, new `LayerId`s, new `FrameId`s, independent authored placement, and no linked Cut/Layer/material behavior by default. Editing the duplicated Cut must not mutate the source Cut, and editing the source Cut must not mutate the duplicate.

## Long-term linked Cut / linked Layer candidates

Linked Cut, Linked Layer, cross-layer linked paste, and cross-cut linked paste remain long-term candidates only. They are not current MVP Cut duplicate behavior and must not be introduced accidentally by duplicate, rename, reorder, or paste work.

Any future linked Cut or linked Layer design must preserve the separation between drawing material/source sharing and authored timeline placement/timing. Sharing drawing material/source must not silently share exposure duration, timeline placement, marks, blank/X positions, selected cell state, camera/sound/storyboard timing, or unrelated Cut metadata.

Linked Cut may be useful later for shared-use Cut workflows and relationship tracking, but it requires a dedicated current architecture update before implementation. Linked Layer and cross-Cut material/source relationships should be designed with the brush/canvas storage policy rather than by overloading Cut names, Layer names, Frame names, or timeline placement.
