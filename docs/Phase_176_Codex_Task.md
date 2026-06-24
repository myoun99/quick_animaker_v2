# Phase 176 Codex Task

## Title

Create BrushEditHistoryEntry model and builder service

## Repository

```txt id="tzx013"
myoun99/quick_animaker_v2
```

## Base branch

```txt id="h952mt"
master
```

## Project type

```txt id="byu8co"
Flutter / Dart
```

## Current status

QuickAnimaker v2 is complete through Phase 175.

Recent bitmap canvas / brush foundation phases:

```txt id="r05l5h"
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
```

## Existing pieces

Phase 173 introduced:

```txt id="i8wvii"
BrushSurfaceEdit
= beforeSurface
+ afterSurface
+ commitResult
```

Phase 174 introduced:

```txt id="w91d1g"
CanvasSurfaceState
= currentSurface
+ lastEdit?
```

Phase 175 introduced:

```txt id="zpcbzr"
CanvasSurfaceState
+ BrushDabSequence
+ LayerId
+ FrameId
-> CanvasSurfaceState
```

The next step is to create a lightweight history entry that future undo/redo stacks can store.

## Important concept

`BrushSurfaceEdit` carries full before/after surfaces.

That is useful during one edit operation, but it is too heavy to become the normal undo stack unit.

`BrushEditHistoryEntry` should store only:

```txt id="rjwsc1"
LayerId
FrameId
BrushCommitResult
```

Reason:

```txt id="fcw7zu"
BrushCommitResult already contains TileDeltaCommand.
TileDeltaCommand can applyAfter/applyBefore on a BitmapSurface.
Therefore undo/redo can be driven by the command, without storing full before/after surfaces in every history entry.
```

## Long-term roadmap

QuickAnimaker v2 is moving toward a bitmap-first brush engine.

High-level roadmap:

```txt id="xwv8fz"
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
23. UndoStack / RedoStack foundation
24. Cache invalidation execution
25. Canvas UI integration
26. Save/load/export
```

Current local roadmap:

```txt id="qqdczh"
Phase 173: BrushSurfaceEdit model and builder service
Phase 174: CanvasSurfaceState model and BrushSurfaceEdit apply service
Phase 175: BrushDabSequence + CanvasSurfaceState + LayerId + FrameId -> CanvasSurfaceState
Phase 176: BrushEditHistoryEntry model and builder service
Phase 177: UndoStack / RedoStack foundation
```

Phase 176 is model + service only.

It must not add an undo stack.

It must not add a redo stack.

It must not execute cache invalidation.

It must not add canvas UI.

It must not introduce Provider, Riverpod, Bloc, ChangeNotifier, or any state management package.

## What structure this phase should create

Future undo integration will eventually look like this:

```txt id="g4k14m"
CanvasSurfaceState commit result
-> last BrushSurfaceEdit
-> BrushEditHistoryEntry
-> push into future UndoStack
```

This phase only creates:

```txt id="zu7mkg"
BrushEditHistoryEntry model
BrushEditHistoryEntry builder service
```

Meaning:

```txt id="zbz9d1"
BrushSurfaceEdit + LayerId + FrameId
-> BrushEditHistoryEntry?
```

No-op edits should not create history entries.

Changed edits should create history entries.

## Required references

Before editing, read:

```txt id="qxwe95"
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
```

Also inspect:

```txt id="r1z993"
lib/src/models/brush_surface_edit.dart
lib/src/models/brush_commit_result.dart
lib/src/models/canvas_surface_state.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/models/tile_delta_command.dart
lib/src/models/cache_invalidation_plan.dart
lib/src/models/dirty_tile_set.dart
lib/src/services/canvas_surface_state_brush_commit.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
test/models/brush_surface_edit_test.dart
test/models/brush_commit_result_test.dart
test/models/canvas_surface_state_test.dart
test/services/canvas_surface_state_brush_commit_test.dart
```

Do not modify timeline or storyboard behavior.

## Goal

Add model:

