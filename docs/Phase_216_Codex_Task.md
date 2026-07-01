# Phase 216 Codex Task: Main Canvas Brush Editing Surface Integration

## Goal

Continue the brush part only.

This phase promotes the current temporary / preview-style brush canvas route into the production main-canvas brush editing surface.

This does not mean the canvas widget becomes the source of truth.

The source drawing payload must remain owned by the brush/canvas storage boundary, currently `BrushFrameStore` and related brush editing services.

`Frame` must remain lightweight metadata.

The main canvas should become the UI surface that uses the existing brush editing boundary, not a new owner of bitmap data.

## Required reading before implementation

Read these documents directly before editing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`

## Current boundaries to preserve

`BrushFrameEditingCoordinator` is the public brush editing boundary for UI-facing brush edit, undo, and redo.

`UnifiedUndoHistory` is the production-facing global user undo/redo order.

`UndoPayloadRef.paintCommand` points user undo entries at brush paint-command payloads.

`BrushFrameStore` owns frame-local brush drawing payloads and command movement.

`BrushPaintCommand` is the brush command identity / payload boundary.

Internal bitmap materialization history remains a session-local display/materialization bridge below the public coordinator/store boundary.

Cache images are derived and must not become source of truth.

`Frame` owns only lightweight identity, timing, and metadata.

## Hard restrictions

Do not reintroduce `TileDelta` or `TileDeltaCommand`.

Do not treat internal bitmap materialization history as user-facing undo.

Do not make `BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, or materialization undo/redo services into public undo history.

Do not put heavy bitmap payloads, command buffers, baked surfaces, cache images, or preview images into `Frame`.

Do not make the main canvas widget source of truth.

Do not make cache images source of truth.

Do not implement save/load.

Do not implement playback cache.

Do not implement real deferred bake.

Do not expand storyboard or timeline features.

Do not perform a large UI rewrite.

Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

## Implementation tasks

1. Inspect the current main-canvas brush route.

   Review the current UI path for:

    * main canvas host / panel
    * brush canvas panel
    * brush editor selection
    * active project / track / cut / layer / frame selection mapping
    * `BrushFrameKey` construction
    * `BrushFrameEditingCoordinator`
    * `BrushFrameStore`
    * placeholder behavior when no frame/layer is selected

2. Promote the brush canvas route into the production main-canvas brush editing surface.

   The selected project / track / cut / layer / frame should resolve into a stable `BrushFrameKey`.

   When a valid frame/layer selection exists, the main canvas should use the production brush editing coordinator route.

   When no valid frame/layer selection exists, the main canvas should show a safe placeholder and avoid fake editable state.

   Remove or reduce preview/temporary wording where it incorrectly describes the production main-canvas brush editing path.

   Do not restore deleted smoke/debug workspace routes.

3. Keep ownership correct.

   The main canvas UI may display and send input to the brush editing coordinator.

   The main canvas UI must not directly own bitmap payloads, command buffers, baked surfaces, or cache images.

   Heavy frame-local drawing state must remain in `BrushFrameStore` or the brush/canvas storage boundary.

   `Frame` must remain lightweight.

4. Keep undo/redo routing correct.

   UI-facing brush undo and redo must continue to go through:

   ```txt
   BrushFrameEditingCoordinator.undo()
   BrushFrameEditingCoordinator.redo()
   ```

   UI-facing code must not directly call internal materialization undo/redo helpers.

5. Keep active-frame display behavior intact.

   Do not break the existing behavior:

    * commit displays active-frame drawing
    * coordinator undo hides it
    * coordinator redo restores it

6. Add or strengthen tests.

   Add or update focused tests proving:

    * main-canvas brush host does not crash when there is no selection
    * main-canvas brush host uses a real resolved `BrushFrameKey` when selection exists
    * selected project / track / cut / layer / frame identity is preserved in the brush editing route
    * UI-facing undo/redo still routes through `BrushFrameEditingCoordinator`
    * main canvas UI does not import or call internal materialization undo/redo helpers
    * main canvas UI does not store heavy bitmap payloads or cache images in `Frame`
    * `TileDelta` / `TileDeltaCommand` are not reintroduced

7. Documentation.

   Update `docs/Current_Brush_Architecture.md`, `docs/Current_Canvas_Cache_Storage_Architecture.md`, or `docs/Current_UI_Product_Policy.md` only if this phase clarifies the main-canvas brush editing surface boundary.

   Do not modify sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If the continuation state changes, update only section 8 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   Do not add brittle documentation tests based on exact prose length.

## Validation

Run:

```sh id="841s2z"
dart format lib test
flutter analyze
flutter test
git status
```

## PR notes

The PR description must include:

* Summary
* Architecture boundary notes
* Tests run
* Whether visible UI behavior changed
* Confirmation that the main canvas widget was not made source of truth
* Confirmation that `Frame` remains lightweight
* Confirmation that `TileDelta` / `TileDeltaCommand` were not reintroduced
* Confirmation that internal materialization history was not made user-facing undo
* Confirmation that save/load, playback cache, real deferred bake, storyboard expansion, timeline expansion, and broad UI rewrite were not implemented
