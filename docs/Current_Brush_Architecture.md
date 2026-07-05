# Current Brush Architecture

## Status

This is the canonical current brush architecture source of truth for QuickAnimaker v2.
Older brush documents and phase task documents are historical unless they explicitly defer to this file.

The current brush architecture uses **Deferred Bake Hybrid Brush History** as the long-term policy. The current accepted Brush T2 runtime baseline is the Phase 224 / PR #294 production route.

Runtime code has not necessarily implemented every future item described here. This document defines current architecture policy and future implementation direction without changing runtime behavior.

## Latest policy summary

The latest policy is:

1. Brush input creates stroke-like / paint-command information.
2. User-facing undo is based on recent live paint commands / stroke-like paint commands through `UnifiedUndoHistory`.
3. A custom `userUndoLimit` controls how many recent brush commands are user-undoable.
4. A separate `deferredBakePaintCommands` concept exists for older commands waiting to be baked.
5. The deferred bake buffer is conceptually about 10% of the user undo limit when implemented.
6. The deferred bake buffer is not user-facing undo.
7. Older commands may eventually be compacted into `bakedBaseSurface`.
8. The active edit display is WYSIWYG: committed strokes render from the materialized session `BitmapSurface` (via the tile-image display cache), and the in-progress stroke renders as a tip alpha-mask stamp overlay that previews the commit rasterizer result. Future baked-base work extends the same surface-based display.
9. Cache images are derived from brush frame drawing state and are not source of truth.
10. Playback uses prepared preview/composite bitmap cache images.
11. Playback must not replay live paint commands.
12. Playback must not run live brush rasterization.
13. Brush T2 starts with the lightest practical source-data model: `BrushFrameDrawing.commands + hiddenCommandIds`, with no per-frame `visibleCommandCount`.
14. Brush-specific undo/redo controls do not exist. Brush stroke undo/redo participates only in app-level global undo/redo through `HistoryManager`, `BrushStrokeHistoryCommand`, `BrushFrameEditingCoordinator`, and `BrushFrameStore.hiddenCommandIds`.

## Brush T2 minimum direction

Brush T2 is the next brush milestone after the T1 production-route cleanup.

T2 means the brush becomes basically usable: realtime stroke display is visible while drawing, selected layer/frame drawing is routed through the production brush store, global undo/redo handles brush strokes, and the temporary 320x240 brush canvas default is removed in favor of the active Cut canvas policy.

T2 should stay lightweight. It must not try to implement the full future renderer, save/load, playback cache, real deferred baking, or complete bitmap compaction system in one step.

For T2, discard unnecessary implementation state:

- Do not use a per-frame `visibleCommandCount`.
- Do not add brush-specific undo/redo.
- Do not keep drawing source payloads inside `Frame`.
- Do not add a separate drawable-area model.
- Do not bake bitmap data in the live editing hot path.
- Do not generate cache images while the user is actively editing a stroke.

## Core concepts

- `BrushPaintCommand`: source stroke/paint-command data authored by brush input.
- `BrushPaintCommandId`: identity for a brush paint command.
- `BrushFrameDrawing`: lightweight source drawing payload for a single brush frame key. The T2 minimum shape is `commands + hiddenCommandIds`.
- `hiddenCommandIds`: command ids hidden by global undo but retained for redo while the command remains in the global redo stack.
- `bakedBaseSurface`: bitmap/tile data containing old confirmed artwork that has been compacted and is no longer individually user-undoable.
- `deferredBakePaintCommands`: older paint commands that have left user-facing undo but are intentionally not baked immediately. This is a future/full-policy concept and does not need to be physically implemented in the T2 minimum model.
- `livePaintCommands`: recent paint/stroke-like commands that remain user-undoable. In the T2 minimum model, these are represented by visible commands in `BrushFrameDrawing.commands` that are not in `hiddenCommandIds` and are still represented by global undo entries.
- `activeStrokeOverlay`: temporary in-progress drawing overlay for active input before commit.
- `inactivePreviewCache`: derived preview/composite image for inactive frame display.
- `playbackPreviewCache`: derived preview/composite bitmap cache image for playback.
- `dirty flags`: metadata marking which previews, composites, or cached images need refresh.
- `userUndoLimit`: user-configurable number of undoable brush commands.
- `deferredBakeRatio`: default conceptual ratio used to size the deferred bake buffer, approximately 10%.
- `deferredBakeLimit`: maximum number of non-user-undoable deferred bake commands retained before baking pressure applies.
- `UnifiedUndoHistory`: the one global user-facing undo/redo order across brush, project, timeline, layer, and cut changes.
- `BrushFrameStore`: frame-keyed owner of brush frame drawing payloads and frame-local paint command state.

