# Current Canvas, Cache, and Storage Architecture

## Source-of-truth rule

Canvas/cache/storage must align with current brush architecture without treating timeline range semantics as storage policy. Cache images are derived, not source of truth.

Runtime may not yet implement every item in this document. This file defines current policy and future implementation direction.

## Current policy

- Cache images are derived from source drawing payloads; they are not the source of truth.
- Heavy bitmap payloads, paint command buffers, baked surfaces, preview caches, dirty flags, and similar frame-local drawing data belong in brush/canvas storage such as `BrushFrameStore`, not directly inside lightweight `Frame` metadata.
- `BrushFrameStore` or an equivalent brush/canvas storage boundary owns frame-local drawing payloads keyed by frame identity.
- `Project`, `Stroke`, `PaintCommand`, and `BrushFrameStore` must stay conceptually distinct:
  - `Project` owns lightweight project structure such as tracks, cuts, layers, and frames.
  - `Stroke` / stroke-like data and `PaintCommand` data describe authored drawing input or brush actions where appropriate.
  - `BrushFrameStore` owns the heavy frame-local drawing payload, command buffers, baked bitmap surfaces, and derived caches.
- Timeline range semantics must not decide storage validity.
- `Cut.duration` is playback/export duration only.
- Authored drawing data can exist beyond `Cut.duration`.

## Brush-aligned playback policy

- Playback should use prepared preview/composite bitmap cache images.
- Playback must not replay live paint commands.
- Playback must not run brush rasterization.
- Playback should not composite all layers from scratch when a valid cache exists.
- `inactivePreviewCache` and `playbackPreviewCache` are derived images that can be invalidated and rebuilt from brush frame drawing state.
- If a required cache is stale or missing, cache preparation should happen outside the hot playback path or be handled by future renderer/cache policy.

## Storage boundaries

Heavy bitmap payloads, paint command buffers, baked surfaces, preview caches, dirty flags, and similar frame-local drawing data belong in brush/canvas storage such as `BrushFrameStore`, not directly inside lightweight `Frame` metadata.

`Frame` should remain lightweight timing/identity/metadata. It should not embed large bitmap surfaces, command lists, or preview/composite cache images.

## Timeline separation

Canvas/cache/storage semantics must stay separate from timeline range semantics. `Cut.duration` is a playback/export boundary; it must not decide whether frame bitmap data can exist, whether caches can be stored, or whether authored drawing data is valid.

Authored frames and drawing payloads beyond `Cut.duration` may remain valid project data. Editing beyond `Cut.duration` must not implicitly become a storage allocation or storage deletion rule.

## Long-term shared material/source ownership candidate

A project-level or repository-level drawing material/source ownership model may be needed later for robust cross-layer or cross-cut sharing. This remains a long-term candidate only.

If introduced, it must preserve the current separation between lightweight project structure, frame-local brush payload storage, and derived caches. It must not make timeline placement, exposure duration, marks, blank/X positions, selected cell state, cache images, or playback previews into shared source-of-truth data merely because drawing material/source is shared.

Do not add project-level material/source ownership as a shortcut before brush/canvas storage ownership, save/load source-payload boundaries, and linked Cut/Layer policy are explicitly designed in current documents.

## Future implementation direction

- Dirty flags, dirty regions, and dirty tiles are cache invalidation concepts; brush cache invalidation must use dirty-region/dirty-tile boundaries rather than TileDelta / TileDeltaCommand.
- Sparse tile allocation is the preferred future storage direction.
- Do not eagerly allocate every tile in every frame or layer.
- Cache invalidation should be explicit enough to rebuild derived previews/composites without making cache images durable source data.
- Save/load must distinguish source payload from derived caches.
- Source drawing payloads must be persisted.
- Derived caches may be omitted, invalidated, or rebuilt.

## Tile delta wording

TileDelta / TileDeltaCommand are not current brush runtime architecture. They must not be used as brush commit results, brush undo/redo payloads, brush edit history entries, or cache-invalidation inputs. Sparse tile storage remains valid; dirty-region/dirty-tile APIs are the cache invalidation boundary.