```dart id="cdp3xt"
class BrushEditHistoryEntry {
  BrushEditHistoryEntry({
    required this.layerId,
    required this.frameId,
    required this.commitResult,
  });

  final LayerId layerId;
  final FrameId frameId;
  final BrushCommitResult commitResult;

  TileDeltaCommand get command;
  CacheInvalidationPlan get cacheInvalidationPlan;
  DirtyTileSet get dirtyTiles;
  int get changedTileCount;

  BrushEditHistoryEntry copyWith({
    LayerId? layerId,
    FrameId? frameId,
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

```dart id="tq7h5j"
BrushEditHistoryEntry? brushEditHistoryEntryFromBrushSurfaceEdit({
  required BrushSurfaceEdit edit,
  required LayerId layerId,
  required FrameId frameId,
})
```

## Required production files

Create:

```txt id="wp8rb8"
lib/src/models/brush_edit_history_entry.dart
lib/src/services/brush_edit_history_entry_builder.dart
```

## Required model behavior

### BrushEditHistoryEntry fields

```txt id="ol5j18"
layerId
frameId
commitResult
```

### Constructor validation

Reject no-op commit results.

Expected:

```txt id="b0n1fv"
if commitResult.isNoOp:
  throw ArgumentError
```

Reason:

```txt id="k9kakg"
Undo/redo history should not contain no-op brush edits.
No-op edits do not need history entries.
```

Do not validate by applying the command to a surface.

Reason:

```txt id="40t8hi"
BrushEditHistoryEntry should be lightweight.
It should not know the current surface.
It should not perform bitmap mutation or validation.
```

### command getter

```txt id="lj6h07"
command == commitResult.command!
```

Because constructor rejects no-op, `commitResult.command` must be non-null.

### cacheInvalidationPlan getter

```txt id="06fe90"
cacheInvalidationPlan == commitResult.cacheInvalidationPlan
```

### dirtyTiles getter

```txt id="e965su"
dirtyTiles == command.dirtyTiles
```

### changedTileCount getter

```txt id="zxfzuu"
changedTileCount == command.length
```

### copyWith behavior

All fields are non-null.

No nullable sentinel is needed.

Expected:

```txt id="zzd9lm"
copyWith() == original
copyWith(layerId: otherLayerId) updates layerId
copyWith(frameId: otherFrameId) updates frameId
copyWith(commitResult: otherCommitResult) updates commitResult
```

### JSON behavior

Do not implement JSON in Phase 176.

Reason:

```txt id="xsf2ko"
BrushEditHistoryEntry is a runtime undo/redo preparation model.
It is not a project save format yet.
History persistence can be designed later.
```

### Equality / hashCode / toString

Implement:

```txt id="ra4g1n"
operator ==
hashCode
toString
```

Expected equality fields:

```txt id="gu7ke7"
layerId
frameId
commitResult
```

## Required builder service behavior

The function:

```dart id="ouh9ph"
BrushEditHistoryEntry? brushEditHistoryEntryFromBrushSurfaceEdit({
  required BrushSurfaceEdit edit,
  required LayerId layerId,
  required FrameId frameId,
})
```

should:

```txt id="vn2fg8"
1. If edit.isNoOp:
   return null

2. If edit.hasChanges:
   return BrushEditHistoryEntry(
     layerId: layerId,
     frameId: frameId,
     commitResult: edit.commitResult,
   )
