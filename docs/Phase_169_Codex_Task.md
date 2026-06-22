# Phase 169 Codex Task

## Title

Create BrushCommitResult model

## Repository

```txt id="xloalm"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="h55av0"
master
```

## Project type

```txt id="ms6tnt"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 168.

Recent bitmap canvas / brush foundation phases:

```txt id="4g8u1m"
Phase 152: BitmapSurface / BitmapTile / TileCoord model foundation
Phase 153: DirtyRegion / DirtyTileSet model foundation
Phase 154: TileDelta / TileDeltaCommand model foundation
Phase 155: Cache invalidation key / plan model foundation
Phase 156: BrushDab / BrushDabSequence / BrushDabPlacement foundation
Phase 157: BrushDab dirty region / dirty tile derivation foundation
Phase 158: BrushDab.color snapshot / RgbaColor foundation
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab pixel coverage foundation
Phase 161: BrushDab pixel blend foundation
Phase 162: BrushDabSequence pixel blend operation foundation
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: Apply BrushPixelBlendOperation list to BitmapTile
Phase 165: BitmapTile operation list -> TileDeltaCommand?
Phase 166: BrushDabSequence + one BitmapTile -> TileDeltaCommand?
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
```

## Existing brush commit pieces

The current brush commit pipeline has these independent pieces:

```txt id="typt0w"
BrushDabSequence + BitmapSurface
-> TileDeltaCommand?
```

```txt id="kjra3v"
TileDeltaCommand? + LayerId + FrameId
-> CacheInvalidationPlan
```

The next step is to introduce a small result object that can hold both:

```txt id="eo4cm3"
BrushCommitResult
= TileDeltaCommand?
+ CacheInvalidationPlan
```

This makes future canvas / undo / cache integration easier because a brush commit can return one object.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="yfr2ht"
1. Core project/timeline/storyboard model stability
2. BitmapSurface / BitmapTile / DirtyRegion foundation
3. TileDeltaCommand and cache invalidation model foundation
4. Brush input and BrushDab placement foundation
5. RGBA color and source-over blend math foundation
6. BrushDab pixel coverage foundation
7. BrushDab pixel blend foundation
8. BrushDabSequence pixel operation foundation
9. BitmapTile read/write helper foundation
10. BrushPixelBlendOperation list -> BitmapTile updated copy
11. BitmapTile before/after -> TileDeltaCommand connection
12. BrushDabSequence + one BitmapTile -> TileDeltaCommand?
13. BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
14. TileDeltaCommand? -> CacheInvalidationPlan
15. BrushCommitResult model
16. BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
17. Canvas UI integration
18. Undo/cache/playback integration
19. Save/load/export
```

Current local roadmap:

```txt id="0e2zor"
Phase 158: BrushDab.color + RgbaColor
Phase 159: RGBA source-over blend foundation
Phase 160: BrushDab -> BrushPixelCoverage
Phase 161: BrushDab + BrushPixelCoverage + destination RgbaColor -> blended RgbaColor
Phase 162: BrushDabSequence -> BrushPixelBlendOperation list
Phase 163: BitmapTile RGBA read/write helper foundation
Phase 164: BrushPixelBlendOperation list -> BitmapTile updated copy
Phase 165: BitmapTile + BrushPixelBlendOperation list -> TileDeltaCommand?
Phase 166: BrushDabSequence + one BitmapTile -> TileDeltaCommand?
Phase 167: BrushDabSequence + BitmapSurface -> multi-tile TileDeltaCommand?
Phase 168: TileDeltaCommand? + LayerId + FrameId -> CacheInvalidationPlan
Phase 169: BrushCommitResult model
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
```

Phase 169 is model-only.

It must not build a brush commit.

It must not apply a command.

It must not mutate a surface.

It must not invalidate actual caches.

It must not add undo/cache execution.

It must not add canvas UI.

## What structure this phase should create

Future brush commit should eventually flow like this:

```txt id="xm65sf"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> TileDeltaCommand?
-> CacheInvalidationPlan
-> BrushCommitResult
-> future surface apply
-> future cache invalidation
-> future undo stack
```