## Brush frame drawing state

A full brush frame drawing payload conceptually contains:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
+ hiddenByUndoPaintCommands, if needed for redo
+ inactivePreviewCache / playbackPreviewCache
+ dirty flags
```

The T2 minimum runtime/source model should start simpler:

```txt
BrushFrameDrawing
- commands: List<BrushPaintCommand>
- hiddenCommandIds: Set<BrushPaintCommandId>
```

`commands` stores source stroke/paint-command data. `hiddenCommandIds` records commands hidden by global undo. Visible commands are commands whose ids are not in `hiddenCommandIds` and whose source has not been compacted into a baked base.

`visibleCommandCount` is not part of the T2 model. It is only useful for a brush-local linear history and creates unnecessary duplicated state when user-facing undo is global.

`BrushFrameStore` owns this frame-local drawing payload, keyed by `BrushFrameKey`. Frame remains lightweight; heavy brush bitmap payloads, brush command lists, baked surfaces, dirty state, and cache images belong outside `Frame` in `BrushFrameStore` or an equivalent brush/canvas storage boundary. A `Frame` remains lightweight metadata and should not embed heavy bitmap surfaces, command lists, or cache images directly.

## Phase 303 brush settings panel and spacing policy

Phase 303 keeps brush size, opacity, color, and spacing as editor-session tool state in `BrushToolState`, owned by the editor session / `HomePage` boundary. This state is not Project, Cut, Layer, Frame, Stroke, brush command, cache, playback, camera, persistence, or save/load schema data.

`BrushToolState.spacing` is a brush dab sampling ratio, where the effective sampling interval is based on brush size multiplied by spacing. Smaller spacing produces denser future dabs; larger spacing produces wider future dab intervals. Spacing affects future sampling only. Existing committed strokes are not rewritten when spacing changes because committed source dabs already carry the materialized rendering values for the stroke that was drawn.

`BrushSettingsPanel` is the primary editable brush settings UI. `BrushCanvasPanel` should receive brush tool state for drawing input only and should remain focused on viewport display, panbars, zoom/fit/reset, canvas clipping, and drawing input. It should not own brush setting mutation callbacks or duplicate editable brush controls.

Active strokes snapshot brush input settings at pointer down. Size, opacity, color, spacing, flow, hardness, and tip shape used by an in-progress stroke must come from that active-stroke snapshot until pointer up/cancel. Mid-stroke UI changes therefore affect future strokes only and must not alter the currently active stroke or already committed strokes.

This panel and settings direction is Photoshop-like in structure, but it is not Photoshop ABR import support and does not imply exact Photoshop brush engine parity. Future settings such as hardness, flow, angle, roundness, pressure, smoothing, texture, dual brush, and presets should fit this boundary without forcing source/save schema changes for editor-session UI state.

## Active editing display (WYSIWYG, post-P4)

The active frame display formula is:

```txt
activeFrameDisplay =
  materialized session BitmapSurface (committed strokes)
  + activeStrokeOverlay (tip alpha-mask stamps for the in-progress stroke)
