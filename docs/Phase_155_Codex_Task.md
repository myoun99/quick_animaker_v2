# Phase 155 Codex Task

## Title

Cache invalidation key / plan model foundation

## Repository

```txt id="eb09zf"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="rzadhj"
master
```

## Project type

```txt id="c7zu6r"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 154.

Recent bitmap canvas foundation phases:

```txt id="pnk880"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
```

Current long-term direction:

```txt id="491icw"
QuickAnimaker v2 is bitmap-first.
Final artwork source of truth should be bitmap tile data.
DirtyRegion describes changed pixel bounds.
DirtyTileSet describes affected tile coordinates.
TileDeltaCommand describes before/after tile changes for one operation.
Playback should eventually use baked preview cache images.
```

Phase 155 adds pure model foundations for cache invalidation.

This phase must not add actual cache storage, image cache, renderer, playback system, brush rasterizer, undo stack, save/load, or canvas UI.

## What structure this phase should create

Future drawing will eventually flow like this:

```txt id="6ynmmf"
Pointer / tablet input
-> ViewportPoint
-> CanvasViewport.viewportToCanvas(...)
-> CanvasPoint
-> BrushInputSample
-> BrushStrokeBuilder
-> DabPlacement
-> DirtyRegion
-> DirtyTileSet
-> BitmapTile updates
-> TileDeltaCommand
-> CacheInvalidationPlan
-> future LayerTileCache invalidation
-> future FrameCompositeCache invalidation
-> future PlaybackPreviewCache invalidation
```

This phase only creates the model layer for:

```txt id="jvvmk7"
LayerTileCacheKey
FrameCompositeCacheKey
PlaybackPreviewCacheKey
CacheInvalidationPlan
```

Meaning:

```txt id="p8a3x1"
LayerTileCacheKey
= identifies one cached bitmap tile for a specific layer/frame/tile coordinate

FrameCompositeCacheKey
= identifies one composited frame cache entry for a cut and timeline frame index

PlaybackPreviewCacheKey
= identifies one playback preview cache entry for a cut, timeline frame index, and preview size

CacheInvalidationPlan
= an immutable set of cache keys that should be invalidated by a future operation
```

This is model-only.

## Required references

Before editing, read:

```txt id="w2wtxp"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
docs/Phase_154_Codex_Task.md
```

Also inspect:

```txt id="x4usri"
lib/src/models/tile_coord.dart
lib/src/models/bitmap_tile.dart
lib/src/models/bitmap_surface.dart
lib/src/models/dirty_tile_set.dart
lib/src/models/tile_delta.dart
lib/src/models/tile_delta_command.dart
lib/src/models/canvas_size.dart
lib/src/models/cut_id.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
test/models/tile_delta_command_test.dart
test/models/dirty_tile_set_test.dart
```

If the ID model filenames differ, follow the existing project convention.

Do not modify timeline or storyboard behavior.

## Goal

Add pure Dart cache invalidation model foundations:

```txt id="aw2t9h"
LayerTileCacheKey
FrameCompositeCacheKey
PlaybackPreviewCacheKey
CacheInvalidationPlan
```

The goal is to prepare the project for future LayerTileCache, FrameCompositeCache, and PlaybackPreviewCache without implementing those caches yet.

## Strong scope rule

Allowed:

```txt id="g27cbg"
pure Dart model classes
cache key value objects
immutable invalidation plan data
copyWith / equality / hashCode / toJson / fromJson
focused model tests
pure factory deriving layer tile invalidation from TileDeltaCommand
```

Not allowed:

```txt id="a6bpid"
actual cache storage
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
image cache
renderer
cache eviction
cache memory budget
cache preloader
playback implementation
brush rasterizer
dab placement
actual drawing behavior
canvas UI
pointer event handling
gesture handling
CustomPainter
UndoService
undo stack
save/load
persistence
Provider/Riverpod/Bloc/ChangeNotifier
timeline/storyboard changes
```

## Required production files

### 1. LayerTileCacheKey

Create:

```txt id="y6spsf"
lib/src/models/layer_tile_cache_key.dart
```

Required fields:

```dart id="q0uyek"
final LayerId layerId;
final FrameId frameId;
final TileCoord tileCoord;
```

Meaning:

```txt id="czpzbc"
layerId: the layer that owns the bitmap tile
frameId: the frame/exposure whose bitmap tile is cached
tileCoord: the tile coordinate inside the bitmap surface
```

Required behavior:

```txt id="xwh253"
- immutable model
- required fields
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Do not include image data.

