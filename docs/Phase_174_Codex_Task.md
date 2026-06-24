# Phase 174 Codex Task

## Title

Create CanvasSurfaceState model and BrushSurfaceEdit apply service

## Repository

```txt id="gce247"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="ri4txx"
master
```

## Project type

```txt id="t0y4lu"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 173.

Recent bitmap canvas / brush foundation phases:

```txt id="i0n1mf"
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
```

## Existing pieces

Phase 173 introduced:

```txt id="r23x6f"
BrushSurfaceEdit
= beforeSurface
+ afterSurface
+ commitResult
```

A `BrushSurfaceEdit` is a transient result of one brush operation.

Current flow:

```txt id="107p8h"
BitmapSurface
+ BrushDabSequence
+ LayerId
+ FrameId
-> BrushSurfaceEdit
```

The next step is to create a small immutable state model that can hold the current canvas bitmap surface:

```txt id="c8dkpe"
CanvasSurfaceState
= currentSurface
+ lastEdit?
```

Then add a pure service:

```txt id="7rkyaz"
CanvasSurfaceState + BrushSurfaceEdit
-> CanvasSurfaceState
```

This prepares future canvas state integration without adding UI or a state management package.

## Important concept

`CanvasSurfaceState` is not a Flutter widget state.

It is not Provider, Riverpod, Bloc, or ChangeNotifier.

It is a plain immutable model that represents the current bitmap surface state for a future canvas controller.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="d6c4xq"
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

```txt id="nr3mcg"
Phase 171: BrushCommitResult -> BitmapSurface applyAfter service
Phase 172: BrushCommitResult -> BitmapSurface applyBefore/revert service
Phase 173: BrushSurfaceEdit model and builder service
Phase 174: CanvasSurfaceState model and BrushSurfaceEdit apply service
Phase 175: BrushDabSequence + CanvasSurfaceState + LayerId + FrameId -> CanvasSurfaceState
```

Phase 174 is model + service only.

It must not add canvas UI.

It must not add UndoService or an undo stack.

It must not execute cache invalidation.

It must not introduce Provider, Riverpod, Bloc, ChangeNotifier, or any state management package.

## What structure this phase should create

Future canvas integration will eventually flow like this:

```txt id="x2ccp5"
CanvasSurfaceState(currentSurface)
+ BrushDabSequence
+ LayerId
+ FrameId
-> BrushSurfaceEdit
-> CanvasSurfaceState(currentSurface: edit.afterSurface, lastEdit: edit)
```

Phase 174 should only implement the middle state update step:

```txt id="rkf1gq"
CanvasSurfaceState + BrushSurfaceEdit -> CanvasSurfaceState
```

Meaning:

```txt id="4q3szp"
applyBrushSurfaceEditToCanvasSurfaceState
= takes current immutable state
= takes a BrushSurfaceEdit
= validates edit.beforeSurface == state.currentSurface
= if edit is no-op, returns the same state instance
= if edit has changes, returns a new CanvasSurfaceState(
    currentSurface: edit.afterSurface,
    lastEdit: edit,
  )
```

This is not an undo stack.

This is not HistoryService.

This is not mutable state management.

This is not UI.

This is not cache execution.

## Required references

Before editing, read:

```txt id="x0iimf"
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
```

Also inspect:

```txt id="tjc6l0"
lib/src/models/bitmap_surface.dart
lib/src/models/bitmap_tile.dart
lib/src/models/brush_surface_edit.dart
lib/src/models/brush_commit_result.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/models/tile_delta_command.dart
lib/src/models/tile_delta.dart
lib/src/services/brush_surface_edit_builder.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
test/models/brush_surface_edit_test.dart
test/services/brush_surface_edit_builder_test.dart
test/services/brush_commit_result_apply_test.dart
test/services/brush_commit_result_revert_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add model:

