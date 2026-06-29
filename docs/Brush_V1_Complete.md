# Brush V1 Complete

> **Legacy Brush V1 smoke/dev/test stack document.**
>
> Not the current app-complete brush architecture source of truth.
>
> Current source: `docs/Brush_Architecture_Current.md`.


## Status

Brush V1 is complete as an internal smoke/dev/test stack.

It is not yet wired into the main app.

## Completed capabilities

- BitmapSurface / BitmapTile storage foundation.
- BrushDab / BrushDabSequence transient input model.
- Brush pixel blending.
- BrushDabSequence commit to BitmapSurface.
- CanvasSurfaceState integration.
- Brush edit history entries.
- Brush edit history state.
- Undo service.
- Redo service.
- Cache invalidation execution.
- BrushEditSessionState.
- Cache-aware commit / undo / redo facades.
- Display-only BitmapSurfacePainter.
- BrushEditCanvasView.
- InteractiveBrushEditCanvasView pointer input.
- InteractiveBrushCanvasSmokeHost.
- BrushCanvasSmokeScreen dev/manual harness.
- Undo / redo / reset / color preset dev controls.
- Regression coverage for tap, drag, repeated strokes, pointer cancel, multi-pointer, out-of-bounds movement, undo, redo, reset, color presets, canvas-relative gestures, and sessionResetToken behavior.
- Scope guards preventing accidental main app wiring and direct smoke-screen commit calls.

## Source of truth

Final visible artwork is BitmapSurface tile data.

BrushDabSequence is transient input data.

Stroke or dab sequence replay is not the permanent display source of truth.

## Current UI boundary

Brush V1 exists as a smoke/dev/test stack.

The main app does not expose BrushCanvasSmokeScreen.

No production toolbar has been implemented.

No layer panel integration has been implemented.

No TimelinePanel integration has been implemented.

No StoryboardPanel integration has been implemented.

## Intentionally out of scope

- Main app route wiring.
- Production brush toolbar.
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
- Brush cursor.
- Brush preview overlay.

## Next area

The next major work area is Storyboard panel work.

Brush V1 should remain stable while Storyboard work proceeds.