```

Committed strokes are rasterized into the session `BitmapSurface` at commit time (`commitSourceStroke` materializes and stores the source-dab command in one step) and displayed through the identity-keyed `BitmapTileImageCache` as one `drawImage` per tile - O(tiles), independent of stroke count. The in-progress stroke is stamped from `BrushTipMaskCache` alpha masks (same coverage math as the commit rasterizer: hard core to `radius * hardness`, linear falloff to the radius), tinted at `alpha * opacity * flow`. Sequential source-over stamping matches the rasterizer sequential blend, so what the user sees while drawing is what commits on pointer-up. `BrushTipMaskCache` is the substrate for future custom/ABR tip shapes.

The active stroke overlay is an editing-only layer for current input. It is not a playback mechanism and is not a durable source of truth. No bitmap is baked while the pointer is moving: the overlay is pure stamping, and rasterization happens once per stroke at commit.

Active editing must not use `displayPreviewSurface`, `inactivePreviewCache`, or `playbackPreviewCache` as the active editor base. It must not use a drawPath-based smooth vector brush display or `TileDelta` / `TileDeltaCommand`.

A stroke that changes no pixels commits to nothing: no paint command, no undo entry. Creating an undo entry without a matching bitmap materialization entry would desynchronize the command history from the bitmap history.

Historical note: the Phase 224 / PR #294 T2 baseline displayed committed strokes as square source-dab stamps because materialize-on-commit cost up to 8.5s per stroke (the reason PR #293 failed). The P1 commit-path rewrite (~800x) made materialization at commit time cheap (~10ms worst case), which is what enabled this WYSIWYG display model.

## User-facing undo / redo

User-facing undo is global only.

Brush-specific undo/redo controls do not exist.

User-facing undo for brush strokes is based on recent live paint commands through the app-level global command stack. In the current production route, `HistoryManager` executes `BrushStrokeHistoryCommand`; the command commits through `BrushFrameEditingCoordinator`, and undo/redo hide or restore source commands through `BrushFrameStore.hiddenCommandIds`. Internal `UnifiedUndoHistory` remains below that app-level boundary and must not become a separate brush-local user control.

A brush stroke undo command should be lightweight. It should reference `BrushFrameKey` plus `BrushPaintCommandId` rather than duplicating the full stroke payload.

Undo should hide the command by adding the command id to `hiddenCommandIds` while the command remains redoable.

Redo should unhide the command by removing the command id from `hiddenCommandIds`.

Deferred bake buffer commands are not user-undoable.

Baked commands are not user-undoable as individual commands.

The app-level history owns global user-facing undo order. `BrushFrameStore` owns frame-local payload movement for brush commands but does not decide the global undo order.

## Current production display/commit baseline (P4, supersedes the PR #294 square-stamp baseline)

- Committed strokes display from the materialized session `BitmapSurface`; the in-progress stroke displays as tip alpha-mask stamps.
- `commitSourceStroke` stores source dabs as the durable `BrushPaintCommand` AND materializes the stroke into the session surface in one step; no-op strokes (no pixel changes) create no command and no undo entry.
- The active route must not use an active drawPath brush display.
- The active route must not use `displayPreviewSurface` or inactive/playback preview cache images as the active editor base.
- Brush strokes participate in app-level global undo/redo through `HistoryManager` and `BrushStrokeHistoryCommand`.
- Undo/redo hides and restores source commands with `BrushFrameEditingCoordinator` / `BrushFrameStore.hiddenCommandIds`, and reverts/reapplies the materialized bitmap through the session materialization history in the same operation.
- Timeline frame selection must remain stable after brush undo/redo.

Historical: PR #294 square-stamp display was the T2 baseline before the P1-P4 performance work; PR #293 failed because pre-P1 materialization was unusably slow and its undo route was wrong. Neither is a current reference.

## User undo limit and deferred bake buffer

The policy separates user-facing undo from delayed baking:

```txt
userUndoLimit = user-configurable number of undoable brush commands
deferredBakeRatio = default approximately 10%
deferredBakeLimit = max(minimumBuffer, round(userUndoLimit * deferredBakeRatio))
```

Example:

```txt
userUndoLimit = 250
deferredBakeRatio = 10%
deferredBakeLimit = 25
```

The deferred bake buffer is not an undo buffer.
The deferred bake buffer is not user-facing undo.
It exists only to delay baking and keep active drawing responsive.

T2 does not need to physically implement deferred baking immediately. T2 may begin with visible source commands plus hidden command ids only, as long as the code does not block the later deferred-bake and baked-base extension.

## Baking policy

Older commands beyond the custom user undo limit may eventually move from live source commands into deferred-bake candidates.

Old deferred commands may eventually be baked into `bakedBaseSurface`. Once baked, those commands are represented by bitmap/tile data and are not individually user-undoable.

Baking is an internal compaction policy for old artwork. It must not be confused with user-facing undo.

No bitmap baking should happen in the live editing hot path.

Do not bake while the user is drawing.
Do not fully bake merely because the pointer is released.
Do not generate cache-baked images during active editing.

Future baking should happen at safe moments such as frame switch, idle processing, explicit cache preparation, or after a command leaves the user undo window.

## Cache image generation

`inactivePreviewCache` / `playbackPreviewCache` are derived images.

They are produced from brush frame drawing state, such as:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
```