This phase only creates:

```txt id="a49kn3"
BrushCommitResult model
```

Meaning:

```txt id="603v2h"
BrushCommitResult.noOp()
= no TileDeltaCommand
= empty CacheInvalidationPlan

BrushCommitResult.changed(...)
= non-null TileDeltaCommand
= non-empty CacheInvalidationPlan
```

This is not actual brush commit execution.

This is not cache execution.

This is not undo integration.

## Required references

Before editing, read:

```txt id="odkzwv"
docs/Handoff_QuickAnimaker_v2_Current.md
docs/LongTerm_Roadmap_After_Phase_150.md
docs/Bitmap_Canvas_Brush_Architecture.md
docs/Timeline_Stabilization_Checkpoint.md
docs/LongTerm_Timeline_Range_Semantics.md
docs/Phase_152_Codex_Task.md
docs/Phase_153_Codex_Task.md
docs/Phase_154_Codex_Task.md
docs/Phase_155_Codex_Task.md
docs/Phase_156_Codex_Task.md
docs/Phase_157_Codex_Task.md
docs/Phase_158_Codex_Task.md
docs/Phase_159_Codex_Task.md
docs/Phase_160_Codex_Task.md
docs/Phase_161_Codex_Task.md
docs/Phase_162_Codex_Task.md
docs/Phase_163_Codex_Task.md
docs/Phase_164_Codex_Task.md
docs/Phase_165_Codex_Task.md
docs/Phase_166_Codex_Task.md
docs/Phase_167_Codex_Task.md
docs/Phase_168_Codex_Task.md
```

Also inspect:

```txt id="xnb5eq"
lib/src/models/tile_delta_command.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/models/dirty_tile_set.dart
lib/src/models/tile_delta.dart
lib/src/models/bitmap_tile.dart
lib/src/models/tile_coord.dart
test/models/tile_delta_command_test.dart
test/models/cache_invalidation_plan_test.dart
test/models/dirty_tile_set_test.dart
test/services/brush_commit_cache_invalidation_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add `BrushCommitResult` model:

```dart id="uzxj9x"
class BrushCommitResult {
  BrushCommitResult({
    required TileDeltaCommand? command,
    required CacheInvalidationPlan cacheInvalidationPlan,
  });

  factory BrushCommitResult.noOp();

  factory BrushCommitResult.changed({
    required TileDeltaCommand command,
    required CacheInvalidationPlan cacheInvalidationPlan,
  });

  final TileDeltaCommand? command;
  final CacheInvalidationPlan cacheInvalidationPlan;

  bool get hasChanges;
  bool get isNoOp;
  int get changedTileCount;
  DirtyTileSet get dirtyTiles;

  BrushCommitResult copyWith({
    Object? command,
    CacheInvalidationPlan? cacheInvalidationPlan,
  });

  Map<String, dynamic> toJson();
  factory BrushCommitResult.fromJson(Map<String, dynamic> json);
}
```

Exact implementation may follow the style of existing models.

## Required production file

Create:

```txt id="k85j7q"
lib/src/models/brush_commit_result.dart
```

## Required model behavior

### noOp behavior

```dart id="2fhqqk"
final result = BrushCommitResult.noOp();
```

Expected:

```txt id="9yzm8m"
result.command == null
result.cacheInvalidationPlan.isEmpty == true
result.hasChanges == false
result.isNoOp == true
result.changedTileCount == 0
result.dirtyTiles.isEmpty == true
```

### changed behavior

```dart id="r9k8vw"
final result = BrushCommitResult.changed(
  command: command,
  cacheInvalidationPlan: plan,
);
```

Expected:

```txt id="9yrryd"
result.command == command
result.cacheInvalidationPlan == plan
result.hasChanges == true
result.isNoOp == false
result.changedTileCount == command.length
result.dirtyTiles == command.dirtyTiles
```

## Validation rules

The constructor should validate consistency.

Required validation:

```txt id="hphhi4"
1. If command == null:
   cacheInvalidationPlan must be empty.

