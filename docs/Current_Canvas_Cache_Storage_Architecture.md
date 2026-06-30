# Current Canvas, Cache, and Storage Architecture

## Source-of-truth rule

Canvas/cache/storage must align with current brush architecture without treating timeline range semantics as storage policy. Cache images are derived, not source of truth.

## Brush-aligned playback policy

- Playback must not replay live paint commands.
- Playback must not run brush rasterization.
- Playback should use prepared preview/composite bitmap cache images.
- `inactivePreviewCache` and `playbackPreviewCache` are derived images that can be invalidated and rebuilt from brush frame drawing state.

## Storage boundaries

Heavy bitmap payloads, paint command buffers, baked surfaces, preview caches, dirty flags, and similar frame-local drawing data belong in brush/canvas storage such as `BrushFrameStore`, not directly inside lightweight `Frame` metadata.

## Timeline separation

Canvas/cache/storage semantics must stay separate from timeline range semantics. `Cut.duration` is a playback/export boundary; it must not decide whether frame bitmap data can exist, whether caches can be stored, or whether authored drawing data is valid.

## Tile delta wording

Tile delta is not the current user-facing brush undo policy. Tile delta may appear only as a legacy implementation detail, possible low-level optimization, or internal bitmap mutation/storage detail. Do not describe tile delta as current user-facing undo.
