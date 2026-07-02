# Phase 218 Codex Task: Main Canvas Brush Production Readiness Sweep

## Goal

Continue the brush part only.

This phase is a production-readiness sweep after the main canvas brush surface, brush undo/source-of-truth boundary, and brush cache/storage invalidation boundary have been integrated.

The goal is not to add a large new feature.

The goal is to make the current production brush route safer, clearer, and less likely to regress before a later dedicated runtime stabilization / completion phase.

After this phase, the project may continue with a separate stability/completion pass focused on making the brush experience run more reliably in practice. Do not try to solve that entire future pass in this phase.

## Required reading before implementation

Read these documents directly before editing code:

* `docs/Handoff_QuickAnimaker_v2_Current.md`
* `docs/Current_Brush_Architecture.md`
* `docs/Current_Canvas_Cache_Storage_Architecture.md`
* `docs/Current_UI_Product_Policy.md`

## Current production brush route to preserve

The production route should remain:

```txt id="zxtz7r"
HomePage
-> MainCanvasBrushHost
-> BrushCanvasPanel
-> InteractiveBrushEditCanvasView
-> BrushFrameEditingCoordinator
-> BrushFrameStore
```

`BrushFrameEditingCoordinator` remains the public UI-facing brush editing / undo / redo boundary.

`BrushFrameStore` remains the owner of frame-local brush drawing payloads.

`UnifiedUndoHistory` remains the production-facing global user undo/redo order.

`BrushFrameCacheInvalidation` / `CacheInvalidationSink` remain metadata-only invalidation boundaries for future derived cache rebuild work.

`Frame` must remain lightweight.

Cache images must remain derived and rebuildable, not source of truth.

## User-facing label requirement

The HomePage top toolbar visible labels must remain:

```txt id="nust53"
Undo
Redo
```

Do not rename them back to:

```txt id="hi53hh"
Project Undo
Project Redo
```

This visible label choice must not change routing.

The top toolbar Undo / Redo buttons must not route to legacy `CanvasController`.

They must not call:

```txt id="mhvmfx"
_canvasController.undo()
_canvasController.redo()
_canvasController.canUndo
_canvasController.canRedo
```

They must also not call internal materialization undo/redo services directly.

## Scope

1. Audit the production brush route.

   Review:

    * `lib/src/ui/home_page.dart`
    * `lib/src/ui/brush/main_canvas_brush_host.dart`
    * `lib/src/ui/brush/brush_canvas_panel.dart`
    * `lib/src/ui/brush/interactive_brush_edit_canvas_view.dart`
    * `lib/src/services/brush_frame_editing_coordinator.dart`
    * `lib/src/services/brush_frame_store.dart`
    * current brush cache invalidation sink/model files

   Confirm that HomePage and brush widgets do not own source drawing payloads, cache images, baked surfaces, command buffers, or dirty state directly.

2. Strengthen production-vs-smoke boundaries.

   Production HomePage must not expose debug-only, smoke-only, or tutorial/demo-only brush UI.

   Smoke/dev/test screens may remain as isolated routes/files if they are not reachable from production HomePage accidentally.

   Add or strengthen architecture tests that guard this.

3. Strengthen source-of-truth boundaries.

   Confirm and guard that:

    * `Frame` owns only lightweight identity/timing/metadata.
    * `BrushFrameStore` owns brush drawing payload movement.
    * `BrushFrameDrawingState` may own frame-local brush dirty metadata.
    * `BrushFrameCacheInvalidation` remains metadata-only.
    * UI widgets do not become brush source of truth.
    * cache images are not used as source of truth.
    * internal materialization history is not exposed as user-facing undo.

4. Stabilize main canvas brush host behavior.

   Keep missing-selection behavior safe.

   If there is no valid active layer/frame selection, the main canvas brush host should show a safe placeholder rather than constructing fake editable state.

   If an active frame exists, the host should resolve the active `BrushFrameKey` consistently.

   Switching selection should not create stale source-of-truth state in widgets.

5. Stabilize action/status surface only if needed.

   Keep the UI compact and production-like.

   Do not add a large toolbar or broad new UI.

   If the current brush route has a small status or action ambiguity, clean it up narrowly.

   Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

6. Strengthen tests.

   Add or update focused tests for:

    * HomePage uses `MainCanvasBrushHost` as the production main canvas brush route.
    * legacy `CanvasView` / `CanvasController` brush state is not reintroduced into HomePage.
    * top toolbar visible labels are `Undo` / `Redo`.
    * top toolbar Undo / Redo routing does not call legacy `_canvasController`.
    * brush UI routes call `BrushFrameEditingCoordinator` public boundaries rather than internal materialization undo/redo helpers.
    * production HomePage does not expose smoke/debug-only brush UI.
    * missing active selection uses a safe placeholder.
    * active selection resolves a stable `BrushFrameKey`.
    * `Frame` remains lightweight.
    * `BrushFrameCacheInvalidation` remains metadata-only.
    * no `TileDelta` / `TileDeltaCommand` appears in brush runtime boundaries.
    * cache images remain derived and are not source of truth.

7. Documentation.

   Update `docs/Current_Brush_Architecture.md` and/or `docs/Current_UI_Product_Policy.md` only if this phase clarifies production readiness policy.

   Do not modify sections 0 through 4 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If the continuation state changes, update only section 8 of `docs/Handoff_QuickAnimaker_v2_Current.md`.

   If you discover issues that are too large for this phase, record them as future stabilization candidates rather than expanding this phase too much.

## Hard restrictions

Do not implement save/load.

Do not implement playback cache.

Do not implement real deferred bake.

Do not implement renderer cache generation.

Do not expand storyboard features.

Do not expand timeline features.

Do not do a large UI redesign.

Do not introduce Provider, Riverpod, Bloc, ChangeNotifier, hidden globals, or broad app-wide state management.

Do not make cache images source of truth.

Do not make UI widgets source of truth.

Do not put heavy brush payloads, command buffers, baked surfaces, preview caches, playback caches, or cache images into `Frame`.

Do not reintroduce `TileDelta` or `TileDeltaCommand`.

Do not call internal materialization undo/redo services directly from production UI.

## Future note

The user wants the brush area to become more reliably runnable and more complete after this phase.

Do not over-expand this phase.

Instead, leave the code and documentation ready for a later dedicated runtime stability / completion phase.

That future phase may focus on practical runtime behavior, manual usage issues, edge-case crashes, and overall production stability after this readiness sweep is merged.

## Validation

Run:

```sh id="urhd4k"
dart format lib test
flutter analyze
flutter test
git status
```

## PR notes

The PR description must include:

* Summary
* Production brush route audit notes
* Whether any production UI behavior changed
* Undo / Redo label confirmation
* Legacy CanvasController routing guard confirmation
* Smoke/debug UI exposure confirmation
* Source-of-truth boundary confirmation
* Cache/source separation confirmation
* Frame lightweight confirmation
* TileDelta / TileDeltaCommand absence confirmation
* Tests run
* Any follow-up stabilization candidates found but intentionally left out of this phase
