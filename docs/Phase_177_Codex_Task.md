# Phase 177 Codex Task

## Title

Create BrushEditHistoryState model and history stack foundation services

## Repository

```txt id="x2r6h5"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="z3zfwn"
master
```

## Project type

```txt id="d8ybd5"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 176.

Recent bitmap canvas / brush foundation phases:

```txt id="zvg0bd"
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
Phase 175: BrushDabSequence + CanvasSurfaceState + LayerId + FrameId -> CanvasSurfaceState
Phase 176: BrushEditHistoryEntry model and builder service
```

## Existing pieces

Phase 176 introduced:

```txt id="f1vqbu"
BrushEditHistoryEntry
= LayerId
+ FrameId
+ BrushCommitResult
```

A `BrushEditHistoryEntry` is a lightweight runtime undo/redo preparation unit.

It does not store full `BitmapSurface`.

It stores only enough information to later apply/revert a brush edit:

```txt id="m7bxpx"
entry.commitResult.command.applyAfter(surface)
entry.commitResult.command.applyBefore(surface)
```

The next step is to create a history state that can hold undo and redo entries.

## Important concept

Phase 177 is still not actual undo execution.

This phase should only create:

```txt id="yhrhn9"
BrushEditHistoryState
= undoEntries
+ redoEntries
```

and pure services such as:

```txt id="iew9cy"
pushBrushEditHistoryEntry(...)
clearBrushEditHistoryState(...)
```

Actual undo/redo execution will come later.

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="g8uwwt"
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
22. BrushEditHistoryEntry model and builder
23. BrushEditHistoryState model and push/clear foundation
24. Undo execution service
25. Redo execution service
26. Cache invalidation execution
27. Canvas UI integration
28. Save/load/export
```

Current local roadmap:

```txt id="gbeb19"
Phase 175: BrushDabSequence + CanvasSurfaceState + LayerId + FrameId -> CanvasSurfaceState
Phase 176: BrushEditHistoryEntry model and builder service
Phase 177: BrushEditHistoryState model and push/clear foundation
Phase 178: Undo execution service
Phase 179: Redo execution service
```

Phase 177 is model + service only.

It must not execute undo.

It must not execute redo.

It must not mutate `BitmapSurface`.

It must not execute cache invalidation.

It must not add canvas UI.

It must not introduce Provider, Riverpod, Bloc, ChangeNotifier, or any state management package.

## What structure this phase should create

Future undo flow will eventually look like this:

```txt id="x3ai4e"
BrushSurfaceEdit
-> BrushEditHistoryEntry
-> pushBrushEditHistoryEntry(...)
-> BrushEditHistoryState.undoEntries
```

Future undo execution will later:

```txt id="cxjtwf"
pop undo entry
apply entry.command.applyBefore(...)
push entry to redoEntries
```

But Phase 177 should not do that yet.

This phase should only implement the safe history container.

## Required references

Before editing, read:

```txt id="z7l4q3"
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
docs/Phase_175_Codex_Task.md
docs/Phase_176_Codex_Task.md
```

Also inspect:

```txt id="nq7pkk"
lib/src/models/brush_edit_history_entry.dart
lib/src/models/brush_commit_result.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/tile_delta_command.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/services/brush_edit_history_entry_builder.dart
test/models/brush_edit_history_entry_test.dart
test/services/brush_edit_history_entry_builder_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add model:

```dart id="wv0jm0"
class BrushEditHistoryState {
  BrushEditHistoryState({
    Iterable<BrushEditHistoryEntry> undoEntries = const [],
    Iterable<BrushEditHistoryEntry> redoEntries = const [],
  });

  List<BrushEditHistoryEntry> get undoEntries;
  List<BrushEditHistoryEntry> get redoEntries;

  bool get canUndo;
  bool get canRedo;
  bool get isEmpty;
  int get undoCount;
  int get redoCount;

  BrushEditHistoryEntry? get latestUndoEntry;
  BrushEditHistoryEntry? get latestRedoEntry;

