# Bitmap Canvas and Brush Architecture

## Purpose

This document defines the long-term bitmap canvas and brush direction for QuickAnimaker v2.

QuickAnimaker v2 is intended to be a TVPaint-style bitmap animation tool.

The final drawing data should be bitmap data.

Vector-like stroke data may exist internally for temporary input, command metadata, or debugging, but it should not become the main display-time artwork source of truth.

## Core principle

```txt
User-visible drawing result = bitmap
Stored artwork source of truth = bitmap tile data
Brush input path = temporary calculation data
Undo source = tile delta data
Playback source = baked preview cache
```

The project should avoid becoming a vector animation tool.

## Recommended data layers

### 1. Bitmap layer data

Represents the actual painted pixels for one layer/exposure/frame.

Potential future types:

```txt
LayerBitmapSurface
BitmapSurface
BitmapTile
TileCoord
TileBounds
```

This is the primary artwork data.

### 2. Brush input data

Represents input before it becomes pixels.

Already introduced:

```txt
BrushInputSample
StrokePoint
BrushSettings
BrushPreset
```

Important rule:

```txt
BrushInputSample is pre-stroke input data.
StrokePoint is coordinate data used by Stroke.
BrushSettings is a frozen settings snapshot.
BrushPreset is reusable preset metadata.
```

`Stroke` must not reference `BrushPreset`.

### 3. Rasterization data

Represents temporary brush computation.

Potential future types:

```txt
BrushStrokeBuilder
DabPlacement
BrushTipMask
BrushRasterizer
```

This data should be used to modify bitmap tiles.

It should not become the final artwork source.

### 4. Undo data

Represents changes caused by drawing.

Preferred future types:

```txt
TileDeltaCommand
DirtyTileSet
BeforeTileSnapshot
AfterTileSnapshot
CompressedTileDelta
```

Undo should restore pixel data, not require replaying all old strokes.

### 5. Display cache data

Represents lightweight images for display and playback.

Potential future types:

```txt
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
DiskPreviewCache
```

Playback should use cache image swapping where possible.

## Why not keep undoable strokes as display source?

The v1 approach kept undoable strokes as stroke/vector-like data and baked old strokes into bitmap after the undo limit.

This is a valid idea and should be remembered.

However, for v2 the preferred long-term structure is lighter for playback:

```txt
Draw stroke
-> rasterize immediately into dirty bitmap tiles
-> store tile delta for undo
-> update preview cache
```

Instead of:

```txt
Draw stroke
-> keep stroke list as live display source
-> replay/composite live strokes until they are baked
```

The main reason is playback performance.

Playback should not need to replay strokes.

Playback should not need to run brush rasterization.

Playback should not need to composite all layers from scratch every frame.

## Current recommended drawing flow

```txt
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> StrokeBuilder
-> DabPlacement
-> BitmapBrushRasterizer
-> DirtyTileSet
-> BitmapTile updates
-> TileDeltaCommand
-> FrameCompositeCache invalidation
-> PlaybackPreviewCache invalidation
```

Only the affected tiles should be updated.

The whole canvas should not be redrawn for every stroke.

## Current recommended display flow

For editing the active frame:

```txt
Visible viewport area
-> intersect visible area with tile bounds
-> draw/upload visible tiles only
-> include active stroke overlay if needed
```

For inactive frames:

```txt
Use FrameCompositeCache or PlaybackPreviewCache
```

For playback:

```txt
Use PlaybackPreviewCache
Preload nearby frames
Swap cached preview images
Avoid live brush rasterization
Avoid full layer recomposition
```

## Current recommended undo flow

For a drawing operation:

```txt
1. Determine affected tiles.
2. Store before snapshots for affected tiles.
3. Rasterize stroke into those tiles.
4. Store after snapshots or compressed delta.
5. Push TileDeltaCommand into undo history.
```

Undo:

```txt
Restore before tile data.
Invalidate related frame/layer/composite cache.
```

Redo:

```txt
Restore after tile data.
Invalidate related frame/layer/composite cache.
```

This makes undo independent from brush complexity.

## Tile-based canvas policy

The canvas should be tile-based.

Recommended initial tile size candidates:

```txt
256x256: good default, lower management overhead
128x128: possible if brush responsiveness needs smaller dirty regions
```

Start with 256x256 unless performance tests show a strong reason to use 128x128.

Tile rules:

```txt
- Do not allocate all tiles eagerly.
- Keep sparse tile maps.
- Allocate tiles only when they receive pixel data.
- Track dirty tiles explicitly.
- Upload/redraw only visible dirty tiles.
- Do not recreate the whole frame image during every stroke.
```

## Cache policy

The project should eventually have multiple cache levels.

```txt
LayerTileCache
= cache for individual layer tile images

FrameCompositeCache
= composited frame image or composited frame tile set

PlaybackPreviewCache
= display-size or reduced-size image used for playback

DiskPreviewCache
= optional cache for far-away frames or large projects
```

Playback priority:

```txt
1. Use ready PlaybackPreviewCache.
2. If missing, use nearby preloaded FrameCompositeCache.
3. Avoid blocking playback on full recomposition.
4. Avoid brush rasterization during playback.
```

## Active frame policy

The active frame may temporarily be heavier than inactive frames.

Allowed:

```txt
active stroke overlay
dirty tile redraw
interactive brush preview
high-resolution visible tiles
```

Inactive frames should be lighter.

Preferred:

```txt
baked frame preview
cached composited image
low-memory tile cache
```

## Stroke policy

`Stroke` can remain useful as a command/history concept.

But long-term:

```txt
Stroke should not be the display-time source of truth.
Stroke should not be required to render playback.
Stroke should not be required to display inactive frames.
```

Allowed uses:

```txt
debugging
command history metadata
future optional editable recent-stroke metadata
brush replay tests
```

But playback and general display should use bitmap/cache data.

## Photoshop-style brush import policy

Photoshop-style brush import is a long-term compatibility goal, not a near-term implementation phase.

Preferred long-term approach:

```txt
User imports a user-owned brush file.
Importer extracts supported brush tip/settings data.
QuickAnimaker converts it into its own BrushPreset / BrushSettings / BrushTip data.
Unsupported settings are ignored or approximated with clear reporting.
```

Avoid:

```txt
claiming full Photoshop brush engine compatibility
bundling Adobe/Photoshop default brushes
using Adobe logos or branding
marketing the app as an Adobe-compatible clone
depending on Photoshop internals as the core brush architecture
```

Internal brush architecture must work first.

Brush import should adapt external data into QuickAnimaker's own model, not make the app depend on an external product's brush engine.

## Forbidden shortcuts

Do not optimize playback by hiding structural problems.

Avoid:

```txt
full canvas redraw per frame
full layer recomposition per playback frame
stroke replay during playback
eager allocation of all frame/layer tiles
single giant bitmap for all editing operations
cache invalidation that clears everything after every small edit
making Timeline range semantics drive canvas storage
making StoryboardPanel own drawing data
```

## Near-term implementation direction

The next implementation phases should be:

```txt
1. Bitmap tile coordinate/value models
2. Sparse BitmapSurface model
3. DirtyTileSet model
4. TileDeltaCommand model
5. FrameCompositeCache policy documentation/tests
6. PlaybackPreviewCache policy documentation/tests
7. Minimal bitmap brush rasterizer
8. Canvas UI integration
```

Do not implement advanced brush import before the bitmap brush engine exists.
