# Phase 175 Codex Task

## Title

Create BrushDabSequence to CanvasSurfaceState commit service

## Repository

```txt id="qri2ml"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="d35m0d"
master
```

## Project type

```txt id="xe13ka"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 174.

Recent bitmap canvas / brush foundation phases:

```txt id="gid6qf"
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
Phase 173: BrushSurfaceEdit model and builder service
Phase 174: CanvasSurfaceState model and BrushSurfaceEdit apply service
```

## Existing pieces

Phase 173 introduced:

```txt id="soc1ig"
BrushSurfaceEdit
= beforeSurface
+ afterSurface
+ commitResult
```

Phase 174 introduced:

```txt id="k2tv9k"
CanvasSurfaceState
= currentSurface
+ lastEdit?
```

and:

```txt id="uu3n66"
CanvasSurfaceState + BrushSurfaceEdit
-> applyBrushSurfaceEditToCanvasSurfaceState(...)
-> CanvasSurfaceState
```

The next step is to create a single service that takes a `BrushDabSequence` and commits it to the current `CanvasSurfaceState`.

## Important concept

This is still not UI.

This is still not a controller.

This is still not an undo stack.

This is still not cache invalidation execution.

This is a pure composition service:

```txt id="f0y2of"
CanvasSurfaceState
+ BrushDabSequence
+ LayerId
+ FrameId
-> BrushSurfaceEdit
-> CanvasSurfaceState
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="kcjvty"
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
20. CanvasSurfaceState model and BrushSurfaceEdit apply service
21. BrushDabSequence -> CanvasSurfaceState commit service
22. Undo/cache/playback integration
23. Save/load/export
```

Current local roadmap:

```txt id="tijr1d"
Phase 173: BrushSurfaceEdit model and builder service
Phase 174: CanvasSurfaceState model and BrushSurfaceEdit apply service
Phase 175: BrushDabSequence + CanvasSurfaceState + LayerId + FrameId -> CanvasSurfaceState
Phase 176: Brush edit history entry or undo stack foundation
```

Phase 175 is service-only.

It must not add canvas UI.

It must not add UndoService or an undo stack.

It must not execute cache invalidation.

It must not introduce Provider, Riverpod, Bloc, ChangeNotifier, or any state management package.

## What structure this phase should create

Future canvas integration will eventually call a single service like this:

```txt id="xljrja"
newState = commitBrushDabSequenceToCanvasSurfaceState(
  state: currentState,
  sequence: sequence,
  layerId: activeLayerId,
  frameId: activeFrameId,
)
```

This service should internally compose existing services:

```txt id="kwdr71"
1. brushSurfaceEditForBrushDabSequenceOnBitmapSurface
2. applyBrushSurfaceEditToCanvasSurfaceState
```

Meaning:

```txt id="0ncegd"
CanvasSurfaceState.currentSurface
+ BrushDabSequence
+ LayerId
+ FrameId
-> BrushSurfaceEdit
-> CanvasSurfaceState
```

This phase should not manually build deltas, surfaces, or cache plans.

## Required references

Before editing, read:

```txt id="dn9sfy"
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
docs/Phase_173_Codex_Task.md
docs/Phase_174_Codex_Task.md
```

Also inspect:

```txt id="yzkzrt"
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_surface_edit.dart
lib/src/models/brush_dab.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/bitmap_surface.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/services/brush_surface_edit_builder.dart
lib/src/services/canvas_surface_state_edit.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
test/models/canvas_surface_state_test.dart
test/services/canvas_surface_state_edit_test.dart
test/models/brush_surface_edit_test.dart
test/services/brush_surface_edit_builder_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add service:

```dart id="ve8o99"
CanvasSurfaceState commitBrushDabSequenceToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

## Required production file

Create:

```txt id="g81med"
lib/src/services/canvas_surface_state_brush_commit.dart
```

## Required service behavior

The function:

```dart id="symru3"
CanvasSurfaceState commitBrushDabSequenceToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

should:

```txt id="tc42no"
1. Build a BrushSurfaceEdit by calling:

   brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
     surface: state.currentSurface,
     sequence: sequence,
     layerId: layerId,
     frameId: frameId,
   )

2. Store the result as edit.

3. Apply the edit to the state by calling:

   applyBrushSurfaceEditToCanvasSurfaceState(
     state: state,
     edit: edit,
   )

4. Return the resulting CanvasSurfaceState.
```

Important:

```txt id="iwy3vo"
Do not manually build BrushSurfaceEdit.
Do not manually build BrushCommitResult.
Do not manually build TileDeltaCommand.
Do not manually build CacheInvalidationPlan.
Do not manually apply TileDelta objects.
Do not manually call surface.putTile.
Do not manually call surface.removeTile.
Do not execute cache invalidation.
```

Reason:

```txt id="q2i94s"
Phase 173 owns BrushSurfaceEdit construction.
Phase 174 owns CanvasSurfaceState edit application.
Phase 175 should only compose those services.
```

## No-op behavior

If the sequence produces no changes:

```txt id="aa4igl"
commitBrushDabSequenceToCanvasSurfaceState(...)
```

should return the same `CanvasSurfaceState` instance because Phase 174 service returns the same state for no-op edits.

Expected:

```txt id="dq0ixi"
identical(nextState, state) == true
```

No-op should also preserve existing `lastEdit`.

## Changed behavior

If the sequence produces changes:

```txt id="3a1io2"
nextState.currentSurface != state.currentSurface
nextState.lastEdit != null
nextState.lastEdit!.beforeSurface == state.currentSurface
nextState.lastEdit!.afterSurface == nextState.currentSurface
nextState.lastEdit!.commitResult.hasChanges == true
```

## Required tests

Create:

```txt id="sbxz0b"
test/services/canvas_surface_state_brush_commit_test.dart
```

Required tests:

```txt id="ec482w"
returns same CanvasSurfaceState instance for empty BrushDabSequence
no-op commit preserves existing lastEdit
returns same CanvasSurfaceState instance for non-effective dab
changed commit updates currentSurface
changed commit sets lastEdit
changed commit lastEdit.beforeSurface equals previous state.currentSurface
changed commit lastEdit.afterSurface equals nextState.currentSurface
changed commit lastEdit.commitResult has changes
changed commit can be reverted with revertBrushCommitResultOnBitmapSurface
commit result cache invalidation plan uses provided LayerId
commit result cache invalidation plan uses provided FrameId
changed commit result matches manual composition of:
  brushSurfaceEditForBrushDabSequenceOnBitmapSurface
  applyBrushSurfaceEditToCanvasSurfaceState
multi-tile dab updates multiple tiles
does not mutate previous CanvasSurfaceState
does not mutate original BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushDabSequence
does not mutate BrushDab
does not execute CacheInvalidationPlan
does not add undo stack behavior
```

## Suggested helpers

Avoid unnecessary `const` on model constructors unless the constructor is known to be const.

Suggested IDs:

```dart id="daruno"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="so489m"
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

Suggested one-pixel dab helper:

```dart id="ugdn3b"
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

```dart id="zon8qf"
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

### No-op sequence

```txt id="q8fc0p"
state = CanvasSurfaceState(currentSurface: surface)
sequence = BrushDabSequence()

nextState = commitBrushDabSequenceToCanvasSurfaceState(...)

expected:
identical(nextState, state) == true
```

### Non-effective dab

```txt id="5z05va"
dab.opacity = 0
sequence = BrushDabSequence([dab])

expected:
identical(nextState, state) == true
```

### Changed sequence

```txt id="ck52he"
state.currentSurface has no tile at TileCoord(0,0)
dab affects pixel (0,0)

expected:
nextState.currentSurface.tileAt(TileCoord(0,0)) != null
nextState.lastEdit != null
nextState.lastEdit!.beforeSurface == state.currentSurface
nextState.lastEdit!.afterSurface == nextState.currentSurface
```

### Manual composition equivalence

```txt id="lqfua6"
edit = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
  surface: state.currentSurface,
  sequence: sequence,
  layerId: layerId,
  frameId: frameId,
)

expected = applyBrushSurfaceEditToCanvasSurfaceState(
  state: state,
  edit: edit,
)

actual = commitBrushDabSequenceToCanvasSurfaceState(...)

expect(actual, expected)
```

### Revert last edit

```txt id="smjctw"
revertedSurface = revertBrushCommitResultOnBitmapSurface(
  surface: nextState.currentSurface,
  result: nextState.lastEdit!.commitResult,
)