or from the T2 minimum equivalent:

```txt
visible BrushPaintCommands
```

They are used for inactive frame display and playback.

They are not the source of truth.

Cache images may be regenerated when dirty flags indicate that the underlying brush frame state changed.

Cache image generation must not happen in the live stroke editing hot path.

## Playback policy

Playback uses preview/composite bitmap cache images.

Playback must not replay live paint commands.
Playback must not replay old strokes.
Playback must not run brush rasterization.
Playback must not composite all layers from scratch every frame if a valid preview/composite cache exists.

If a playback cache is stale or missing, it should be prepared outside the live playback path or treated as dirty according to the renderer/cache policy of a future phase.

T2 may defer playback cache implementation. It must still preserve the rule that future playback should use prepared derived images rather than running live brush rendering in the playback loop.

## Frame / BrushFrameStore ownership

`Frame` owns identity, timing, name/label, and lightweight metadata.

`Frame` does not directly own brush source drawing payloads, brush command lists, heavy bitmap surfaces, baked surfaces, preview caches, playback caches, image caches, or dirty state.

`BrushFrameStore` owns frame drawing payloads, including the T2 minimum `BrushFrameDrawing.commands + hiddenCommandIds` model and later `bakedBaseSurface`, deferred-bake commands, preview caches, playback caches, and dirty flags.

`UnifiedUndoHistory` references brush payloads as part of a global undo sequence but does not make cache images or bitmap previews into source-of-truth drawing data.

## Brush input sampling

T2 input should not rely on raw pointer-move events alone.

Brush input should collect pointer points and apply lightweight spacing/interpolation based on brush size so fast strokes do not visually break while avoiding excessive point generation.

A Bresenham-style line fill may be used as a low-level idea for connecting sampled points, but the T2 policy is brush-spacing interpolation rather than a pure one-pixel line algorithm.

## What is current vs legacy

Current policy:

- Deferred Bake Hybrid Brush History.
- User-facing undo is recent live paint command / stroke-like command based through global undo only.
- The deferred bake buffer is separate from user-facing undo.
- The brush frame source model is `commands + hiddenCommandIds`; source dabs remain the durable source of truth even though commits also materialize into the session surface for display.
- Cache images are derived from brush frame state.
- Playback uses preview/composite bitmap cache images and avoids live command replay/rasterization.

Legacy or lower-level implementation details:

- TileDelta / TileDeltaCommand must not be used by brush commit results, brush edit history entries, brush undo/redo payloads, or brush cache-invalidation APIs.
- Sparse bitmap tile storage remains valid: BitmapSurface, BitmapTile, TileCoord, DirtyRegion, and DirtyTileSet may be used for storage and invalidation boundaries.
- Any future low-level bitmap mutation optimization must stay behind brush-domain APIs and must not reintroduce TileDelta / TileDeltaCommand as brush runtime architecture.

## Explicitly not the current policy

The current policy is not:

- Tile delta as the user-facing undo source.
- User-facing undo as `TileDeltaCommand`.
- Tile delta as the primary brush undo model.
- Brush-local undo/redo separate from global undo/redo.
- Per-frame `visibleCommandCount` as the T2 source of user-facing undo.
- Brush display based on replaying every old stroke in playback.
- Playback replaying strokes.
- Playback running brush rasterization.
- Live editing that bakes bitmap data on every pointer move. (Rasterizing once per stroke at commit/pointer-up is the current model; per-move baking remains banned.)
- Committed-stroke display that re-renders per-dab stamps every frame instead of using the materialized surface.