```dart id="qkl5od"
class CanvasSurfaceState {
  CanvasSurfaceState({
    required this.currentSurface,
    this.lastEdit,
  });

  final BitmapSurface currentSurface;
  final BrushSurfaceEdit? lastEdit;

  bool get hasLastEdit;

  CanvasSurfaceState copyWith({
    BitmapSurface? currentSurface,
    Object? lastEdit,
  });

  CanvasSurfaceState clearLastEdit();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Add service:

```dart id="vww8xu"
CanvasSurfaceState applyBrushSurfaceEditToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushSurfaceEdit edit,
})
```

## Required production files

Create:

```txt id="8qnpod"
lib/src/models/canvas_surface_state.dart
lib/src/services/canvas_surface_state_edit.dart
```

## Required model behavior

### CanvasSurfaceState fields

```txt id="c4m54j"
currentSurface
lastEdit
```

`lastEdit` should be nullable.

Reason:

```txt id="go747k"
An initial canvas surface state may exist before any brush edit.
```

### hasLastEdit

```txt id="icw5rh"
hasLastEdit == lastEdit != null
```

### copyWith behavior

Because `lastEdit` is nullable, use a sentinel so callers can distinguish:

```txt id="lgxguz"
- omitted lastEdit: preserve existing lastEdit
- lastEdit: null: explicitly clear lastEdit
- lastEdit: edit: set lastEdit
```

Suggested signature:

```dart id="x683nr"
CanvasSurfaceState copyWith({
  BitmapSurface? currentSurface,
  Object? lastEdit = _copyWithSentinel,
})
```

### clearLastEdit behavior

```txt id="zjmgta"
clearLastEdit()
= copyWith(lastEdit: null)
```

### JSON behavior

Do not implement JSON in Phase 174.

Reason:

```txt id="r38ma9"
CanvasSurfaceState is transient runtime state.
It is not a project save format.
It is not a history storage format yet.
```

### Equality / hashCode / toString

Implement:

```txt id="ba9v81"
operator ==
hashCode
toString
```

Expected equality fields:

```txt id="m3pp3e"
currentSurface
lastEdit
```

## Required service behavior

The function:

```dart id="xbmb0q"
CanvasSurfaceState applyBrushSurfaceEditToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushSurfaceEdit edit,
})
```

should:

```txt id="kqvuj4"
1. Validate:
   edit.beforeSurface == state.currentSurface

2. If validation fails:
   throw StateError

3. If edit.isNoOp:
   return state

4. If edit.hasChanges:
   return CanvasSurfaceState(
     currentSurface: edit.afterSurface,
     lastEdit: edit,
   )
```

Important:

```txt id="3cf5q0"
No-op edit should preserve the same CanvasSurfaceState instance.
```

Reason:

```txt id="hyrrx7"
No effective brush edit should not replace current state or overwrite lastEdit.
```

### Stale edit behavior

If the edit was created from a different surface:

```txt id="e6lh4s"
edit.beforeSurface != state.currentSurface
```

Expected:

```txt id="cozplz"
throw StateError
```

Reason:

```txt id="m7cbb9"
Applying an edit to a different current surface would corrupt canvas state.
```

## Required tests

Create:

```txt id="c8c9fl"
test/models/canvas_surface_state_test.dart
test/services/canvas_surface_state_edit_test.dart
```

## Required model tests

```txt id="5ic1sx"
stores currentSurface and nullable lastEdit
initial state can have no lastEdit
hasLastEdit is false when lastEdit is null
hasLastEdit is true when lastEdit is non-null
copyWith preserves omitted values
copyWith updates currentSurface
copyWith can set lastEdit
copyWith can explicitly clear lastEdit with null
clearLastEdit clears lastEdit
equality compares currentSurface and lastEdit
hashCode matches equality
toString contains useful class name
```

## Required service tests

```txt id="c2r5hu"
returns same CanvasSurfaceState instance for no-op edit
no-op edit preserves existing lastEdit
applies changed BrushSurfaceEdit to currentSurface
changed edit sets currentSurface to edit.afterSurface
changed edit sets lastEdit to edit
changed edit preserves immutability of previous state
throws StateError for stale edit whose beforeSurface differs from state.currentSurface
does not mutate original BitmapSurface
does not mutate existing BitmapTile
does not mutate BrushSurfaceEdit
does not execute CacheInvalidationPlan
does not add undo stack behavior
```

## Suggested helpers

Avoid unnecessary `const` on model constructors unless the constructor is known to be const.

Suggested surface helper:

```dart id="i0g0e3"
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