expect(revertedSurface, state.currentSurface)
```

## Architecture rules

CanvasSurfaceState brush commit service rules:

```txt id="n7vtd1"
canvas_surface_state_brush_commit.dart may know about CanvasSurfaceState.
canvas_surface_state_brush_commit.dart may know about BrushDabSequence.
canvas_surface_state_brush_commit.dart may know about LayerId.
canvas_surface_state_brush_commit.dart may know about FrameId.
canvas_surface_state_brush_commit.dart may call brushSurfaceEditForBrushDabSequenceOnBitmapSurface.
canvas_surface_state_brush_commit.dart may call applyBrushSurfaceEditToCanvasSurfaceState.
canvas_surface_state_brush_commit.dart must not manually create BrushSurfaceEdit.
canvas_surface_state_brush_commit.dart must not manually create BrushCommitResult.
canvas_surface_state_brush_commit.dart must not manually create TileDeltaCommand.
canvas_surface_state_brush_commit.dart must not manually create CacheInvalidationPlan.
canvas_surface_state_brush_commit.dart must not manually apply TileDelta objects.
canvas_surface_state_brush_commit.dart must not call surface.putTile directly.
canvas_surface_state_brush_commit.dart must not call surface.removeTile directly.
canvas_surface_state_brush_commit.dart must not execute cache invalidation.
canvas_surface_state_brush_commit.dart must not implement UndoService.
canvas_surface_state_brush_commit.dart must not add undo stack behavior.
canvas_surface_state_brush_commit.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="cjknzl"
BitmapSurface is immutable data.
BrushSurfaceEdit bundles before surface, after surface, and commit result.
CanvasSurfaceState holds the current BitmapSurface and optionally the last edit.
This commit service composes existing services only.
CacheInvalidationPlan describes stale cache keys but is not executed in this phase.
Undo stack is not performed in this phase.
```

Timeline/storyboard boundary:

```txt id="s597d8"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="pvqd08"
Canvas UI integration
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

```txt id="jo20gm"
lib/src/services/canvas_surface_state_brush_commit.dart
test/services/canvas_surface_state_brush_commit_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="d4w1a3"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="hkebm7"
- changed files
- commitBrushDabSequenceToCanvasSurfaceState behavior
- no-op sequence behavior
- non-effective dab behavior
- changed sequence behavior
- lastEdit behavior
- manual composition equivalence behavior
- revert lastEdit behavior
- LayerId/FrameId cache invalidation propagation behavior
- previous state immutability behavior
- original surface/tile immutability behavior
- BrushDabSequence/BrushDab immutability behavior
- confirmation that no Canvas UI integration was added
- confirmation that no UndoService/undo stack was added
- confirmation that no manual TileDelta application was added
- confirmation that no direct surface.putTile/removeTile usage was added
- confirmation that no actual cache storage was added
- confirmation that no cache eviction/recomputation was added
- confirmation that no Provider/Riverpod/Bloc/ChangeNotifier was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 175 is complete when:

```txt id="o6lzgw"
- canvas_surface_state_brush_commit.dart exists and is tested.
- Empty BrushDabSequence returns same CanvasSurfaceState instance.
- No-op commit preserves existing lastEdit.
- Non-effective dab returns same CanvasSurfaceState instance.
- Changed commit updates currentSurface.
- Changed commit sets lastEdit.
- lastEdit.beforeSurface equals previous state.currentSurface.
- lastEdit.afterSurface equals nextState.currentSurface.
- lastEdit.commitResult.hasChanges is true for changed commit.
- Changed commit can be reverted with revertBrushCommitResultOnBitmapSurface.
- Cache invalidation plan uses provided LayerId.
- Cache invalidation plan uses provided FrameId.
- Result matches manual composition of brushSurfaceEditForBrushDabSequenceOnBitmapSurface and applyBrushSurfaceEditToCanvasSurfaceState.
- Multi-tile dab updates multiple tiles.
- Previous CanvasSurfaceState is not mutated.
- Original BitmapSurface is not mutated.
- Existing BitmapTile is not mutated.
- BrushDabSequence is not mutated.
- BrushDab is not mutated.
- CacheInvalidationPlan is not executed.
- No Canvas UI integration was added.
- No UndoService / undo stack behavior was added.
- No Provider/Riverpod/Bloc/ChangeNotifier was added.
- Existing CanvasSurfaceState tests still pass.
- Existing canvas surface state edit tests still pass.
- Existing BrushSurfaceEdit tests still pass.
- Existing brush surface edit builder tests still pass.
- Existing brush commit result revert tests still pass.
- Existing brush commit result apply tests still pass.
- Existing brush commit builder tests still pass.
- Existing bitmap / dirty region / brush tests still pass.
- Existing timeline/storyboard stabilization tests still pass.
- No manual TileDelta application was added.
- No direct surface.putTile/removeTile usage was added.
- No cache execution behavior was added.
- No drawing canvas UI was added.
```

## Manual check list

This phase is service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="pv77sv"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
