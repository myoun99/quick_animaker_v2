# Phase 173 Codex Task

## Title

Create BrushSurfaceEdit model and builder service

## Repository

```txt id="drvrad"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="y9k03r"
master
```

## Project type

```txt id="ugz0p9"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 172.

Recent bitmap canvas / brush foundation phases:

```txt id="wdth5s"
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
Phase 169: BrushCommitResult model
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult -> BitmapSurface applyAfter service
Phase 172: BrushCommitResult -> BitmapSurface applyBefore/revert service
```

## Existing brush commit pieces

The current pipeline has:

```txt id="tv1zrz"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushCommitResult
```

A `BrushCommitResult` contains:

```txt id="qv6ddp"
TileDeltaCommand? command
CacheInvalidationPlan cacheInvalidationPlan
```

Phase 171 added:

```txt id="oa7gpg"
BrushCommitResult + BitmapSurface
-> applyBrushCommitResultToBitmapSurface(...)
-> BitmapSurface
```

Phase 172 added:

```txt id="f2u010"
BrushCommitResult + BitmapSurface
-> revertBrushCommitResultOnBitmapSurface(...)
-> BitmapSurface
```

Phase 173 should create a transient edit object:

```txt id="f0pj61"
BrushSurfaceEdit
= beforeSurface
+ afterSurface
+ BrushCommitResult
```

and a builder service:

```txt id="8qmdeu"
BrushDabSequence + BitmapSurface + LayerId + FrameId
-> BrushSurfaceEdit
```

## Important concept

`BrushSurfaceEdit` is a transient edit result.

It is not a persistent history entry yet.

It is not a save format.

It is not a cache.

It is not an undo stack.

It exists to carry one brush operation result safely into future canvas state integration.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="xs8tg2"
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
17. BrushCommitResult -> BitmapSurface apply service
18. BrushCommitResult -> BitmapSurface revert service
19. BrushSurfaceEdit model and builder
20. Canvas state integration
21. Undo/cache/playback integration
22. Save/load/export
```

Current local roadmap:

```txt id="q4cnfw"
Phase 170: BrushDabSequence + BitmapSurface + LayerId + FrameId -> BrushCommitResult
Phase 171: BrushCommitResult -> BitmapSurface applyAfter service
Phase 172: BrushCommitResult -> BitmapSurface applyBefore/revert service
Phase 173: BrushSurfaceEdit model and builder service
Phase 174: Canvas surface state draft or brush edit commit API draft
```

Phase 173 is model + service only.

It must not add undo stack behavior.

It must not execute cache invalidation.

It must not add canvas UI.

It must not introduce Provider/Riverpod/Bloc/ChangeNotifier.

## What structure this phase should create

Future canvas state integration will eventually flow like this:

```txt id="xro9xv"
currentSurface
+ BrushDabSequence
+ LayerId
+ FrameId
-> BrushSurfaceEdit

BrushSurfaceEdit.beforeSurface
BrushSurfaceEdit.afterSurface
BrushSurfaceEdit.commitResult

future:
- canvas state uses afterSurface
- undo stack stores commitResult or command
- cache invalidation executor uses commitResult.cacheInvalidationPlan
```

This phase only creates:

```txt id="zbgi3e"
BrushSurfaceEdit model
BrushSurfaceEdit builder service
```

Meaning:

```txt id="rh5gx9"
brushSurfaceEditForBrushDabSequenceOnBitmapSurface
= takes current BitmapSurface
= takes BrushDabSequence
= takes LayerId
= takes FrameId
= builds BrushCommitResult using existing Phase 170 builder
= applies BrushCommitResult using existing Phase 171 apply service
= returns BrushSurfaceEdit(beforeSurface, afterSurface, commitResult)
```

This is not an undo stack.

This is not HistoryService.

This is not mutable state management.

This is not UI.

This is not cache execution.

## Required references

Before editing, read:

```txt id="brjzr5"
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
docs/Phase_169_Codex_Task.md
docs/Phase_170_Codex_Task.md
docs/Phase_171_Codex_Task.md
docs/Phase_172_Codex_Task.md
```

Also inspect:

```txt id="r0hxa1"
lib/src/models/brush_commit_result.dart
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/tile_delta_command.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/services/brush_commit_builder.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
test/models/brush_commit_result_test.dart
test/services/brush_commit_builder_test.dart
test/services/brush_commit_result_apply_test.dart
test/services/brush_commit_result_revert_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add model:

```dart id="kujvbs"
class BrushSurfaceEdit {
  const BrushSurfaceEdit({
    required this.beforeSurface,
    required this.afterSurface,
    required this.commitResult,
  });

  final BitmapSurface beforeSurface;
  final BitmapSurface afterSurface;
  final BrushCommitResult commitResult;

  bool get hasChanges;
  bool get isNoOp;
  BitmapSurface get effectiveSurface;

  BrushSurfaceEdit copyWith({
    BitmapSurface? beforeSurface,
    BitmapSurface? afterSurface,
    BrushCommitResult? commitResult,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Add builder service:

```dart id="ng0sch"
BrushSurfaceEdit brushSurfaceEditForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

## Required production files

Create:

```txt id="wjap6w"
lib/src/models/brush_surface_edit.dart
lib/src/services/brush_surface_edit_builder.dart
```

## Required model behavior

### BrushSurfaceEdit fields

```txt id="c5zjx6"
beforeSurface
afterSurface
commitResult
```

### hasChanges

```txt id="d1ljrl"
hasChanges == commitResult.hasChanges
```

### isNoOp

```txt id="x5shla"
isNoOp == commitResult.isNoOp
```

### effectiveSurface

```txt id="hpht8z"
effectiveSurface == afterSurface
```

Reason:

```txt id="ef6npa"
The caller wants the surface that should become current after this edit.
```

### no-op edit behavior

For a no-op edit:

```txt id="0ga3w5"
commitResult == BrushCommitResult.noOp()
beforeSurface == afterSurface
hasChanges == false
isNoOp == true
effectiveSurface == afterSurface
```

Prefer same instance for before/after when the apply service returns same instance:

```txt id="fdd8ek"
identical(beforeSurface, afterSurface) == true
```

Do not require identity in the model constructor, but builder tests should verify the no-op builder path preserves the same instance.

### changed edit behavior

For a changed edit:

```txt id="5yx6l4"
commitResult.hasChanges == true
afterSurface == applyBrushCommitResultToBitmapSurface(
  surface: beforeSurface,
  result: commitResult,
)
hasChanges == true
isNoOp == false
effectiveSurface == afterSurface
```

## Validation rules

Keep validation minimal.

The model constructor should validate only:

```txt id="xevily"
1. If commitResult.isNoOp:
   beforeSurface must equal afterSurface.

2. If commitResult.hasChanges:
   beforeSurface and afterSurface may differ.
```

Do not validate by re-applying the command inside the model constructor.

Reason:

```txt id="7m2dgy"
The model should remain a simple data holder.
The builder service is responsible for producing consistent before/after surfaces.
```

Do not require `beforeSurface != afterSurface` for changed edits.

Reason:

```txt id="n2bgf4"
Future edge cases may create a command with meaningful cache invalidation or metadata even if surfaces compare equal.
```

## copyWith behavior

`copyWith` should preserve omitted values.

Expected:

```txt id="7jrp5s"
copyWith() == original
copyWith(afterSurface: otherSurface) updates afterSurface
copyWith(commitResult: BrushCommitResult.noOp(), beforeSurface: sameSurface, afterSurface: sameSurface) can create no-op edit
```

No nullable sentinel is required because fields are non-null.

## JSON behavior

Do not implement JSON in Phase 173.

Reason:

```txt id="i4y258"
BrushSurfaceEdit contains full BitmapSurface objects and is intended to be transient.
It is not a save format or history storage format yet.
```

## Equality / hashCode / toString

Implement:

```txt id="sdvqv6"
operator ==
hashCode
toString
```

Expected equality fields:

```txt id="4slqx7"
beforeSurface
afterSurface
commitResult
```

## Required builder service behavior

The function:

```dart id="xuxo8u"
BrushSurfaceEdit brushSurfaceEditForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

should:

```txt id="6wwwjs"
1. Call brushCommitResultForBrushDabSequenceOnBitmapSurface(
     surface: surface,
     sequence: sequence,
     layerId: layerId,
     frameId: frameId,
   )

2. Store the result as commitResult.

3. Call applyBrushCommitResultToBitmapSurface(
     surface: surface,
     result: commitResult,
   )

4. Store the result as afterSurface.

5. Return BrushSurfaceEdit(
     beforeSurface: surface,
     afterSurface: afterSurface,
     commitResult: commitResult,
   )
```

Important:

```txt id="brhq2r"
Do not manually build TileDeltaCommand.
Do not manually build CacheInvalidationPlan.
Do not manually apply TileDelta objects.
Do not manually call surface.putTile.
Do not manually call surface.removeTile.
Do not execute cache invalidation.
```

Reason:

```txt id="bg2dl6"
Phase 170 owns BrushCommitResult building.
Phase 171 owns applying BrushCommitResult to BitmapSurface.
Phase 173 should only compose those existing services and bundle the before/after surfaces.
```

## Required tests

Create:

```txt id="nigaut"
test/models/brush_surface_edit_test.dart
test/services/brush_surface_edit_builder_test.dart
```

## Required model tests

```txt id="vo8hhd"
stores beforeSurface, afterSurface, and commitResult
hasChanges delegates to commitResult.hasChanges
isNoOp delegates to commitResult.isNoOp
effectiveSurface returns afterSurface
constructor accepts no-op edit when beforeSurface equals afterSurface
constructor rejects no-op edit when beforeSurface differs from afterSurface
constructor accepts changed edit
copyWith preserves existing values when omitted
copyWith updates fields
equality compares beforeSurface, afterSurface, and commitResult
hashCode matches equality
toString contains useful class name
```

## Required builder tests

```txt id="io0x7y"
returns no-op BrushSurfaceEdit for empty BrushDabSequence
no-op edit uses same before and after surface instance
no-op edit commitResult is BrushCommitResult.noOp

returns changed BrushSurfaceEdit for dab on missing tile
changed edit beforeSurface is original surface
changed edit afterSurface contains created tile
changed edit commitResult has changes
changed edit effectiveSurface equals afterSurface

returns changed BrushSurfaceEdit for dab on existing tile
changed edit afterSurface equals applyBrushCommitResultToBitmapSurface manual result
changed edit can be reverted with revertBrushCommitResultOnBitmapSurface back to beforeSurface

multi-tile dab produces afterSurface with multiple changed tiles

builder result matches manual composition of:
  brushCommitResultForBrushDabSequenceOnBitmapSurface
  applyBrushCommitResultToBitmapSurface
  BrushSurfaceEdit

cache invalidation plan uses provided LayerId
cache invalidation plan uses provided FrameId

does not mutate original BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushDabSequence
does not mutate BrushDab
does not execute cache invalidation
does not add undo stack behavior
```

## Suggested helpers

Suggested IDs:

```dart id="hx7ewr"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="qt63cu"
BitmapSurface surface({
  int width = 4,
  int height = 4,
  int tileSize = 2,
  Map<TileCoord, BitmapTile> tiles = const {},
}) {
  return BitmapSurface(
    canvasSize: CanvasSize(width: width, height: height),
    tileSize: tileSize,
    tiles: tiles,
  );
}
```

Suggested tile helper:

```dart id="jm79ub"
BitmapTile blankTile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(coord: TileCoord(x: tileX, y: tileY), size: size);
}
```

Suggested one-pixel dab helper:

```dart id="roay5h"
BrushDab onePixelDab({
  required double globalX,
  required double globalY,
  int color = 0xFFFF0000,
  double opacity = 1,
  double flow = 1,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: globalX + 0.5, y: globalY + 0.5),
    color: color,
    size: 1,
    opacity: opacity,
    flow: flow,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: sequence,
  );
}
```

Suggested square dab helper:

```dart id="ux5fdb"
BrushDab squareDab({
  required double centerX,
  required double centerY,
  int color = 0xFFFF0000,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: centerX, y: centerY),
    color: color,
    size: 2,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.square,
    pressure: 1,
    sequence: sequence,
  );
}
```

## Suggested examples

### No-op edit

```txt id="uwjxfk"
surface = BitmapSurface(...)
sequence = BrushDabSequence()

edit = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(...)

expected:
edit.beforeSurface == surface
edit.afterSurface == surface
identical(edit.beforeSurface, edit.afterSurface) == true
edit.commitResult == BrushCommitResult.noOp()
edit.hasChanges == false
edit.isNoOp == true
edit.effectiveSurface == edit.afterSurface
```

### Changed edit on missing tile

```txt id="c8w8xg"
surface has no tile at TileCoord(0,0)
dab affects global pixel (0,0)

expected:
edit.hasChanges == true
edit.beforeSurface.tileAt(TileCoord(0,0)) == null
edit.afterSurface.tileAt(TileCoord(0,0)) != null
edit.commitResult.command!.deltas.single.isCreation == true
```

### Changed edit on existing tile

```txt id="u0i0x2"
surface has tile before at TileCoord(0,0)
dab affects global pixel (0,0)

expected:
edit.hasChanges == true
edit.afterSurface != edit.beforeSurface
edit.commitResult.command!.deltas.single.isReplacement == true
```

### Manual composition equivalence

```txt id="xw4u8m"
commitResult = brushCommitResultForBrushDabSequenceOnBitmapSurface(...)
afterSurface = applyBrushCommitResultToBitmapSurface(
  surface: surface,
  result: commitResult,
)
expected = BrushSurfaceEdit(
  beforeSurface: surface,
  afterSurface: afterSurface,
  commitResult: commitResult,
)

actual = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(...)

expect(actual, expected)
```

### Revert equivalence

```txt id="08x060"
reverted = revertBrushCommitResultOnBitmapSurface(
  surface: edit.afterSurface,
  result: edit.commitResult,
)

expect(reverted, edit.beforeSurface)
```

## Architecture rules

BrushSurfaceEdit model rules:

```txt id="cmrddt"
brush_surface_edit.dart may know about BitmapSurface.
brush_surface_edit.dart may know about BrushCommitResult.
brush_surface_edit.dart must not know about BrushDab.
brush_surface_edit.dart must not know about BrushDabSequence.
brush_surface_edit.dart must not know about LayerId.
brush_surface_edit.dart must not know about FrameId.
brush_surface_edit.dart must not build BrushCommitResult.
brush_surface_edit.dart must not apply BrushCommitResult.
brush_surface_edit.dart must not revert BrushCommitResult.
brush_surface_edit.dart must not execute cache invalidation.
brush_surface_edit.dart must not implement undo.
brush_surface_edit.dart must not add UI.
```

BrushSurfaceEdit builder rules:

```txt id="qwh94z"
brush_surface_edit_builder.dart may know about BitmapSurface.
brush_surface_edit_builder.dart may know about BrushDabSequence.
brush_surface_edit_builder.dart may know about LayerId.
brush_surface_edit_builder.dart may know about FrameId.
brush_surface_edit_builder.dart may know about BrushSurfaceEdit.
brush_surface_edit_builder.dart may call brushCommitResultForBrushDabSequenceOnBitmapSurface.
brush_surface_edit_builder.dart may call applyBrushCommitResultToBitmapSurface.
brush_surface_edit_builder.dart must not manually create TileDeltaCommand.
brush_surface_edit_builder.dart must not manually create CacheInvalidationPlan.
brush_surface_edit_builder.dart must not manually apply TileDelta objects.
brush_surface_edit_builder.dart must not call surface.putTile directly.
brush_surface_edit_builder.dart must not call surface.removeTile directly.
brush_surface_edit_builder.dart must not execute cache invalidation.
brush_surface_edit_builder.dart must not implement undo.
brush_surface_edit_builder.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="r91c93"
TileDeltaCommand describes changed tiles.
CacheInvalidationPlan describes stale cache keys.
BrushCommitResult bundles command and cache plan.
BrushSurfaceEdit bundles before surface, after surface, and commit result.
BrushSurfaceEdit is transient.
Actual cache eviction/recomputation is not performed by this phase.
Undo stack is not performed by this phase.
```

Timeline/storyboard boundary:

```txt id="q28xz8"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="s3zkzr"
Canvas state integration
UndoService
UndoStack
RedoStack
HistoryService
actual cache storage
cache eviction
cache recomputation
LayerTileCache implementation
FrameCompositeCache implementation
PlaybackPreviewCache implementation
FrameCompositeCacheKey generation
PlaybackPreviewCacheKey generation
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

```txt id="d9je7x"
lib/src/models/brush_surface_edit.dart
lib/src/services/brush_surface_edit_builder.dart
test/models/brush_surface_edit_test.dart
test/services/brush_surface_edit_builder_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="wbg6pl"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="xizxzb"
- changed files
- BrushSurfaceEdit model behavior
- no-op edit behavior
- changed edit behavior
- builder behavior
- manual composition equivalence behavior
- forward/revert round-trip behavior
- original surface immutability behavior
- existing tile immutability behavior
- BrushDabSequence/BrushDab immutability behavior
- cache invalidation plan LayerId/FrameId behavior
- confirmation that no Canvas state integration was added
- confirmation that no UndoService/undo stack was added
- confirmation that no manual TileDelta application was added
- confirmation that no direct surface.putTile/removeTile usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no canvas UI was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 173 is complete when:

```txt id="pc32md"
- brush_surface_edit.dart exists and is tested.
- brush_surface_edit_builder.dart exists and is tested.
- BrushSurfaceEdit stores beforeSurface, afterSurface, and commitResult.
- hasChanges delegates to commitResult.hasChanges.
- isNoOp delegates to commitResult.isNoOp.
- effectiveSurface returns afterSurface.
- no-op edit requires equal before/after surfaces.
- changed edit is accepted.
- copyWith works.
- equality/hashCode/toString work.
- builder returns no-op edit for empty sequence.
- no-op edit preserves same before/after surface instance.
- builder returns changed edit for dab on missing tile.
- builder returns changed edit for dab on existing tile.
- afterSurface equals manual apply result.
- changed edit can be reverted back to beforeSurface.
- multi-tile dab changes multiple tiles.
- builder result equals manual composition.
- cache invalidation plan uses provided LayerId.
- cache invalidation plan uses provided FrameId.
- original BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- BrushDabSequence is not mutated.
- BrushDab is not mutated.
- CacheInvalidationPlan is not executed.
- No Canvas state integration was added.
- No UndoService / undo stack behavior was added.
- Existing brush commit result revert tests still pass.
- Existing brush commit result apply tests still pass.
- Existing BrushCommitResult tests still pass.
- Existing brush commit builder tests still pass.
- Existing brush commit cache invalidation tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing CacheInvalidationPlan tests still pass.
- Existing TileDeltaCommand tests still pass.
- Existing BitmapTile operation delta tests still pass.
- Existing one-tile brush commit tests still pass.
- Existing bitmap / dirty region / brush tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No manual TileDelta application was added.
- No direct surface.putTile/removeTile usage was added.
- No cache execution behavior was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="rtz0tr"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
