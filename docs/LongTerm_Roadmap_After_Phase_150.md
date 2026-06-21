# Long-Term Roadmap After Phase 150

## Purpose

This document records the long-term direction after Phase 150.

Phase 146 through Phase 150 completed the recommended post-timeline-stabilization sequence:

```txt
Phase 146: StoryboardPanel stabilization / feature foundation
Phase 147: StoryboardPanel interaction tests
Phase 148: 2D brush model / brush settings architecture
Phase 149: Brush input sampling tests
Phase 150: Canvas viewport foundation
```

The project should now stop treating Phase 146-150 as the next recommended phase sequence.

The next direction should be a bitmap-first canvas architecture, optimized for playback performance, editing performance, and long-term scalability.

## Current high-level state

The project now has stable foundations for:

```txt
Timeline stabilization
StoryboardPanel overview semantics
Brush settings / brush preset model
Brush input sample model
Canvas viewport coordinate conversion
```

The project still does not have:

```txt
bitmap tile storage
dirty tile tracking
tile delta undo
brush rasterization
canvas drawing integration
playback preview cache
save/load for bitmap tile data
renderer/cache/persistence architecture
```

## Core long-term direction

QuickAnimaker v2 is a bitmap animation tool.

The source of truth for drawn artwork should be bitmap data, not vector stroke data.

Internal stroke or path-like data may exist as temporary input or command metadata, but the displayed and stored artwork should be bitmap-first.

Primary rule:

```txt
Final artwork source of truth = bitmap tile data
```

Not:

```txt
Final artwork source of truth = editable vector stroke list
```

## Recommended next large milestones

### Milestone 1: Bitmap surface foundation

Goal:

```txt
Define how one frame/layer stores bitmap pixels.
```

Target concepts:

```txt
BitmapSurface
BitmapTile
TileCoord
DirtyTileSet
TileBounds
```

This should still be mostly pure model/service work.

Do not jump directly to UI drawing.

### Milestone 2: Dirty tile and tile delta architecture

Goal:

```txt
Track only the bitmap areas changed by a drawing operation.
```

Target concepts:

```txt
DirtyTileSet
TileSnapshot
TileDelta
TileDeltaCommand
```

This prepares the project for lightweight undo/redo.

Undo should eventually restore tile snapshots or compressed tile deltas instead of replaying stroke vectors.

### Milestone 3: Frame and layer bitmap cache policy

Goal:

```txt
Avoid recomputing full frames during playback and scrubbing.
```

Target concepts:

```txt
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
CacheInvalidationPolicy
```

Playback should prefer prebuilt preview images.

Playback must not rasterize brush strokes or recomposite full layers on every frame.

### Milestone 4: Brush rasterizer prototype

Goal:

```txt
Convert brush input samples into bitmap tile changes.
```

Target concepts:

```txt
BrushStrokeBuilder
DabPlacement
BitmapBrushRasterizer
BrushTipMask
BrushBlendMode
```

This should start with a minimal bitmap brush.

Do not implement Photoshop-style brush import yet.

### Milestone 5: Canvas UI integration

Goal:

```txt
Connect viewport coordinate conversion, pointer input, and bitmap drawing.
```

Target concepts:

```txt
CanvasViewportController
PointerToBrushInputAdapter
ActiveStrokeOverlay
TileUploadInvalidation
```

This should happen only after bitmap surface and rasterizer logic are stable.

### Milestone 6: Tile-delta undo / redo

Goal:

```txt
Undo and redo drawing operations by restoring dirty tile data.
```

Target concepts:

```txt
TileDeltaCommand
BeforeTileSnapshot
AfterTileSnapshot
UndoMemoryBudget
UndoCompactionPolicy
```

Undo should be fast even for complex brushes.

### Milestone 7: Save / load and project file structure

Goal:

```txt
Persist bitmap tile data, metadata, and optional preview cache.
```

Target concepts:

```txt
ProjectFileManifest
TileChunkStore
FrameLayerBitmapStore
CompressedTileData
PreviewCacheManifest
```

Save/load should not assume every frame is loaded into memory.

### Milestone 8: Playback optimization

Goal:

```txt
Make playback use cache image swapping rather than live reconstruction.
```

Target concepts:

```txt
PlaybackCacheWindow
PreviewCachePreloader
FrameDecodeQueue
CacheMemoryBudget
DiskPreviewCache
```

Playback performance is a primary product goal.

### Milestone 9: StoryboardPanel long-term expansion

Goal:

```txt
Expand StoryboardPanel as a project/cut overview, not as a drawing canvas.
```

Allowed future directions:

```txt
Storyboard thumbnails
Storyboard metadata display
Project-level cut overview
Track-based board view
Primary-track storyboard export
Optional selected-track export
```

Still forbidden:

```txt
StoryboardPanel owning timeline range semantics
StoryboardPanel becoming the drawing canvas
StoryboardPanel mutating Project during layout derivation
```

### Milestone 10: Photoshop-style / ABR brush compatibility investigation

Goal:

```txt
Investigate importing user-owned brush assets into QuickAnimaker's own brush model.
```

This should happen after the internal bitmap brush engine is stable.

The project should not claim full Photoshop brush engine compatibility early.

Preferred language:

```txt
Best-effort import of user-owned brush files
```

Avoid:

```txt
Photoshop brush engine clone
Full Photoshop compatibility
Bundling Adobe brushes
Using Adobe branding as product identity
```

## Development priority order

The recommended next direction is:

```txt
1. Long-term architecture documentation
2. BitmapSurface / Tile model
3. DirtyTileSet / TileDelta model
4. FrameCompositeCache / PlaybackPreviewCache policy
5. Minimal bitmap brush rasterizer
6. Canvas UI integration
7. Tile-delta undo/redo
8. Save/load for bitmap tile data
9. Playback optimization
10. Brush import compatibility research
```

Do not start with ABR import.

Do not start with advanced brush UI.

Do not start with playback UI.

The project needs the bitmap storage and cache architecture first.

## Key architectural rules

```txt
- QuickAnimaker v2 is bitmap-first.
- Stroke data may exist as input/history metadata.
- Stroke data should not be the display-time source of truth.
- Final artwork should live in bitmap tile data.
- Undo should prefer tile deltas over stroke replay.
- Playback should use baked preview cache images.
- Non-active frames should be displayed from cache where possible.
- Drawing should update only dirty tiles.
- Full-frame recomposition should be avoided during playback.
- Timeline range semantics must remain separate from canvas/cache semantics.
- StoryboardPanel must remain a project/cut overview, not a drawing canvas.
```

## What not to do next

Do not immediately implement:

```txt
Photoshop brush import
Advanced brush engine
Gesture-based zoom/pan UI
Full renderer rewrite
Undo/redo UI
Save/load rewrite
Storyboard thumbnail renderer
Playback/export system
```

The next implementation phase should start with bitmap canvas storage foundations.
