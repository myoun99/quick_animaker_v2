# Current Brush Architecture

## Status

This is the canonical current brush architecture source of truth for QuickAnimaker v2.
Older brush documents and phase task documents are historical unless they explicitly defer to this file.

The current brush architecture uses **Deferred Bake Hybrid Brush History**.

Runtime code has not necessarily implemented every item described here. This document defines the current architecture policy and future implementation direction without changing runtime behavior.

## Latest policy summary

The latest policy is:

1. Brush input creates stroke-like / paint-command information.
2. User-facing undo is based on recent live paint commands / stroke-like paint commands through `UnifiedUndoHistory`.
3. A custom `userUndoLimit` controls how many recent brush commands are user-undoable.
4. A separate `deferredBakePaintCommands` buffer exists for older commands waiting to be baked.
5. The deferred bake buffer is conceptually about 10% of the user undo limit.
6. The deferred bake buffer is not user-facing undo.
7. Older commands may be compacted into `bakedBaseSurface`.
8. Active frame display is composed from `bakedBaseSurface + deferredBakePaintCommands + livePaintCommands + activeStrokeOverlay`.
9. Cache images are derived from brush frame drawing state and are not source of truth.
10. Playback uses prepared preview/composite bitmap cache images.
11. Playback must not replay live paint commands.
12. Playback must not run live brush rasterization.

## Core concepts

- `bakedBaseSurface`: bitmap/tile data containing old confirmed artwork that has been compacted and is no longer individually user-undoable.
- `deferredBakePaintCommands`: older paint commands that have left user-facing undo but are intentionally not baked immediately.
- `livePaintCommands`: recent paint/stroke-like commands that remain user-undoable.
- `hiddenByUndoPaintCommands`: undone recent commands hidden from display and available for redo while still retained by the active edit history.
- `activeStrokeOverlay`: temporary in-progress drawing overlay for active input before commit.
- `inactivePreviewCache`: derived preview/composite image for inactive frame display.
- `playbackPreviewCache`: derived preview/composite bitmap cache image for playback.
- `dirty flags`: metadata marking which previews, composites, or cached images need refresh.
- `userUndoLimit`: user-configurable number of undoable brush commands.
- `deferredBakeRatio`: default conceptual ratio used to size the deferred bake buffer, approximately 10%.
- `deferredBakeLimit`: maximum number of non-user-undoable deferred bake commands retained before baking pressure applies.
- `UnifiedUndoHistory`: the one global user-facing undo/redo order across brush, project, timeline, and layer changes.
- `BrushFrameStore`: frame-keyed owner of brush frame drawing payloads and frame-local paint command state.

## Brush frame drawing state

A brush frame drawing payload conceptually contains:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
+ hiddenByUndoPaintCommands, if needed for redo
+ inactivePreviewCache / playbackPreviewCache
+ dirty flags
```

`BrushFrameStore` owns this frame-local drawing payload, keyed by `BrushFrameKey`. A `Frame` remains lightweight metadata and should not embed heavy bitmap surfaces, command lists, or cache images directly.

## Active editing display

The active frame display formula is:

```txt
activeFrameDisplay =
  bakedBaseSurface
  + deferredBakePaintCommands
  + livePaintCommands
  + activeStrokeOverlay