```dart id="r2fh8w"
BitmapTile tile({
  required int tileX,
  required int tileY,
  int size = 2,
  int firstByte = 0,
}) {
  return BitmapTile(
    coord: TileCoord(x: tileX, y: tileY),
    size: size,
    pixels: Uint8List(size * size * BitmapTile.bytesPerPixel)..[0] = firstByte,
  );
}
```

Suggested command helper:

```dart id="tdhy4n"
TileDeltaCommand commandForCreatedTile(BitmapTile tile) {
  return TileDeltaCommand(
    deltas: [TileDelta.created(tile)],
  );
}
```

Suggested plan helper:

```dart id="w56yiy"
CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
  return CacheInvalidationPlan.fromTileDeltaCommand(
    layerId: LayerId('layer-a'),
    frameId: FrameId('frame-a'),
    command: command,
  );
}
```

Suggested commit result helper:

```dart id="o4txz2"
BrushCommitResult resultForCommand(TileDeltaCommand command) {
  return BrushCommitResult.changed(
    command: command,
    cacheInvalidationPlan: planForCommand(command),
  );
}
```

Suggested edit helper:

```dart id="crgoi5"
BrushSurfaceEdit changedEdit({
  required BitmapSurface beforeSurface,
  required BitmapSurface afterSurface,
  required BrushCommitResult commitResult,
}) {
  return BrushSurfaceEdit(
    beforeSurface: beforeSurface,
    afterSurface: afterSurface,
    commitResult: commitResult,
  );
}
```

## Suggested examples

### Initial state

```txt id="hpvk6f"
state = CanvasSurfaceState(currentSurface: surface)

expected:
state.currentSurface == surface
state.lastEdit == null
state.hasLastEdit == false
```

### No-op edit

```txt id="yh2sek"
state.currentSurface = surface
edit.beforeSurface = surface
edit.afterSurface = surface
edit.commitResult = BrushCommitResult.noOp()

updated = applyBrushSurfaceEditToCanvasSurfaceState(state, edit)

expected:
identical(updated, state) == true
updated.lastEdit remains whatever state.lastEdit was
```

### Changed edit

```txt id="fat6iq"
state.currentSurface = beforeSurface
edit.beforeSurface = beforeSurface
edit.afterSurface = afterSurface
edit.commitResult.hasChanges == true

updated = applyBrushSurfaceEditToCanvasSurfaceState(state, edit)

expected:
updated.currentSurface == afterSurface
updated.lastEdit == edit
state.currentSurface == beforeSurface
```

### Stale edit

```txt id="hlj4x5"
state.currentSurface = surfaceA
edit.beforeSurface = surfaceB

expected:
StateError
```

## Architecture rules

CanvasSurfaceState model rules:

```txt id="k3rygu"
canvas_surface_state.dart may know about BitmapSurface.
canvas_surface_state.dart may know about BrushSurfaceEdit.
canvas_surface_state.dart must not know about BrushDab.
canvas_surface_state.dart must not know about BrushDabSequence.
canvas_surface_state.dart must not know about LayerId.
canvas_surface_state.dart must not know about FrameId.
canvas_surface_state.dart must not know about Provider.
canvas_surface_state.dart must not know about Riverpod.
canvas_surface_state.dart must not know about ChangeNotifier.
canvas_surface_state.dart must not implement undo stack behavior.
canvas_surface_state.dart must not execute cache invalidation.
canvas_surface_state.dart must not add UI.
```