```

Important:

```txt id="jq8h95"
Do not inspect edit.beforeSurface.
Do not inspect edit.afterSurface.
Do not apply the command.
Do not revert the command.
Do not execute cache invalidation.
Do not push into an undo stack.
```

Reason:

```txt id="jpw518"
BrushSurfaceEdit already represents the completed edit.
BrushEditHistoryEntry should only extract the lightweight undoable record from it.
```

## Required tests

Create:

```txt id="bs4zfc"
test/models/brush_edit_history_entry_test.dart
test/services/brush_edit_history_entry_builder_test.dart
```

## Required model tests

```txt id="zu1qc2"
stores layerId, frameId, and commitResult
rejects no-op commitResult
command getter returns commitResult.command
cacheInvalidationPlan getter returns commitResult.cacheInvalidationPlan
dirtyTiles getter returns command.dirtyTiles
changedTileCount getter returns command.length
copyWith preserves omitted values
copyWith updates layerId
copyWith updates frameId
copyWith updates commitResult
equality compares layerId, frameId, and commitResult
hashCode matches equality
toString contains useful class name
does not contain beforeSurface or afterSurface fields
```

## Required builder tests

```txt id="hno0ub"
returns null for no-op BrushSurfaceEdit
returns BrushEditHistoryEntry for changed BrushSurfaceEdit
entry uses provided LayerId
entry uses provided FrameId
entry commitResult equals edit.commitResult
entry command equals edit.commitResult.command
entry dirtyTiles equals edit.commitResult.dirtyTiles
entry changedTileCount equals edit.commitResult.changedTileCount
entry can revert applied surface using commitResult through existing revert service
does not mutate BrushSurfaceEdit
does not mutate BrushCommitResult
does not mutate beforeSurface
does not mutate afterSurface
does not execute CacheInvalidationPlan
does not add undo stack behavior
```

## Suggested helpers

Avoid unnecessary `const` on model constructors unless the constructor is known to be const.

Suggested IDs:

```dart id="z92m6y"
const layerId = LayerId('layer-a');
const frameId = FrameId('frame-a');
```

Suggested surface helper:

```dart id="pbkim2"
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

```dart id="ev7s4h"
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

Suggested changed edit helper:

```dart id="yl5fwi"
BrushSurfaceEdit changedEdit({
  required BitmapSurface surface,
}) {
  return brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
    layerId: layerId,
    frameId: frameId,
  );
}
```

Suggested no-op edit helper:

```dart id="g3i7p9"
BrushSurfaceEdit noOpEdit({
  required BitmapSurface surface,
}) {
  return brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: BrushDabSequence(),
    layerId: layerId,
    frameId: frameId,
  );
}
```

## Suggested examples

### No-op edit

```txt id="ej96df"
edit = BrushSurfaceEdit(
  beforeSurface: surface,
  afterSurface: surface,
  commitResult: BrushCommitResult.noOp(),
)

entry = brushEditHistoryEntryFromBrushSurfaceEdit(...)

expected:
entry == null
```

### Changed edit

```txt id="t6p5qk"
edit.hasChanges == true

entry = brushEditHistoryEntryFromBrushSurfaceEdit(
  edit: edit,
  layerId: layerId,
  frameId: frameId,
)

expected:
entry != null
entry.layerId == layerId
entry.frameId == frameId
entry.commitResult == edit.commitResult
entry.command == edit.commitResult.command
```

### Revert with entry

```txt id="c1g9rd"
revertedSurface = revertBrushCommitResultOnBitmapSurface(
  surface: edit.afterSurface,
  result: entry.commitResult,
)