2. If command != null:
   cacheInvalidationPlan must be non-empty.
```

Reason:

```txt id="3bbrva"
A no-op brush commit should not invalidate cache.
A changed brush commit should have an invalidation plan.
```

Do not over-validate exact cache key contents yet.

Allowed future behavior:

```txt id="dtbxge"
Future phases may add frame composite or playback preview invalidations.
So this model should not require that cacheInvalidationPlan.layerTiles exactly equals command.dirtyTiles.
```

Only require empty/non-empty consistency.

## copyWith behavior

Suggested pattern:

```dart id="n00gnt"
BrushCommitResult copyWith({
  Object? command = _copyWithSentinel,
  CacheInvalidationPlan? cacheInvalidationPlan,
})
```

Reason:

```txt id="pqzp0r"
command is nullable, so copyWith needs a sentinel to distinguish:
- omit command
- explicitly set command to null
```

Expected:

```txt id="pqmx42"
copyWith() keeps existing values.
copyWith(command: null, cacheInvalidationPlan: CacheInvalidationPlan.empty()) can create no-op state.
copyWith(command: newCommand, cacheInvalidationPlan: newPlan) can create changed state.
```

## JSON behavior

`toJson` should include:

```txt id="55is2k"
command
cacheInvalidationPlan
```

For no-op:

```txt id="lg53le"
command should be null.
cacheInvalidationPlan should serialize as empty plan.
```

For changed:

```txt id="0yvlh0"
command should serialize with TileDeltaCommand.toJson().
cacheInvalidationPlan should serialize with CacheInvalidationPlan.toJson().
```

`fromJson` should restore equivalent object.

## Equality / hashCode / toString

Implement:

```txt id="r3gjzw"
operator ==
hashCode
toString
```

Expected equality fields:

```txt id="fzotdl"
command
cacheInvalidationPlan
```

## Required tests

Create:

```txt id="dwt2o0"
test/models/brush_commit_result_test.dart
```

Required tests:

```txt id="yy7tz2"
noOp creates null command and empty cache invalidation plan
noOp hasChanges is false
noOp isNoOp is true
noOp changedTileCount is 0
noOp dirtyTiles is empty

changed stores command and cache invalidation plan
changed hasChanges is true
changed isNoOp is false
changedTileCount equals command.length
dirtyTiles equals command.dirtyTiles

constructor rejects null command with non-empty cache invalidation plan
constructor rejects non-null command with empty cache invalidation plan

copyWith preserves existing values when omitted
copyWith can produce noOp when command is explicitly null and plan is empty
copyWith can produce changed result when command and plan are provided

toJson/fromJson round trips noOp
toJson/fromJson round trips changed result

equality compares command and cacheInvalidationPlan
hashCode matches equality
toString contains useful class name
```

## Suggested helpers

Suggested IDs:

```dart id="x6i8d8"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested tile helper:

```dart id="gqku0r"
BitmapTile tile(int x, int y) {
  return BitmapTile.blank(coord: TileCoord(x: x, y: y), size: 2);
}
```

Suggested command helper:

```dart id="16an74"
TileDeltaCommand commandForCoords(List<TileCoord> coords) {
  return TileDeltaCommand(
    deltas: coords.map(
      (coord) => TileDelta.created(
        BitmapTile.blank(coord: coord, size: 2),
      ),
    ),
  );
}
```

Suggested plan helper:

```dart id="dvrj1w"
CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
  return CacheInvalidationPlan.fromTileDeltaCommand(
    layerId: layerId,
    frameId: frameId,
    command: command,
  );
}
```

## Architecture rules

BrushCommitResult model rules:

```txt id="y1sqlr"
brush_commit_result.dart may know about TileDeltaCommand.
brush_commit_result.dart may know about CacheInvalidationPlan.
brush_commit_result.dart may know about DirtyTileSet.
brush_commit_result.dart must not know about BitmapSurface.
brush_commit_result.dart must not know about BrushDab.
brush_commit_result.dart must not know about BrushDabSequence.
brush_commit_result.dart must not know about LayerId.
brush_commit_result.dart must not know about FrameId.
brush_commit_result.dart must not build CacheInvalidationPlan from LayerId/FrameId.
brush_commit_result.dart must not apply TileDeltaCommand to BitmapSurface.
brush_commit_result.dart must not mutate cache.
brush_commit_result.dart must not implement undo.
brush_commit_result.dart must not add UI.
```