CanvasSurfaceState edit service rules:

```txt id="jjqszb"
canvas_surface_state_edit.dart may know about CanvasSurfaceState.
canvas_surface_state_edit.dart may know about BrushSurfaceEdit.
canvas_surface_state_edit.dart must not build BrushSurfaceEdit.
canvas_surface_state_edit.dart must not build BrushCommitResult.
canvas_surface_state_edit.dart must not manually apply TileDelta objects.
canvas_surface_state_edit.dart must not call surface.putTile directly.
canvas_surface_state_edit.dart must not call surface.removeTile directly.
canvas_surface_state_edit.dart must not execute cache invalidation.
canvas_surface_state_edit.dart must not implement UndoService.
canvas_surface_state_edit.dart must not add undo stack behavior.
canvas_surface_state_edit.dart must not add UI.
```

Bitmap/cache boundary:

```txt id="uihn89"
BitmapSurface is immutable data.
BrushSurfaceEdit bundles before surface, after surface, and commit result.
CanvasSurfaceState holds the current BitmapSurface and optionally the last edit.
CacheInvalidationPlan describes stale cache keys but is not executed in this phase.
Undo stack is not performed in this phase.
```

Timeline/storyboard boundary:

```txt id="gaaut4"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="msyopp"
BrushDabSequence -> CanvasSurfaceState commit service
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

```txt id="b7h9tr"
lib/src/models/canvas_surface_state.dart
lib/src/services/canvas_surface_state_edit.dart
test/models/canvas_surface_state_test.dart
test/services/canvas_surface_state_edit_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="dtt3qz"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="c2tgz3"
- changed files
- CanvasSurfaceState model behavior
- lastEdit nullable behavior
- copyWith behavior
- clearLastEdit behavior
- applyBrushSurfaceEditToCanvasSurfaceState behavior
- no-op edit behavior
- changed edit behavior
- stale edit error behavior
- original state immutability behavior
- original surface/tile immutability behavior
- confirmation that no BrushDabSequence -> CanvasSurfaceState commit service was added
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

Phase 174 is complete when:

```txt id="xc7w6g"
- canvas_surface_state.dart exists and is tested.
- canvas_surface_state_edit.dart exists and is tested.
- CanvasSurfaceState stores currentSurface and nullable lastEdit.
- Initial state can have no lastEdit.
- hasLastEdit works.
- copyWith preserves omitted values.
- copyWith can update currentSurface.
- copyWith can set lastEdit.
- copyWith can explicitly clear lastEdit with null.
- clearLastEdit clears lastEdit.
- equality/hashCode/toString work.
- applyBrushSurfaceEditToCanvasSurfaceState returns same state instance for no-op edit.
- no-op edit preserves existing lastEdit.
- changed edit updates currentSurface to edit.afterSurface.
- changed edit sets lastEdit to edit.
- changed edit does not mutate previous state.
- stale edit throws StateError.
- original BitmapSurface is not mutated.
- existing BitmapTile is not mutated.
- BrushSurfaceEdit is not mutated.
- CacheInvalidationPlan is not executed.
- No BrushDabSequence -> CanvasSurfaceState commit service was added.
- No Canvas UI integration was added.
- No UndoService / undo stack behavior was added.
- No Provider/Riverpod/Bloc/ChangeNotifier was added.
- Existing BrushSurfaceEdit tests still pass.
- Existing brush surface edit builder tests still pass.
- Existing brush commit result revert tests still pass.
- Existing brush commit result apply tests still pass.
- Existing BrushCommitResult tests still pass.
- Existing brush commit builder tests still pass.
- Existing brush commit cache invalidation tests still pass.
- Existing BitmapSurface brush commit tests still pass.
- Existing CacheInvalidationPlan tests still pass.
- Existing TileDeltaCommand tests still pass.
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

```txt id="ede759"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
