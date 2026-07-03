# Current Canvas, Cache, and Storage Architecture

## Source-of-truth rule

Canvas/cache/storage must align with current brush architecture without treating timeline range semantics as storage policy. Cache images are derived, not source of truth.

Runtime may not yet implement every item in this document. This file defines current policy and future implementation direction.

## Current policy

- Cache images are derived from source drawing payloads; they are not the source of truth.
- Heavy bitmap payloads, baked surfaces, preview caches, playback caches, image caches, dirty flags, and similar frame-local drawing/cache data belong in brush/canvas storage such as `BrushFrameStore`, not directly inside lightweight `Frame` metadata.
- `BrushFrameStore` or an equivalent brush/canvas storage boundary owns frame-local brush source drawing payloads keyed by frame identity.
- For Brush T2, the minimum source drawing payload is `BrushFrameDrawing.commands + hiddenCommandIds`.
- `Project`, `Cut`, `Frame`, `Stroke` / `BrushPaintCommand`, and `BrushFrameStore` must stay conceptually distinct:
  - `Project` owns lightweight project structure such as tracks and project-wide camera settings.
  - `Cut` owns playback/export duration, cut metadata, layers, and cut canvas size.
  - `Frame` owns lightweight identity/timing/name/storyboard metadata.
  - `Stroke` / stroke-like data and `BrushPaintCommand` data describe authored drawing input or brush actions where appropriate.
  - `BrushFrameStore` owns frame-local brush source payloads and later derived/baked/cache payloads.
- Timeline range semantics must not decide storage validity.
- `Cut.duration` is playback/export duration only.
- Authored drawing data can exist beyond `Cut.duration`.

## Project camera and Cut canvas policy

Brush T2 uses separate project camera and cut canvas concepts.

```txt
Project.cameraSize = 1920 x 1080 by default
Cut.canvasSize = 2340 x 1654 by default
```

`Project.cameraSize` is the project-wide camera/output frame size. All Cuts in a Project share this camera output size unless a future explicit camera-output architecture changes this policy.

`Cut.canvasSize` is the drawable/storage canvas bounds for that Cut. Each Cut may have its own canvas size.

The temporary production brush default canvas size of 320 x 240 is not part of the T2 policy and should be removed when the brush route starts using active Cut canvas settings.

## Drawable area policy

Brush T2 does not add a separate drawable-area model.

```txt
drawing bounds = Cut.canvasSize
```

Drawing source points should be recorded inside the active Cut canvas bounds.

Viewport interaction is separate from drawing bounds. Future pan/zoom/spacebar viewport movement may receive input outside the visual canvas area, but that does not create a separate drawable-area model for T2.

## Export size policy

The following export-size concepts are planned:

1. Canvas export
   - Outputs the active Cut canvas size.
   - Example default: 2340 x 1654.

2. Camera export
   - Outputs the Project camera frame size.
   - Example default: 1920 x 1080.

Storyboard-style output, TDTS output, XDTS output, and other timesheet/storyboard export formats are future export/sheet features. They must not redefine brush/canvas source storage semantics.

## Brush-aligned playback policy

- Playback should use prepared preview/composite bitmap cache images.
- Playback must not replay live paint commands.
- Playback must not run brush rasterization.
- Playback should not composite all layers from scratch when a valid cache exists.
- `inactivePreviewCache` and `playbackPreviewCache` are derived images that can be invalidated and rebuilt from brush frame drawing state.
- If a required cache is stale or missing, cache preparation should happen outside the hot playback path or be handled by future renderer/cache policy.

Brush T2 may defer playback cache implementation, but it must preserve the future policy that playback should not run live brush rendering.

## Storage boundaries

`Frame` should remain lightweight timing/identity/name/storyboard metadata. It should not embed brush source command lists, large bitmap surfaces, baked surfaces, preview/composite cache images, playback caches, image caches, or dirty state.

Brush source drawing data belongs outside `Frame` in `BrushFrameStore` or an equivalent brush/canvas storage boundary.

For T2, the minimum brush source storage is:

```txt
BrushFrameStore
- BrushFrameKey -> BrushFrameDrawing

BrushFrameDrawing
- commands: List<BrushPaintCommand>
- hiddenCommandIds: Set<BrushPaintCommandId>
```

`hiddenCommandIds` is source-state metadata used by global undo/redo to hide or restore source commands. It is not a cache image and not a bitmap payload.

Derived caches may be omitted, invalidated, or rebuilt. Source drawing payloads must be persisted when save/load is designed.

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
- Bitmap baking and cache image generation must not happen in the live stroke editing hot path.

## Tile delta wording

TileDelta / TileDeltaCommand are not current brush runtime architecture. They must not be used as brush commit results, brush undo/redo payloads, brush edit history entries, or cache-invalidation inputs. Sparse tile storage remains valid; dirty-region/dirty-tile APIs are the cache invalidation boundary.

## Phase 217 brush-frame invalidation boundary note

Brush edit commits, brush undo, and brush redo through `BrushFrameEditingCoordinator` now mark the affected `BrushFrameKey` dirty through the frame-local `BrushFrameStore` drawing state and may emit a lightweight `BrushFrameCacheInvalidation` through `CacheInvalidationSink`. The invalidation event carries the `BrushFrameKey` plus dirty tiles when the current materialization bridge has them; otherwise it can fall back to whole-frame invalidation. This boundary is only dirty metadata for future derived inactive-preview, playback, save/load, or renderer rebuild work. It does not generate cache images, does not make cache images source of truth, and does not move source brush payload ownership out of `BrushFrameStore`.


## Phase 222 brush frame display-cache foundation

Brush frame display now has a first derived preview-cache boundary owned by `BrushFrameStore` adjacent to the source drawing payload. The cache is keyed by `BrushFrameKey`, stores a rebuildable `BitmapSurface` preview plus dirty/revision metadata, and remains derived data rather than source of truth. Source artwork remains in `BrushFrameDrawing.commands + hiddenCommandIds`; `Frame` remains lightweight and does not own brush source payloads or preview/cache payloads.

Brush source commits, undo, redo, and deferred-bake state moves mark the matching display cache dirty and advance source revision metadata. Rebuilding is explicit through the display-cache service/renderer and is not performed by live pointer movement. Display routes can prefer a valid preview surface and layer the active stroke overlay over it, avoiding repeated source-command replay when a prepared preview exists. Full save/load, playback renderer integration, onion skin, and dirty-region partial rebuilds remain deferred.

## Brush T2 canvas/storage planning note

Brush T2 should begin from the simplest canvas/storage model that does not block future cache and baking work:

- Project owns camera size, default 1920 x 1080.
- Cut owns canvas size, default 2340 x 1654.
- No separate drawable-area model exists for T2.
- Drawing bounds equal active Cut canvas bounds.
- Frame remains lightweight and does not own drawing source payloads.
- BrushFrameStore owns `BrushFrameDrawing.commands + hiddenCommandIds`.
- Cache images, baked surfaces, and playback previews remain derived or future payloads, not source of truth.
