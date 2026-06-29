# Bitmap Canvas and Brush Architecture

> **Superseded notice**
>
> Current brush architecture source of truth: `docs/Brush_Architecture_Current.md`.
>
> This file is kept only as a legacy Brush V1 / bitmap-tile implementation snapshot. It is not an independent current architecture source.

## Legacy status

Earlier Brush V1 planning explored tile-delta-centered undo flows for bitmap editing internals. That wording is superseded for app-complete brush architecture.

Current user-facing brush undo is based on recent live paint commands / stroke-like paint commands through `UnifiedUndoHistory`, with a custom user undo limit and a separate non-user-facing deferred bake buffer.

Tile delta may still exist as a legacy implementation detail, possible future low-level optimization, or internal bitmap detail, but tile delta is not the current user-facing undo policy.

For current policy, see `docs/Brush_Architecture_Current.md`.
