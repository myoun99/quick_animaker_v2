# Current Canvas, Cache, and Storage Architecture

## Bitmap-first canvas direction

Drawn artwork is bitmap-first. Stroke-like data can exist as input metadata or live paint commands, but user-visible drawing and playback should be represented by bitmap surfaces and prepared cache images according to brush policy.

## Canvas ownership rules

- `CanvasViewport` is pure coordinate conversion and must not depend on Flutter `Offset`, `PointerEvent`, `Canvas`, `Paint`, or `CustomPainter`.
- `Frame` stays lightweight. Heavy drawing payloads belong in dedicated frame drawing stores such as `BrushFrameStore`.
- Active stroke overlays are editing-only temporary layers and are not durable source of truth or playback mechanisms.

## Cache policy

- Preview, inactive-frame, frame-composite, and playback cache images are derived data.
- Derived cache images are not source of truth.
- Dirty flags or invalidation records should identify what must be regenerated.
- Playback should use prepared preview/composite bitmap cache images.
- Playback must not replay live paint commands, replay old strokes, run live brush rasterization, or recomposite every layer from scratch when a valid cache exists.

## Storage direction

- Persistence should store durable project/domain data and durable bitmap drawing payloads, not transient UI viewport state.
- Future storage may use tiles, snapshots, compaction, or low-level deltas as implementation details.
- Low-level tile/delta concepts are not the current user-facing brush undo policy. User-facing brush undo is defined in `docs/Current_Brush_Architecture.md`.
