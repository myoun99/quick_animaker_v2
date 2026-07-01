# Phase 214: Brush Runtime Display Stabilization Task

## Goal

Continue the brush part only.

This phase stabilizes the current brush runtime/display boundary so the active frame drawing route becomes safer before moving to storyboard, timeline, save/load, playback, or real deferred bake work.

The focus is:

* brush runtime/display stabilization
* active-frame drawing display correctness
* command payload/materialization boundary protection
* tests that prevent UI-facing routes from bypassing the public brush editing boundary

## Required reading before implementation

Read these documents directly before changing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`

## Hard restrictions

Do not reintroduce `TileDelta` or `TileDeltaCommand`.

Do not treat internal bitmap materialization history as user-facing undo.

Do not make `BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, or materialization undo/redo services into public undo history.

Do not put heavy bitmap payloads, command buffers, baked surfaces, cache images, or preview images into `Frame`.

Do not make cache images source of truth.

Do not implement save/load.

Do not implement playback cache.

Do not implement real deferred bake.

Do not perform a large UI rewrite.

Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

## Current architecture boundaries to preserve

`UnifiedUndoHistory` is the production-facing global user undo/redo order.

`BrushFrameEditingCoordinator` is the public brush editing boundary for UI-facing undo/redo routes.

`BrushFrameStore` owns frame-local brush payload movement.

`BrushPaintCommand` is the brush command identity and payload boundary.

The internal bitmap materialization bridge may exist only below the coordinator/store boundary as a session-local display/materialization helper.

Active frame display must conceptually remain:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
+ activeStrokeOverlay
```

Cache images are derived from brush frame drawing state and must not become durable source data.

## Implementation tasks

1. Inspect the current active-frame brush display route.

   Identify how committed brush edits become visible in the active frame.

   Identify which code paths use `BrushFrameEditingCoordinator`, `BrushFrameStore`, `BrushPaintCommand`, and the internal bitmap materialization bridge.

   Confirm that UI/canvas/smoke routes do not directly call materialization undo/redo internals.

2. Stabilize the runtime/display boundary.

   Keep changes small and modular.

   Clarify comments or names only where they protect the architecture boundary.

   Do not rename broad areas unless clearly necessary.

   Do not restore deleted Brush V1 workspace routes.

3. Strengthen active-frame display correctness tests.

   Add or update tests that prove:

    * a committed brush command becomes visible through the current public coordinator/store route
    * undo through `BrushFrameEditingCoordinator.undo()` hides the committed command
    * redo through `BrushFrameEditingCoordinator.redo()` restores the committed command
    * UI-facing code does not import or call internal bitmap materialization undo/redo services directly
    * `TileDelta` / `TileDeltaCommand` are not used in brush commit, undo, redo, edit history, or cache invalidation boundaries

4. Strengthen command payload/materialization boundary tests if needed.

   Tests should protect that `BrushPaintCommand` remains the brush command identity/payload boundary and that internal materialization references remain minimal session-local bridges.

5. Documentation.

   Update `docs/Current_Brush_Architecture.md` only if the runtime/display boundary is clarified.

   Do not modify sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If the implementation changes the continuation state, update only section 8 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

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

* summary
* architecture boundary notes
* tests run
* whether visible UI behavior changed
* explicit statement that `TileDelta` / `TileDeltaCommand` were not reintroduced
* explicit statement that save/load, playback cache, real deferred bake, and broad UI rewrite were not implemented