expected:
revertedSurface == edit.beforeSurface
```

## Architecture rules

BrushEditHistoryEntry model rules:

```txt id="mqoa5x"
brush_edit_history_entry.dart may know about LayerId.
brush_edit_history_entry.dart may know about FrameId.
brush_edit_history_entry.dart may know about BrushCommitResult.
brush_edit_history_entry.dart may know about TileDeltaCommand.
brush_edit_history_entry.dart may know about CacheInvalidationPlan.
brush_edit_history_entry.dart may know about DirtyTileSet.
brush_edit_history_entry.dart must not know about BitmapSurface.
brush_edit_history_entry.dart must not know about BrushSurfaceEdit.
brush_edit_history_entry.dart must not know about BrushDab.
brush_edit_history_entry.dart must not know about BrushDabSequence.
brush_edit_history_entry.dart must not execute cache invalidation.
brush_edit_history_entry.dart must not implement UndoStack.
brush_edit_history_entry.dart must not add UI.
```

BrushEditHistoryEntry builder rules:

```txt id="jeh235"
brush_edit_history_entry_builder.dart may know about BrushSurfaceEdit.
brush_edit_history_entry_builder.dart may know about BrushEditHistoryEntry.
brush_edit_history_entry_builder.dart may know about LayerId.
brush_edit_history_entry_builder.dart may know about FrameId.
brush_edit_history_entry_builder.dart must not manually create BrushCommitResult.
brush_edit_history_entry_builder.dart must not manually create TileDeltaCommand.
brush_edit_history_entry_builder.dart must not manually create CacheInvalidationPlan.
brush_edit_history_entry_builder.dart must not manually apply TileDelta objects.
brush_edit_history_entry_builder.dart must not call surface.putTile directly.
brush_edit_history_entry_builder.dart must not call surface.removeTile directly.
brush_edit_history_entry_builder.dart must not execute cache invalidation.
brush_edit_history_entry_builder.dart must not implement UndoStack.
brush_edit_history_entry_builder.dart must not add UI.
```

Bitmap/cache/history boundary:

```txt id="ey3exg"
BrushSurfaceEdit bundles before surface, after surface, and commit result.
BrushEditHistoryEntry stores only LayerId, FrameId, and BrushCommitResult.
BrushEditHistoryEntry does not store BitmapSurface.
CacheInvalidationPlan describes stale cache keys but is not executed in this phase.
Undo stack is not performed in this phase.
```

Timeline/storyboard boundary:

```txt id="ejx1lu"
Do not modify TimelinePanel.
Do not modify LayerTimelineGrid.
Do not modify TimelineController.
Do not modify StoryboardPanel.
Do not modify timeline range semantics.
Do not modify storyboard layer semantics.
```

## Out of scope

Do not add:

```txt id="dj8g9c"
UndoService
UndoStack
RedoStack
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

```txt id="kh3ym9"
lib/src/models/brush_edit_history_entry.dart
lib/src/services/brush_edit_history_entry_builder.dart
test/models/brush_edit_history_entry_test.dart
test/services/brush_edit_history_entry_builder_test.dart
```

Avoid touching unrelated files.

## Required checks

Run:

```bash id="e5g3gq"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable in the environment, report that clearly.

## Required report back

After implementation, report:

```txt id="g4u8dy"
- changed files
- BrushEditHistoryEntry model behavior
- constructor validation behavior
- command/cacheInvalidationPlan/dirtyTiles/changedTileCount getter behavior
- copyWith behavior
- builder no-op behavior
- builder changed behavior
- revert-with-entry behavior
- immutability behavior
- confirmation that BrushEditHistoryEntry does not store BitmapSurface
- confirmation that no UndoStack/RedoStack/HistoryService was added
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

Phase 176 is complete when:

```txt id="a8pzt3"
- brush_edit_history_entry.dart exists and is tested.
- brush_edit_history_entry_builder.dart exists and is tested.
- BrushEditHistoryEntry stores layerId, frameId, and commitResult.
- BrushEditHistoryEntry rejects no-op commitResult.
- command getter returns commitResult.command.
- cacheInvalidationPlan getter returns commitResult.cacheInvalidationPlan.
- dirtyTiles getter returns command.dirtyTiles.
- changedTileCount getter returns command.length.
- copyWith works.
- equality/hashCode/toString work.
- BrushEditHistoryEntry does not store BitmapSurface.
- Builder returns null for no-op BrushSurfaceEdit.
- Builder returns entry for changed BrushSurfaceEdit.
- Builder entry uses provided LayerId.
- Builder entry uses provided FrameId.
- Builder entry commitResult equals edit.commitResult.
- Entry can revert edit.afterSurface back to edit.beforeSurface using existing revert service.
- BrushSurfaceEdit is not mutated.
- BrushCommitResult is not mutated.
- beforeSurface is not mutated.
- afterSurface is not mutated.
- CacheInvalidationPlan is not executed.
- No UndoStack / RedoStack / HistoryService was added.
- No Provider/Riverpod/Bloc/ChangeNotifier was added.
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

```txt id="es9rqc"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```
