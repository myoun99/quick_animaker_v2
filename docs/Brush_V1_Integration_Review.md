# Brush V1 Integration Review

> **Legacy Brush V1 review document.**
>
> Not the current app-complete brush architecture source of truth.
>
> Current source: `docs/Brush_Architecture_Current.md`.


## Status

Brush V1 is internally implemented as a testable smoke/dev stack. It is not wired into the main application entrypoint or production route flow.

## Core data flow

Pointer input is sampled by the interactive canvas and accumulated into a transient `BrushDabSequence`. On pointer completion, the sequence is submitted through the cache-aware commit facade. The commit updates a `BrushEditSessionState`, applies tile changes to the `BitmapSurface` held by `CanvasSurfaceState`, records brush edit history, produces a cache invalidation result, and lets the UI rebuild from the returned session state.

## Bitmap principle

Final visible artwork is `BitmapSurface` tile data. `BrushDabSequence` is transient input and commit data for a single brush operation. A stroke or dab sequence is not the permanent display source of truth and should not be replayed for display.

## Session state

`BrushEditSessionState` owns the current `CanvasSurfaceState` and `BrushEditHistoryState`. `InteractiveBrushEditCanvasView` performs brush commit operations. `InteractiveBrushCanvasSmokeHost` can own local session state and can accept explicit session replacement through `sessionResetToken`. `BrushCanvasSmokeScreen` owns canonical smoke/dev session state for undo, redo, reset, color preset, and debug status controls.

## Undo / Redo

Undo and redo are based on `BrushEditHistoryState` and the existing cache-aware session facades. They apply or revert bitmap tile deltas through session state operations. Display does not replay strokes or dab sequences.

## Cache invalidation

Commit, undo, and redo use cache invalidation plans and results. The smoke screen uses a recording invalidation sink to count invalidations for debug status. No renderer cache, disk cache, cache storage, or cache recomputation system is implemented by Brush V1.

## UI status

`BitmapSurfacePainter` is display-only. `BrushEditCanvasView` displays a `BitmapSurface`. `InteractiveBrushEditCanvasView` handles pointer input and commits completed brush input. `InteractiveBrushCanvasSmokeHost` is a local/stateful smoke host. `BrushCanvasSmokeScreen` is a dev/manual harness with undo, redo, reset, color presets, and debug status.

## Explicitly out of scope

- Main app wiring.
- Production toolbar.
- Layer panel integration.
- Timeline integration.
- Storyboard integration.
- Save/load.
- Renderer cache.
- Disk cache.
- Onion skin.
- Playback preview.
- Stylus pressure.
- Smoothing.
- Eraser.
- Selection.

## Regression coverage

Current regression coverage includes:

- Tap commit.
- Drag commit.
- Repeated strokes.
- Pointer cancel.
- Multi-pointer handling.
- Out-of-bounds movement.
- Undo, redo, and reset.
- Color presets.
- Canvas-relative gesture helpers.
- Host `sessionResetToken` behavior.
- Scope guards for app wiring, state management package boundaries, direct smoke-screen commit facade calls, and Storyboard/Timeline isolation.