## Phase 213C UI undo route safety note

UI-facing brush undo/redo routes, including smoke and canvas hosts, must call `BrushFrameEditingCoordinator.undo()` / `BrushFrameEditingCoordinator.redo()` rather than direct bitmap materialization undo/redo helpers. The coordinator is the public brush editing boundary for production-facing undo: it takes entries from `UnifiedUndoHistory`, moves paint-command state in `BrushFrameStore`, and may use the session-local bitmap materialization bridge only below that boundary to refresh temporary `BitmapSurface` display.

`BrushBitmapMaterializationHistoryState`, `BrushBitmapMaterializationHistoryEntry`, `BrushCommitResult`, and the materialization undo/redo services remain internal/session-local bitmap materialization bridges. They are not public UI/user undo history, not durable brush command history, and not a replacement for `UndoPayloadRef.paintCommand -> BrushFrameStore -> BrushPaintCommand`.

## Future implementation phases

Future phases may implement actual deferred baking, preview cache generation, playback cache preparation, renderer cache behavior, save/load integration, or memory-estimation UI.

Those phases must preserve this policy unless a newer canonical architecture document explicitly supersedes it.

## Brush V1 implementation snapshot retained as context

Brush V1 completed an internal smoke/dev/test stack with BitmapSurface / BitmapTile storage, BrushDabSequence input, brush pixel blending, commit/undo/redo services, cache invalidation facades, BitmapSurfacePainter display, InteractiveBrushEditCanvasView, and smoke-screen regression coverage. That stack is context only: it is not app-complete and must not be restored into production routes merely to satisfy legacy documentation tests.

The V1-style global command stack idea remains useful as an architectural direction for T2: brush strokes should participate in one global undo/redo order. However, T2 commands should remain lightweight references such as `BrushFrameKey + BrushPaintCommandId`, not large copied payload snapshots.

TileDelta / TileDeltaCommand are not the current brush runtime policy. They must not appear in brush commit, undo, redo, edit history, or cache-invalidation boundaries.

## Historical naming decisions retained for current integration context

### Phase 206 BrushWorkspaceCoordinator naming cleanup preparation

BrushWorkspaceCoordinator is no longer tied to the deleted BrushWorkspaceScreen route. BrushWorkspaceCoordinator is currently a production brush editing coordination service. The planned naming direction was BrushWorkspaceCoordinator -> BrushFrameEditingCoordinator. BrushWorkspaceCacheInvalidationSink should be considered separately. Left runtime behavior unchanged. Did not rename BrushWorkspaceCoordinator yet. Did not rename BrushWorkspaceCacheInvalidationSink. Did not reintroduce deleted workspace UI or debug controls.

### Phase 207 BrushFrameEditingCoordinator runtime rename

Renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator. Renamed brush_workspace_coordinator.dart to brush_frame_editing_coordinator.dart. Kept runtime behavior unchanged. BrushWorkspaceCacheInvalidationSink was not renamed in this phase.

### Phase 208 BrushWorkspaceCacheInvalidationSink naming decision

BrushWorkspaceCacheInvalidationSink is no longer tied to deleted BrushWorkspaceScreen / BrushWorkspaceView UI. BrushWorkspaceCacheInvalidationSink currently acts as the cache invalidation sink boundary used by brush editing flows. BrushWorkspaceCacheInvalidationSink -> BrushEditCacheInvalidationSink. Why BrushEditCacheInvalidationSink: it names the brush-edit cache invalidation boundary without implying a deleted workspace UI. Left runtime behavior unchanged. Did not rename BrushWorkspaceCacheInvalidationSink yet. Did not rename brush_workspace_cache_invalidation_sink.dart yet.

### Phase 209 BrushEditCacheInvalidationSink runtime rename

Renamed BrushWorkspaceCacheInvalidationSink to BrushEditCacheInvalidationSink. Renamed brush_workspace_cache_invalidation_sink.dart to brush_edit_cache_invalidation_sink.dart. Updated production imports to use BrushEditCacheInvalidationSink. Updated tests to use BrushEditCacheInvalidationSink. Kept cache invalidation semantics unchanged.