Do not include dirty state.

Do not include cache storage.

### 2. FrameCompositeCacheKey

Create:

```txt id="v9jvh1"
lib/src/models/frame_composite_cache_key.dart
```

Required fields:

```dart id="s1dggh"
final CutId cutId;
final int frameIndex;
```

Meaning:

```txt id="v4jsrp"
cutId: cut whose layers are composited
frameIndex: timeline frame index inside the cut
```

Required validation:

```txt id="gq1y46"
frameIndex >= 0
invalid values throw ArgumentError
```

Required behavior:

```txt id="swi1nm"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Important:

`FrameCompositeCacheKey` should use timeline frame index, not `FrameId`.

Reason:

```txt id="bszybg"
A composited frame represents what is visible at a timeline frame index across layers.
It is not the same thing as one layer's FrameId.
```

### 3. PlaybackPreviewCacheKey

Create:

```txt id="sbc1ry"
lib/src/models/playback_preview_cache_key.dart
```

Required fields:

```dart id="ipsaav"
final CutId cutId;
final int frameIndex;
final CanvasSize previewSize;
```

Meaning:

```txt id="6w0pt5"
cutId: cut being played
frameIndex: timeline frame index inside the cut
previewSize: output preview size used for playback
```

Required validation:

```txt id="0emyx2"
frameIndex >= 0
previewSize uses existing CanvasSize validation
invalid values throw ArgumentError
```

Required behavior:

```txt id="e4dx8b"
- immutable model
- copyWith
- toJson/fromJson
- equality/hashCode
- toString
```

Important:

`PlaybackPreviewCacheKey` is separate from `FrameCompositeCacheKey`.

Reason:

```txt id="vgc0kt"
A full frame composite and a playback preview may have different sizes.
Playback may use display-size or reduced-size cache images.
```

Do not include actual image data.

Do not include cache storage.

### 4. CacheInvalidationPlan

Create:

```txt id="m5b6sd"
lib/src/models/cache_invalidation_plan.dart
```

Required internal data:

```dart id="vbyqyw"
Set<LayerTileCacheKey>
Set<FrameCompositeCacheKey>
Set<PlaybackPreviewCacheKey>
```

Recommended constructor:

```dart id="lbhjuh"
CacheInvalidationPlan({
  Iterable<LayerTileCacheKey> layerTiles = const [],
  Iterable<FrameCompositeCacheKey> frameComposites = const [],
  Iterable<PlaybackPreviewCacheKey> playbackPreviews = const [],
})
```

Required behavior:

```txt id="q4nvnl"
- immutable public API
- defensive copy input iterables
- expose unmodifiable sets or deterministic unmodifiable lists
- equality ignores insertion order
- hashCode ignores insertion order
- toJson/fromJson
- toString
```

Required getters:

```dart id="c5s03s"
Set<LayerTileCacheKey> get layerTiles
Set<FrameCompositeCacheKey> get frameComposites
Set<PlaybackPreviewCacheKey> get playbackPreviews

bool get isEmpty
bool get isNotEmpty
int get totalKeyCount
```

Required factories:

```dart id="besyap"
CacheInvalidationPlan.empty()

CacheInvalidationPlan.fromTileDeltaCommand({
  required LayerId layerId,
  required FrameId frameId,
  required TileDeltaCommand command,
})
```

`fromTileDeltaCommand` meaning:

```txt id="i2hbw0"
Create LayerTileCacheKey entries for every tile affected by command.dirtyTiles.
Do not derive FrameCompositeCacheKey automatically.
Do not derive PlaybackPreviewCacheKey automatically.
The caller/future timeline mapping layer will add those keys later.
```

Required helpers:

```dart id="pp93ex"
CacheInvalidationPlan addLayerTile(LayerTileCacheKey key)
CacheInvalidationPlan addFrameComposite(FrameCompositeCacheKey key)
CacheInvalidationPlan addPlaybackPreview(PlaybackPreviewCacheKey key)

CacheInvalidationPlan addLayerTiles(Iterable<LayerTileCacheKey> keys)
CacheInvalidationPlan addFrameComposites(Iterable<FrameCompositeCacheKey> keys)
CacheInvalidationPlan addPlaybackPreviews(Iterable<PlaybackPreviewCacheKey> keys)

