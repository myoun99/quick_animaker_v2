# Phase 217 Codex Task: Brush Cache / Storage Invalidation Boundary

## Goal

Continue the brush part only.

This phase prepares a narrow brush cache / storage invalidation boundary after the main canvas was promoted to the production brush editing surface.

Do not implement real playback cache, save/load, real deferred bake, or renderer cache generation in this phase.

The goal is to make brush edit operations explicitly mark which brush frame state became dirty so future inactive preview cache, playback cache, save/load, and renderer work can rebuild derived cache images safely.

Cache images must remain derived and rebuildable.

They must not become source of truth.

## Required reading before implementation

Read these documents directly before editing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`

## Current source-of-truth boundaries to preserve

`BrushFrameEditingCoordinator` is the public UI-facing brush editing / undo / redo boundary.

`UnifiedUndoHistory` owns production-facing global user undo/redo order.

`BrushFrameStore` owns frame-local brush drawing payloads and brush command movement.

`BrushPaintCommand` is the brush command identity / payload boundary.

`BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, and materialization undo/redo services remain internal session-local bitmap materialization bridges only.

`Frame` remains lightweight identity, timing, and metadata.

Cache images are derived and rebuildable.

The main canvas widget must not become source of truth.

## Small UI label requirement

In the HomePage top toolbar, visible button labels should be:

```txt
Undo
Redo
```

Do not show:

```txt
Project Undo
Project Redo
```

However, this is only a label change.

The buttons must not go back to legacy `CanvasController` undo/redo.

The top toolbar Undo / Redo buttons must continue to avoid the old legacy canvas route.

If they currently call project-level history through `HistoryManager`, keep that boundary or use the existing appropriate project-history boundary.

Do not route these top toolbar buttons to internal brush materialization undo/redo services.

Do not route these top toolbar buttons to legacy `CanvasController`.

Update tests accordingly so they assert the visible labels are `Undo` / `Redo` while still guarding against `_canvasController.undo()`, `_canvasController.redo()`, `_canvasController.canUndo`, and `_canvasController.canRedo`.

## Hard restrictions

Do not reintroduce `TileDelta` or `TileDeltaCommand`.

Do not use `TileDelta` / `TileDeltaCommand` as brush commit results, brush undo/redo payloads, brush edit history entries, or cache-invalidation inputs.

Do not treat internal bitmap materialization history as user-facing undo.

Do not put heavy bitmap payloads, command buffers, baked surfaces, preview caches, playback caches, dirty flags, or cache images into `Frame`.

Do not make cache images source of truth.

Do not make the main canvas widget source of truth.

Do not implement save/load.

Do not implement playback cache.

Do not implement real deferred bake.

Do not implement renderer cache generation.

Do not expand storyboard or timeline features.

Do not perform a large UI rewrite.

Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

## Implementation tasks

1. Inspect the current brush edit cache invalidation path.

   Review existing code around:

    * `BrushFrameEditingCoordinator`
    * `BrushFrameStore`
    * `BrushEditCacheInvalidationSink`
    * `CacheInvalidationSink`
    * `BrushEditSessionCacheOperationResult`
    * `InteractiveBrushEditCanvasView`
    * `BrushCanvasPanel`
    * `MainCanvasBrushHost`

2. Add or strengthen a narrow brush-frame dirty / invalidation boundary.

   Prefer existing types if they already exist.

   If a small new type is necessary, keep it focused and lightweight.

   Acceptable concepts include:

    * `BrushFrameKey`
    * dirty frame state
    * dirty region
    * dirty tile set
    * cache invalidation event
    * cache invalidation sink

   The invalidation boundary should identify which brush frame became dirty after a brush edit operation.

   If region/tile-level information is already available, preserve it through a dirty-region / dirty-tile boundary.

   If region/tile information is not yet available, a whole-frame dirty marker keyed by `BrushFrameKey` is acceptable for this phase.

   Do not invent a heavy cache system.

3. Mark dirty state after brush edit operations.

   Ensure dirty / invalidation information is produced or preserved after relevant brush operations such as:

    * brush commit / paint operation
    * undo of a brush paint command through the public coordinator route
    * redo of a brush paint command through the public coordinator route
    * active frame display refresh caused by a brush operation

   Keep dirty state below the brush/canvas storage boundary.

   Do not store dirty flags in `Frame`.

4. Keep cache ownership correct.

   Cache invalidation tells future cache builders what to rebuild.

   Cache invalidation must not make cache images source of truth.

   Cache invalidation must not persist fake preview images as authored drawing data.

   Cache invalidation must not bypass `BrushFrameStore`.

5. Keep UI route safe.

   `BrushCanvasPanel` and `MainCanvasBrushHost` may pass cache invalidation events through the existing sink/boundary.

   UI widgets must not directly own source drawing payloads, cache images, command buffers, baked surfaces, or dirty state.

   UI widgets must not call internal materialization undo/redo helpers.

6. Update Undo / Redo labels.

   Change visible labels from `Project Undo` / `Project Redo` to `Undo` / `Redo`.

   Preserve the non-legacy route.

   Update tests to match the new labels while keeping architecture guards that prevent returning to legacy `CanvasController`.

7. Add or strengthen tests.

   Add or update focused tests proving:

    * brush commit marks the active `BrushFrameKey` dirty or emits a cache invalidation event
    * brush undo through `BrushFrameEditingCoordinator.undo()` marks the affected frame dirty
    * brush redo through `BrushFrameEditingCoordinator.redo()` marks the affected frame dirty
    * cache invalidation uses `BrushFrameKey` and dirty-region / dirty-tile concepts where available
    * cache invalidation does not use `TileDelta` or `TileDeltaCommand`
    * cache images are not treated as source of truth
    * `Frame` remains lightweight and does not own dirty flags, cache images, command buffers, or bitmap payloads
    * main canvas UI does not directly own brush payloads or cache images
    * top toolbar visible labels are `Undo` / `Redo`
    * top toolbar Undo / Redo do not call legacy `CanvasController` undo/redo
    * internal materialization history is not exposed as user-facing undo

8. Documentation.

   Update `docs/Current_Brush_Architecture.md` and/or `docs/Current_Canvas_Cache_Storage_Architecture.md` only if this phase clarifies dirty / invalidation policy.

   Do not modify sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If the continuation state changes, update only section 8 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   Do not add brittle documentation tests based on exact prose length.

## Validation

Run:

```sh
dart format lib test
flutter analyze
flutter test
git status
```

## PR notes

The PR description must include:

* Summary
* Cache / storage invalidation boundary notes
* Undo / Redo label change confirmation
* Tests run
* Whether visible UI behavior changed
* Confirmation that cache images were not made source of truth
* Confirmation that `Frame` remains lightweight
* Confirmation that `TileDelta` / `TileDeltaCommand` were not reintroduced
* Confirmation that internal materialization history was not made user-facing undo
* Confirmation that save/load, playback cache, real deferred bake, renderer cache generation, storyboard expansion, timeline expansion, and broad UI rewrite were not implemented