## Phase 213B source-of-truth boundary note

Runtime naming now separates production user-facing brush undo from the temporary bitmap materialization bridge:

- `UnifiedUndoHistory` is the production-facing global user undo/redo order.
- `UndoPayloadRef.paintCommand` points user undo entries at brush paint-command payloads.
- `BrushFrameStore` owns frame-local brush payload movement for live, hidden-by-undo, deferred-bake, and baked paint commands.
- `BrushPaintCommand` is the brush command identity / payload boundary and carries a minimal internal `materializationRef` bridge to the current bitmap materialization payload while full persistence/deferred bake payload design remains future work.
- `BrushBitmapMaterializationHistoryState` and `BrushBitmapMaterializationHistoryEntry` are internal session-local bitmap materialization helpers only; they are not user-facing brush undo source of truth.
- `BrushCommitResult` remains an internal before/after `BitmapSurface` materialization bridge only; it is not durable brush command history.

## Phase 217 brush-frame invalidation boundary note

Brush edit commits, brush undo, and brush redo through `BrushFrameEditingCoordinator` now mark the affected `BrushFrameKey` dirty through the frame-local `BrushFrameStore` drawing state and may emit a lightweight `BrushFrameCacheInvalidation` through `CacheInvalidationSink`. The invalidation event carries the `BrushFrameKey` plus dirty tiles when the current materialization bridge has them; otherwise it can fall back to whole-frame invalidation. This boundary is only dirty metadata for future derived inactive-preview, playback, save/load, or renderer rebuild work. It does not generate cache images, does not make cache images source of truth, and does not move source brush payload ownership out of `BrushFrameStore`.

## Phase 218 production readiness note

The production main-canvas brush route remains `HomePage -> MainCanvasBrushHost -> BrushCanvasPanel -> InteractiveBrushEditCanvasView -> BrushFrameEditingCoordinator -> BrushFrameStore`. `MainCanvasBrushHost` must resolve a real active `BrushFrameKey` from the editor selection before constructing editable brush state; when no valid active layer/frame selection exists, it shows the safe empty-selection placeholder instead of creating a fake placeholder frame. Production HomePage must not expose brush smoke/debug/tutorial UI, and UI widgets on this route must not own source drawing payloads, command buffers, baked surfaces, cache images, or brush dirty state.

## Brush T2 planning note

Brush T2 starts from the simplified source model and global undo decisions captured above:

- `BrushFrameDrawing.commands + hiddenCommandIds` is the minimum source drawing model.
- `visibleCommandCount` is intentionally excluded.
- Brush strokes use global undo/redo only.
- `BrushStrokeCommand`-like history entries should be lightweight references to `BrushFrameKey + BrushPaintCommandId`.
- `Frame` remains lightweight and does not directly own brush drawing data.
- Realtime drawing uses `activeStrokeOverlay` and visible source commands, not live bitmap baking.
- Bitmap baking and cache image generation are future work and must stay outside the live editing hot path.

## Phase 302 brush tool state and options UI

Brush size, opacity, and color are editor-session tool settings owned by the UI/editor session, not source data. `HomePage` owns the current `BrushToolState` and passes it through `MainCanvasBrushHost` into `BrushCanvasPanel`, where the state is converted to `BrushEditCanvasInputSettings` for `InteractiveBrushEditCanvasView` when new dabs are sampled.

The compact production brush options bar lives in the canvas editor panel directly below the canvas title/status row. It exposes size, opacity, color swatches, and a concise current-setting display while keeping viewport, panbar, boundary clipping, and undo/redo responsibilities in their existing canvas/editor components.

Committed source dabs continue to carry the materialized brush values needed to render the stroke that was drawn. Changing the editor brush tool state only affects future strokes and does not rewrite existing strokes. The state is intentionally not serialized in Project, Cut, Layer, Frame, Stroke, cache, playback, camera, or save/load data.

Future brush work can expand this editor-session boundary with presets, eraser mode, pressure controls, color picker, and shortcuts without moving transient tool options into source models or adopting broad app-wide state management.