CacheInvalidationPlan merge(CacheInvalidationPlan other)
```

Rules:

```txt id="p6p6sz"
All helpers return a new CacheInvalidationPlan.
Original plan must not mutate.
Duplicate keys should collapse naturally through sets.
```

Equality/hashCode:

```txt id="l1dixc"
- equality ignores insertion order
- hashCode ignores insertion order
- use Object.hashAllUnordered for each key set or equivalent
```

Recommended hashCode:

```dart id="piqknd"
@override
int get hashCode => Object.hash(
  Object.hashAllUnordered(_layerTiles),
  Object.hashAllUnordered(_frameComposites),
  Object.hashAllUnordered(_playbackPreviews),
);
```

JSON shape:

```json id="q7m4q1"
{
  "layerTiles": [
    { "...": "LayerTileCacheKey json" }
  ],
  "frameComposites": [
    { "...": "FrameCompositeCacheKey json" }
  ],
  "playbackPreviews": [
    { "...": "PlaybackPreviewCacheKey json" }
  ]
}
```

`toJson` should emit deterministic order for stable tests.

Recommended deterministic order:

```txt id="3a9f1s"
LayerTileCacheKey:
- layerId value
- frameId value
- tileCoord.y
- tileCoord.x

FrameCompositeCacheKey:
- cutId value
- frameIndex

PlaybackPreviewCacheKey:
- cutId value
- frameIndex
- previewSize.width
- previewSize.height
```

If ID value fields differ, inspect existing ID models and use their string/value property or `toString` only if no better option exists.

## Required tests

### 1. LayerTileCacheKey tests

Create:

```txt id="b89xgy"
test/models/layer_tile_cache_key_test.dart
```

Required tests:

```txt id="mzlfoy"
creates with layerId, frameId, tileCoord
copyWith updates layerId
copyWith updates frameId
copyWith updates tileCoord
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
toString includes useful identifying data
```

### 2. FrameCompositeCacheKey tests

Create:

```txt id="a0ngev"
test/models/frame_composite_cache_key_test.dart
```

Required tests:

```txt id="gmlygu"
creates with cutId and frameIndex
rejects negative frameIndex
copyWith updates cutId
copyWith updates frameIndex
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
toString includes useful identifying data
```

### 3. PlaybackPreviewCacheKey tests

Create:

```txt id="aypuyh"
test/models/playback_preview_cache_key_test.dart
```

Required tests:

```txt id="cbow1i"
creates with cutId, frameIndex, previewSize
rejects negative frameIndex
copyWith updates cutId
copyWith updates frameIndex
copyWith updates previewSize
equality includes all fields
hashCode is value-based
toJson/fromJson round-trips
different previewSize creates different key
toString includes useful identifying data
```

### 4. CacheInvalidationPlan tests

Create:

```txt id="d2y8h9"
test/models/cache_invalidation_plan_test.dart
```

Required tests:

```txt id="a5hufc"
empty plan is empty
constructor stores layer tile keys
constructor stores frame composite keys
constructor stores playback preview keys
constructor defensively copies input iterables
exposed key sets are unmodifiable
isEmpty is true only when all key sets are empty
isNotEmpty is true when any key set is non-empty
totalKeyCount sums all key sets
addLayerTile returns new plan
addFrameComposite returns new plan
addPlaybackPreview returns new plan
add helpers do not mutate original
addLayerTiles collapses duplicates
addFrameComposites collapses duplicates
addPlaybackPreviews collapses duplicates
merge combines all key sets
merge does not mutate originals
fromTileDeltaCommand creates LayerTileCacheKey entries for every dirty tile
fromTileDeltaCommand does not create FrameCompositeCacheKey entries
fromTileDeltaCommand does not create PlaybackPreviewCacheKey entries
equality ignores insertion order
hashCode ignores insertion order
toJson/fromJson round-trips
toJson emits deterministic order
```

Important test for order independence:

```txt id="un20p9"
CacheInvalidationPlan(layerTiles: [a, b]) == CacheInvalidationPlan(layerTiles: [b, a])
and both have the same hashCode
```

Important test for `fromTileDeltaCommand`:

```txt id="e0fgtu"
TileDeltaCommand with deltas at TileCoord(0,0) and TileCoord(1,0)
-> CacheInvalidationPlan.fromTileDeltaCommand(layerId, frameId, command)
-> layerTiles contains:
   LayerTileCacheKey(layerId, frameId, TileCoord(0,0))
   LayerTileCacheKey(layerId, frameId, TileCoord(1,0))