```

The active stroke overlay is an editing-only layer for current input. It is not a playback mechanism and is not a durable source of truth.

## User-facing undo / redo

User-facing undo is based on recent live paint commands through `UnifiedUndoHistory`.

Undo should affect `livePaintCommands` / `hiddenByUndoPaintCommands` while the command is still within the `userUndoLimit`.

Deferred bake buffer commands are not user-undoable.

Baked commands are not user-undoable as individual commands.

`UnifiedUndoHistory` owns global user-facing undo order. `BrushFrameStore` owns frame-local payload movement for brush commands but does not decide the global undo order.

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

The deferred bake buffer is not buffer undo.
The deferred bake buffer is not user-facing undo.
It exists only to delay baking and keep active drawing responsive.

## Baking policy

Older commands beyond the custom user undo limit may move from `livePaintCommands` into `deferredBakePaintCommands`.

Old deferred commands may eventually be baked into `bakedBaseSurface`. Once baked, those commands are represented by bitmap/tile data and are not individually user-undoable.

Baking is an internal compaction policy for old artwork. It must not be confused with user-facing undo.

## Cache image generation

`inactivePreviewCache` / `playbackPreviewCache` are derived images.

They are produced from brush frame drawing state, such as:

```txt
bakedBaseSurface
+ deferredBakePaintCommands
+ livePaintCommands
```

They are used for inactive frame display and playback.

They are not the source of truth.

Cache images may be regenerated when dirty flags indicate that the underlying brush frame state changed.

## Playback policy

Playback uses preview/composite bitmap cache images.

Playback must not replay live paint commands.
Playback must not replay old strokes.
Playback must not run brush rasterization.
Playback must not composite all layers from scratch every frame if a valid preview/composite cache exists.

If a playback cache is stale or missing, it should be prepared outside the live playback path or treated as dirty according to the renderer/cache policy of a future phase.

## Frame / BrushFrameStore ownership

`Frame` owns identity, timing, and lightweight metadata.

`BrushFrameStore` owns frame drawing payloads, including `bakedBaseSurface`, `deferredBakePaintCommands`, `livePaintCommands`, `hiddenByUndoPaintCommands`, preview caches, playback caches, and dirty flags.

`UnifiedUndoHistory` references brush payloads as part of a global undo sequence but does not make cache images or bitmap previews into source-of-truth drawing data.

## What is current vs legacy

Current policy:

- Deferred Bake Hybrid Brush History.
- User-facing undo is recent live paint command / stroke-like command based.
- The deferred bake buffer is separate from user-facing undo.
- Cache images are derived from brush frame state.
- Playback uses preview/composite bitmap cache images and avoids live command replay/rasterization.

Legacy or lower-level implementation details:

- Existing Brush V1 tile delta classes may remain as implementation details of bitmap edit services and tests.
- Tile delta may be considered a possible future low-level optimization for bitmap mutation or storage.
- Tile delta is not the current user-facing undo policy.

## Explicitly not the current policy

The current policy is not:

- `Undo source = tile delta data` as the current user-facing architecture.
- User-facing undo as `TileDeltaCommand`.
- Tile delta as the primary brush undo model.
- Brush display based on replaying every old stroke.
- Playback replaying strokes.
- Playback running brush rasterization.

## Future implementation phases

Future phases may implement actual deferred baking, preview cache generation, playback cache preparation, renderer cache behavior, save/load integration, or memory-estimation UI.

Those phases must preserve this policy unless a newer canonical architecture document explicitly supersedes it.

## Brush V1 implementation snapshot retained as context

Brush V1 completed an internal smoke/dev/test stack with BitmapSurface / BitmapTile storage, BrushDabSequence input, brush pixel blending, commit/undo/redo services, cache invalidation facades, BitmapSurfacePainter display, InteractiveBrushEditCanvasView, and smoke-screen regression coverage. That stack is context only: it is not app-complete and must not be restored into production routes merely to satisfy legacy documentation tests.

Tile delta is not the current user-facing undo policy. Tile delta may appear only as a legacy implementation detail, possible low-level optimization, or internal bitmap mutation/storage detail.

## Historical naming decisions retained for current integration context

### Phase 206 BrushWorkspaceCoordinator naming cleanup preparation

BrushWorkspaceCoordinator is no longer tied to the deleted BrushWorkspaceScreen route. BrushWorkspaceCoordinator is currently a production brush editing coordination service. The planned naming direction was BrushWorkspaceCoordinator -> BrushFrameEditingCoordinator. BrushWorkspaceCacheInvalidationSink should be considered separately. Left runtime behavior unchanged. Did not rename BrushWorkspaceCoordinator yet. Did not rename BrushWorkspaceCacheInvalidationSink. Did not reintroduce deleted workspace UI or debug controls.

### Phase 207 BrushFrameEditingCoordinator runtime rename

Renamed BrushWorkspaceCoordinator to BrushFrameEditingCoordinator. Renamed brush_workspace_coordinator.dart to brush_frame_editing_coordinator.dart. Kept runtime behavior unchanged. BrushWorkspaceCacheInvalidationSink was not renamed in this phase.

### Phase 208 BrushWorkspaceCacheInvalidationSink naming decision

BrushWorkspaceCacheInvalidationSink is no longer tied to deleted BrushWorkspaceScreen / BrushWorkspaceView UI. BrushWorkspaceCacheInvalidationSink currently acts as the cache invalidation sink boundary used by brush editing flows. BrushWorkspaceCacheInvalidationSink -> BrushEditCacheInvalidationSink. Why BrushEditCacheInvalidationSink: it names the brush-edit cache invalidation boundary without implying a deleted workspace UI. Left runtime behavior unchanged. Did not rename BrushWorkspaceCacheInvalidationSink yet. Did not rename brush_workspace_cache_invalidation_sink.dart yet.

### Phase 209 BrushEditCacheInvalidationSink runtime rename

Renamed BrushWorkspaceCacheInvalidationSink to BrushEditCacheInvalidationSink. Renamed brush_workspace_cache_invalidation_sink.dart to brush_edit_cache_invalidation_sink.dart. Updated production imports to use BrushEditCacheInvalidationSink. Updated tests to use BrushEditCacheInvalidationSink. Kept cache invalidation semantics unchanged.
