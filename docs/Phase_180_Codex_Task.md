# Phase 180 Codex Task

## Title

Create integrated brush edit session commit service

## Current position

```txt id="nc6acy"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit
```

## Brush work detailed roadmap

```txt id="o9997q"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - done
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit - current
1-11. Cache invalidation execution
1-12. Real Canvas UI integration
1-13. Brush work v1 complete
```

## Goal

Create a service that commits a `BrushDabSequence` to the current canvas surface and, if the edit changed pixels, pushes a history entry into `BrushEditHistoryState`.

This phase should combine existing services only.

It should not add UI.

It should not execute cache invalidation.

It should not add save/load.

## Required files

Create:

```txt id="z75nbk"
lib/src/models/brush_edit_session_commit_result.dart
lib/src/services/brush_edit_session_commit.dart
test/models/brush_edit_session_commit_result_test.dart
test/services/brush_edit_session_commit_test.dart
```

## Required model

Create:

```dart id="m2ce0y"
class BrushEditSessionCommitResult {
  BrushEditSessionCommitResult({
    required this.canvasState,
    required this.historyState,
    required this.historyEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? historyEntry;

  bool get didCommit;

  BrushEditSessionCommitResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? historyEntry,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

`historyEntry` is nullable.

```txt id="xly9xb"
No-op brush edit:
historyEntry == null
didCommit == false

Changed brush edit:
historyEntry != null
didCommit == true
```

Use a nullable sentinel in `copyWith` for `historyEntry`.

Do not add JSON.

## Required service

Create:

```dart id="kyx4v2"
BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSession({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

Behavior:

```txt id="i9zv7g"
1. Build a BrushSurfaceEdit by calling:

   brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
     surface: canvasState.currentSurface,
     sequence: sequence,
     layerId: layerId,
     frameId: frameId,
   )

2. Apply the edit to CanvasSurfaceState by calling:

   applyBrushSurfaceEditToCanvasSurfaceState(
     state: canvasState,
     edit: edit,
   )

3. Build a history entry by calling:

   brushEditHistoryEntryFromBrushSurfaceEdit(
     edit: edit,
     layerId: layerId,
     frameId: frameId,
   )

4. If historyEntry is null:
   return BrushEditSessionCommitResult(
     canvasState: updatedCanvasState,
     historyState: historyState,
     historyEntry: null,
   )

5. If historyEntry is non-null:
   push it by calling:

   pushBrushEditHistoryEntry(
     history: historyState,
     entry: historyEntry,
   )

6. Return BrushEditSessionCommitResult(
     canvasState: updatedCanvasState,
     historyState: updatedHistoryState,
     historyEntry: historyEntry,
   )
```

Important:

```txt id="a2c58s"
Do not manually create BrushCommitResult.
Do not manually create TileDeltaCommand.
Do not manually create CacheInvalidationPlan.
Do not manually apply TileDelta objects.
Do not call command.applyBefore or command.applyAfter.
Do not call surface.putTile or surface.removeTile directly.
Do not execute cache invalidation.
Do not execute undo or redo.
Do not add UI.
```

## Required tests

Model tests:

```txt id="kat8l2"
- stores canvasState, historyState, historyEntry
- didCommit false when historyEntry is null
- didCommit true when historyEntry is non-null
- copyWith preserves omitted values
- copyWith updates canvasState
- copyWith updates historyState
- copyWith can set historyEntry
- copyWith can clear historyEntry with null
- equality / hashCode / toString
```

Service tests:

```txt id="lyowb0"
- empty BrushDabSequence returns no commit result
- no-op edit does not push history entry
- no-op edit preserves existing historyState instance
- changed edit updates CanvasSurfaceState.currentSurface
- changed edit sets CanvasSurfaceState.lastEdit
- changed edit creates historyEntry
- changed edit pushes historyEntry into undoEntries
- changed edit clears redoEntries
- historyEntry uses provided LayerId
- historyEntry uses provided FrameId
- result matches manual composition of existing services
- changed edit can be undone with existing undoLatestBrushEdit
- changed edit can be redone with existing redoLatestBrushEdit after undo
- does not mutate input CanvasSurfaceState
- does not mutate input BrushEditHistoryState
- does not mutate BrushDabSequence or BrushDab
- does not execute cache invalidation
- does not add UI/state management/timeline/storyboard changes
```

## Required references

Read before editing:

```txt id="qoa9n5"
docs/Phase_175_Codex_Task.md
docs/Phase_176_Codex_Task.md
docs/Phase_177_Codex_Task.md
docs/Phase_178_Codex_Task.md
docs/Phase_179_Codex_Task.md
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_edit_history_state.dart
lib/src/models/brush_edit_history_entry.dart
lib/src/models/brush_dab_sequence.dart
lib/src/models/layer_id.dart
lib/src/models/frame_id.dart
lib/src/services/brush_surface_edit_builder.dart
lib/src/services/canvas_surface_state_edit.dart
lib/src/services/brush_edit_history_entry_builder.dart
lib/src/services/brush_edit_history_stack.dart
lib/src/services/brush_edit_undo_service.dart
lib/src/services/brush_edit_redo_service.dart
```

## Out of scope

Do not add:

```txt id="a9pthz"
Canvas UI
Pointer input
Brush tool widget
HistoryService
Provider / Riverpod / Bloc / ChangeNotifier
Cache invalidation execution
Cache storage
Save / load
Timeline changes
Storyboard changes
```

## Required checks

Run:

```bash id="yigz53"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase is model/service-only.

If the app is run, only confirm:

```txt id="k6ncs3"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```

## Report back

Report:

```txt id="wkvowr"
- changed files
- session commit result model behavior
- integrated commit service behavior
- no-op behavior
- changed edit behavior
- history push behavior
- redo clear behavior
- undo/redo compatibility behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