  BrushEditHistoryState copyWith({
    Iterable<BrushEditHistoryEntry>? undoEntries,
    Iterable<BrushEditHistoryEntry>? redoEntries,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Add service:

```dart id="v7cn83"
BrushEditHistoryState pushBrushEditHistoryEntry({
  required BrushEditHistoryState history,
  required BrushEditHistoryEntry entry,
})
```

Add service:

```dart id="oy8jhh"
BrushEditHistoryState clearBrushEditHistoryState({
  required BrushEditHistoryState history,
})
```

Optional additional service:

```dart id="z0i589"
BrushEditHistoryState clearRedoEntries({
  required BrushEditHistoryState history,
})
```

## Required production files

Create:

```txt id="fqut4j"
lib/src/models/brush_edit_history_state.dart
lib/src/services/brush_edit_history_stack.dart
```

## Required model behavior

### BrushEditHistoryState fields

```txt id="lw3yp0"
undoEntries
redoEntries
```

These should be stored immutably.

Do not expose mutable internal lists.

Expected:

```txt id="gcrolo"
state.undoEntries.add(...) should not be possible.
```

Use defensive copies and unmodifiable lists.

### canUndo

```txt id="c8mcu1"
canUndo == undoEntries.isNotEmpty
```

### canRedo

```txt id="r7brsq"
canRedo == redoEntries.isNotEmpty
```

### isEmpty

```txt id="zrbyi1"
isEmpty == undoEntries.isEmpty && redoEntries.isEmpty
```

### undoCount

```txt id="ztmuxq"
undoCount == undoEntries.length
```

### redoCount

```txt id="qz22rh"
redoCount == redoEntries.length
```

### latestUndoEntry

```txt id="lnj5vo"
latestUndoEntry == undoEntries.isEmpty ? null : undoEntries.last
```

### latestRedoEntry

```txt id="u4sd2o"
latestRedoEntry == redoEntries.isEmpty ? null : redoEntries.last
```

### copyWith

`copyWith` should preserve omitted values.

Expected:

```txt id="g1mtfs"
copyWith() == original
copyWith(undoEntries: [...]) updates undoEntries
copyWith(redoEntries: [...]) updates redoEntries
```

No nullable sentinel is needed because `undoEntries` and `redoEntries` are non-null collections.

### JSON behavior

Do not implement JSON in Phase 177.

Reason:

```txt id="pv9qye"
BrushEditHistoryState is runtime undo/redo state.
History persistence can be designed later.
```

### Equality / hashCode / toString

Implement:

```txt id="f09ujy"
operator ==
hashCode
toString
```

Expected equality fields:

```txt id="xn1hgt"
undoEntries
redoEntries
```

For list equality, do not rely on default `List ==`.

Use element-wise equality.

## Required service behavior

### pushBrushEditHistoryEntry

```dart id="sl8nkr"
BrushEditHistoryState pushBrushEditHistoryEntry({
  required BrushEditHistoryState history,
  required BrushEditHistoryEntry entry,
})
```

Expected behavior:

```txt id="mud61p"
1. Append entry to undoEntries.
2. Clear redoEntries.
3. Return a new BrushEditHistoryState.
4. Do not mutate the input history.
```

Reason:

```txt id="lu31fz"
After a new brush edit, the redo stack must be cleared.
```

### clearBrushEditHistoryState

```dart id="gkjfnx"
BrushEditHistoryState clearBrushEditHistoryState({
  required BrushEditHistoryState history,
})
```

Expected behavior:

```txt id="hwkupf"
return an empty BrushEditHistoryState
```

Input history must not be mutated.

### clearRedoEntries

```dart id="fv23l2"
BrushEditHistoryState clearRedoEntries({
  required BrushEditHistoryState history,
})
```

Expected behavior:

```txt id="x9fh75"
return history.copyWith(redoEntries: const [])
```

Input history must not be mutated.

## Required tests

Create:

```txt id="lcplkf"
test/models/brush_edit_history_state_test.dart
test/services/brush_edit_history_stack_test.dart
```

## Required model tests

```txt id="bnj13e"
initial state has empty undoEntries and redoEntries
stores undoEntries and redoEntries
defensively copies constructor lists
exposes unmodifiable undoEntries
exposes unmodifiable redoEntries
canUndo is false when undoEntries is empty
canUndo is true when undoEntries is non-empty
canRedo is false when redoEntries is empty
canRedo is true when redoEntries is non-empty
isEmpty is true only when both stacks are empty
undoCount returns undoEntries length
redoCount returns redoEntries length
latestUndoEntry returns null when undoEntries is empty
latestUndoEntry returns last undo entry
latestRedoEntry returns null when redoEntries is empty
latestRedoEntry returns last redo entry
copyWith preserves omitted values
copyWith updates undoEntries
copyWith updates redoEntries
equality uses element-wise list equality
hashCode matches equality
toString contains useful class name
does not store BitmapSurface
```

## Required service tests

```txt id="x3f95b"
pushBrushEditHistoryEntry appends entry to undoEntries
pushBrushEditHistoryEntry clears redoEntries
pushBrushEditHistoryEntry returns new state
pushBrushEditHistoryEntry does not mutate input history
pushBrushEditHistoryEntry preserves existing undo order
pushBrushEditHistoryEntry puts new entry at latestUndoEntry
clearBrushEditHistoryState clears undoEntries and redoEntries
clearBrushEditHistoryState returns new empty state
clearBrushEditHistoryState does not mutate input history
clearRedoEntries clears only redoEntries
clearRedoEntries preserves undoEntries
clearRedoEntries does not mutate input history
services do not execute undo
services do not execute redo
services do not execute CacheInvalidationPlan
services do not mutate BrushEditHistoryEntry
services do not add canvas UI behavior
```

## Suggested helpers

Avoid unnecessary `const` on model constructors unless the constructor is known to be const.

Suggested IDs:

```dart id="es64wz"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested tile helper:

```dart id="w3xlcu"
BitmapTile tile({
  required int tileX,
  required int tileY,
  int size = 2,
}) {
  return BitmapTile.blank(
    coord: TileCoord(x: tileX, y: tileY),
    size: size,
  );
}
```

Suggested command helper:

```dart id="sxe6r1"
TileDeltaCommand commandForTile(BitmapTile tile) {
  return TileDeltaCommand(
    deltas: [TileDelta.created(tile)],
  );
}
```

Suggested result helper:

```dart id="jn9oyj"
BrushCommitResult resultForTile(BitmapTile tile) {
  final command = commandForTile(tile);
  return BrushCommitResult.changed(
    command: command,
    cacheInvalidationPlan: CacheInvalidationPlan.fromTileDeltaCommand(
      layerId: layerId,
      frameId: frameId,
      command: command,
    ),
  );
}
```

Suggested entry helper:

```dart id="ejt7mr"
BrushEditHistoryEntry entry({
  int tileX = 0,
  int tileY = 0,
  LayerId entryLayerId = layerId,
  FrameId entryFrameId = frameId,
}) {
  return BrushEditHistoryEntry(
    layerId: entryLayerId,
    frameId: entryFrameId,
    commitResult: resultForTile(tile(tileX: tileX, tileY: tileY)),
  );
}
```

## Suggested examples

### Empty state

```txt id="n20aqy"
history = BrushEditHistoryState()

expected:
history.undoEntries.isEmpty
history.redoEntries.isEmpty
history.canUndo == false
history.canRedo == false
history.isEmpty == true
```

### Push entry

```txt id="tv9r4z"
history = BrushEditHistoryState()
entry = BrushEditHistoryEntry(...)

next = pushBrushEditHistoryEntry(history: history, entry: entry)

expected:
next.undoEntries == [entry]
next.redoEntries == []
next.latestUndoEntry == entry
history.undoEntries == []
```

### Push clears redo

```txt id="daghml"
history = BrushEditHistoryState(
  undoEntries: [entryA],
  redoEntries: [entryB],
)

next = pushBrushEditHistoryEntry(history: history, entry: entryC)

expected:
next.undoEntries == [entryA, entryC]
next.redoEntries == []
```

### Clear history

```txt id="y1hybp"
history = BrushEditHistoryState(
  undoEntries: [entryA],
  redoEntries: [entryB],
)

next = clearBrushEditHistoryState(history: history)

expected:
next.isEmpty == true
history.isEmpty == false
```

## Architecture rules

BrushEditHistoryState model rules:

```txt id="vp91iq"
brush_edit_history_state.dart may know about BrushEditHistoryEntry.
brush_edit_history_state.dart must not know about BitmapSurface.
brush_edit_history_state.dart must not know about BrushSurfaceEdit.
brush_edit_history_state.dart must not know about CanvasSurfaceState.
brush_edit_history_state.dart must not know about BrushDab.
brush_edit_history_state.dart must not know about BrushDabSequence.
brush_edit_history_state.dart must not execute undo.
brush_edit_history_state.dart must not execute redo.
brush_edit_history_state.dart must not execute cache invalidation.
brush_edit_history_state.dart must not add UI.
```

BrushEditHistoryStack service rules:

```txt id="e8bikm"
brush_edit_history_stack.dart may know about BrushEditHistoryState.
brush_edit_history_stack.dart may know about BrushEditHistoryEntry.
brush_edit_history_stack.dart must not know about BitmapSurface.
brush_edit_history_stack.dart must not know about CanvasSurfaceState.
brush_edit_history_stack.dart must not manually apply TileDelta objects.
brush_edit_history_stack.dart must not call surface.putTile directly.
brush_edit_history_stack.dart must not call surface.removeTile directly.
brush_edit_history_stack.dart must not execute undo.
brush_edit_history_stack.dart must not execute redo.
brush_edit_history_stack.dart must not execute cache invalidation.
brush_edit_history_stack.dart must not add UI.
```

Bitmap/cache/history boundary:

```txt id="k5c71a"
BrushEditHistoryEntry stores one undoable brush edit command.
BrushEditHistoryState stores undoEntries and redoEntries.
Phase 177 only pushes and clears entries.
Phase 177 does not apply command.applyBefore or command.applyAfter.
CacheInvalidationPlan describes stale cache keys but is not executed in this phase.
```

Timeline/storyboard boundary:

```txt id="cbb0r3"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="u4wdgd"
Undo execution
Redo execution
UndoService that mutates CanvasSurfaceState
RedoService that mutates CanvasSurfaceState
HistoryService
Canvas UI integration
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

```txt id="cslaml"
lib/src/models/brush_edit_history_state.dart
lib/src/services/brush_edit_history_stack.dart
test/models/brush_edit_history_state_test.dart
test/services/brush_edit_history_stack_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="p3xsmf"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="v8x1iw"
- changed files
- BrushEditHistoryState model behavior
- undoEntries/redoEntries immutability behavior
- canUndo/canRedo/isEmpty/count/latestEntry behavior
- copyWith behavior
- pushBrushEditHistoryEntry behavior
- clearBrushEditHistoryState behavior
- clearRedoEntries behavior
- confirmation that no BitmapSurface is stored
- confirmation that no undo execution was added
- confirmation that no redo execution was added
- confirmation that no command.applyBefore/applyAfter was called
- confirmation that no CacheInvalidationPlan execution was added
- confirmation that no Canvas UI integration was added
- confirmation that no Provider/Riverpod/Bloc/ChangeNotifier was added
- confirmation that no timeline/storyboard semantics were changed
- analyze result
- test result
- git status summary
```

## Acceptance criteria

Phase 177 is complete when:

```txt id="h5kage"
- brush_edit_history_state.dart exists and is tested.
- brush_edit_history_stack.dart exists and is tested.
- BrushEditHistoryState stores undoEntries and redoEntries.
- Constructor defensively copies input lists.
- Exposed undoEntries and redoEntries are unmodifiable.
- canUndo/canRedo/isEmpty/undoCount/redoCount work.
- latestUndoEntry/latestRedoEntry work.
- copyWith works.
- equality uses element-wise list equality.
- hashCode/toString work.
- BrushEditHistoryState does not store BitmapSurface.
- pushBrushEditHistoryEntry appends entry to undoEntries.
- pushBrushEditHistoryEntry clears redoEntries.
- pushBrushEditHistoryEntry preserves undo order.
- pushBrushEditHistoryEntry does not mutate input history.
- clearBrushEditHistoryState clears both stacks.
- clearBrushEditHistoryState does not mutate input history.
- clearRedoEntries clears only redoEntries.
- clearRedoEntries preserves undoEntries.
- clearRedoEntries does not mutate input history.
- Services do not execute undo.
- Services do not execute redo.
- Services do not call command.applyBefore/applyAfter.
- Services do not execute CacheInvalidationPlan.
- No Canvas UI integration was added.
- No Provider/Riverpod/Bloc/ChangeNotifier was added.
- Existing BrushEditHistoryEntry tests still pass.
- Existing BrushEditHistoryEntry builder tests still pass.
- Existing CanvasSurfaceState brush commit tests still pass.
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

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm changed-risk areas:

```txt id="k24nv0"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