Important:

```txt id="lze3yk"
LayerId and FrameId are not part of BrushCommitResult.
They are input context used to create CacheInvalidationPlan before constructing BrushCommitResult.
```

Bitmap/cache boundary:

```txt id="c0n3gj"
TileDeltaCommand describes changed tiles.
CacheInvalidationPlan describes which cache keys become stale.
BrushCommitResult bundles both.
Actual BitmapSurface mutation is not performed by BrushCommitResult.
Actual cache eviction/recomputation is not performed by BrushCommitResult.
Undo stack is not performed by BrushCommitResult.
```

Timeline/storyboard boundary:

```txt id="5jtvco"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="ogkobl"
BrushCommitResult builder service
BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
BitmapSurface mutation
TileDeltaCommand applyAfter/applyBefore usage
actual cache storage
cache eviction
cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
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
renderer
playback implementation
save/load
persistence service
Provider
Riverpod
Bloc
ChangeNotifier
onion skin
export
Photoshop-style / ABR brush import
timeline changes
storyboard changes
```

## Expected changed files

Likely:

```txt id="aajyer"
lib/src/models/brush_commit_result.dart
test/models/brush_commit_result_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="s2v29q"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="uymb93"
- changed files
- BrushCommitResult fields
- noOp behavior
- changed behavior
- validation behavior
- copyWith behavior
- JSON behavior
- equality/hashCode/toString behavior
- dirtyTiles behavior
- changedTileCount behavior
- confirmation that no BrushCommitResult builder service was added
- confirmation that no BitmapSurface mutation was added
- confirmation that no TileDeltaCommand applyAfter/applyBefore usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no FrameCompositeCacheKey generation was added
- confirmation that no PlaybackPreviewCacheKey generation was added
- confirmation that no UndoService/undo stack was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 169 is complete when:

```txt id="f1p1sc"
- brush_commit_result.dart exists and is tested.
- BrushCommitResult.noOp() creates null command and empty plan.
- noOp.hasChanges == false.
- noOp.isNoOp == true.
- noOp.changedTileCount == 0.
- noOp.dirtyTiles is empty.
- BrushCommitResult.changed(...) stores command and plan.
- changed.hasChanges == true.
- changed.isNoOp == false.
- changed.changedTileCount == command.length.
- changed.dirtyTiles == command.dirtyTiles.
- Constructor rejects command == null with non-empty plan.
- Constructor rejects command != null with empty plan.
- copyWith preserves existing values when omitted.
- copyWith can explicitly set command to null with empty plan.
- copyWith can set command and non-empty plan.
- toJson/fromJson round trips noOp.
- toJson/fromJson round trips changed.
- Equality compares command and plan.
- hashCode is consistent with equality.
- toString is useful.
- Existing brush commit cache invalidation tests still pass.
- Existing CacheInvalidationPlan tests still pass.
- Existing LayerTileCacheKey tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing one-tile brush commit tests still pass.
- Existing BitmapTile operation delta tests still pass.
- Existing BitmapTile operation apply tests still pass.
- Existing BitmapTile RGBA helper tests still pass.
- Existing TileDelta tests still pass.
- Existing BrushPixelBlendOperation tests still pass.
- Existing BrushDabSequence blend tests still pass.
- Existing BrushPixelCoverage tests still pass.
- Existing BrushDab coverage tests still pass.
- Existing Brush pixel blend tests still pass.
- Existing RgbaColor / rgba_blend tests still pass.
- Existing bitmap / dirty region tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No BrushCommitResult builder service was added.
- No BitmapSurface mutation was added.
- No cache execution behavior was added.
- No UndoService / undo stack was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is model-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="bigvgl"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