-> frameComposites is empty
-> playbackPreviews is empty
```

## Architecture rules

Cache invalidation rules:

```txt id="mujah7"
CacheInvalidationPlan is not a cache.
CacheInvalidationPlan stores keys to invalidate later.
CacheInvalidationPlan does not store images.
CacheInvalidationPlan does not evict anything.
CacheInvalidationPlan does not preload anything.
CacheInvalidationPlan does not know about renderer implementation.
CacheInvalidationPlan does not mutate BitmapSurface.
```

Bitmap storage boundary:

```txt id="wto4za"
BitmapSurface remains sparse bitmap storage.
BitmapTile remains RGBA8888 pixel storage.
DirtyRegion remains pixel rectangle math.
DirtyTileSet remains tile-coordinate set math.
TileDeltaCommand remains before/after tile delta data.
CacheInvalidationPlan may derive LayerTileCacheKey values from TileDeltaCommand.dirtyTiles.
CacheInvalidationPlan must not change BitmapSurface or TileDeltaCommand semantics.
```

Timeline/storyboard boundary:

```txt id="6lxdj5"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="wt9vxi"
actual cache implementation
LayerTileCache
FrameCompositeCache
PlaybackPreviewCache
cache storage maps
cache eviction
cache memory budget
cache preloader
image data
ui.Image
dart:ui
renderer
playback implementation
UndoService
UndoStack
RedoStack
HistoryService
actual canvas UI
drawing canvas
pointer event handling
tablet input
gesture detector
zoom/pan UI integration
brush rasterizer
brush engine execution
dab placement
stroke rendering
pixel blending
BitmapTile drawing mutation helpers
dirty region calculation from brush input
save/load
persistence service
tile upload
CustomPainter changes
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
export
Photoshop-style / ABR brush import
```

## Expected changed files

Likely:

```txt id="jma07o"
lib/src/models/layer_tile_cache_key.dart
lib/src/models/frame_composite_cache_key.dart
lib/src/models/playback_preview_cache_key.dart
lib/src/models/cache_invalidation_plan.dart
test/models/layer_tile_cache_key_test.dart
test/models/frame_composite_cache_key_test.dart
test/models/playback_preview_cache_key_test.dart
test/models/cache_invalidation_plan_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="td5nz3"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="obv33u"
- changed files
- new model files added
- LayerTileCacheKey fields
- FrameCompositeCacheKey fields and frameIndex validation
- PlaybackPreviewCacheKey fields and frameIndex validation
- CacheInvalidationPlan storage and immutability policy
- CacheInvalidationPlan deterministic JSON ordering policy
- confirmation that CacheInvalidationPlan equality/hashCode ignore insertion order
- confirmation that fromTileDeltaCommand only creates LayerTileCacheKey entries
- confirmation that no actual cache implementation was added
- confirmation that no image/renderer/playback implementation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no brush rasterizer was added
- confirmation that no canvas UI was added
- confirmation that no cache/save-load implementation was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 155 is complete when:

```txt id="w8tmpj"
- LayerTileCacheKey exists and is tested.
- FrameCompositeCacheKey exists and is tested.
- PlaybackPreviewCacheKey exists and is tested.
- CacheInvalidationPlan exists and is tested.
- FrameCompositeCacheKey rejects negative frameIndex.
- PlaybackPreviewCacheKey rejects negative frameIndex.
- CacheInvalidationPlan is immutable from the public API.
- CacheInvalidationPlan equality ignores insertion order.
- CacheInvalidationPlan hashCode ignores insertion order.
- CacheInvalidationPlan JSON output is deterministic.
- fromTileDeltaCommand derives only layer tile keys.
- Existing Phase 152 BitmapSurface / BitmapTile / TileCoord tests still pass.
- Existing Phase 153 DirtyRegion / DirtyTileSet tests still pass.
- Existing Phase 154 TileDelta / TileDeltaCommand tests still pass.
- Existing canvas viewport and brush input tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No actual cache implementation was added.
- No renderer/playback implementation was added.
- No UndoService / undo stack was added.
- No brush rasterization was added.
- No drawing canvas UI was added.
- No save-load behavior was added.
```

## Manual check list

This phase is model-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="g5jwtl"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
