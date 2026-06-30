# Phase 179 Codex Task

## Title

Create brush edit redo execution service

## Current position

```txt id="uz2h7w"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-9. Redo execution service
```

## Brush work detailed roadmap

```txt id="g82g07"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - current
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit
1-11. Cache invalidation execution
1-12. Real Canvas UI integration
1-13. Brush work v1 complete
```

## Goal

Add redo execution for brush edits.

This phase should take:

```txt id="qx8c99"
CanvasSurfaceState
BrushEditHistoryState
```

and redo the latest redo entry if possible.

It should:

```txt id="zdqzms"
- re-apply currentSurface using the latest redo entry
- move that entry from redoEntries to undoEntries
- set CanvasSurfaceState.lastEdit to a reconstructed BrushSurfaceEdit
```

This is still service/model only.

Do not add UI.

Do not execute cache invalidation yet.

Do not add save/load.

## Required files

Create:

```txt id="trxwga"
lib/src/models/brush_edit_redo_result.dart
lib/src/services/brush_edit_redo_service.dart
test/models/brush_edit_redo_result_test.dart
test/services/brush_edit_redo_service_test.dart
```

## Required model

Create:

```dart id="nn7lbo"
class BrushEditRedoResult {
  BrushEditRedoResult({
    required this.canvasState,
    required this.historyState,
    required this.redoneEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? redoneEntry;

  bool get didRedo;

  BrushEditRedoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? redoneEntry,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

`redoneEntry` is nullable.

If there was no redoable entry:

```txt id="kzoo4s"
redoneEntry == null
didRedo == false
```

If redo happened:

```txt id="z4flf1"
redoneEntry != null
didRedo == true
```

Use a nullable sentinel in `copyWith` for `redoneEntry`.

Do not add JSON.

## Required service

Create:

```dart id="dz7k61"
BrushEditRedoResult redoLatestBrushEdit({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
})
```

Behavior:

```txt id="ym9nca"
1. If historyState.canRedo is false:
   return BrushEditRedoResult(
     canvasState: canvasState,
     historyState: historyState,
     redoneEntry: null,
   )

2. Get entry = historyState.latestRedoEntry!

3. Re-apply the surface by calling existing service:

   applyBrushCommitResultToBitmapSurface(
     surface: canvasState.currentSurface,
     result: entry.commitResult,
   )

4. Create a reconstructed BrushSurfaceEdit:

   BrushSurfaceEdit(
     beforeSurface: canvasState.currentSurface,
     afterSurface: appliedSurface,
     commitResult: entry.commitResult,
   )

5. Create updated CanvasSurfaceState:
   currentSurface = appliedSurface
   lastEdit = reconstructed BrushSurfaceEdit

6. Create updated BrushEditHistoryState:
   undoEntries = [...historyState.undoEntries, entry]
   redoEntries = historyState.redoEntries without the last entry

7. Return BrushEditRedoResult(
   canvasState: updatedCanvasState,
   historyState: updatedHistoryState,
   redoneEntry: entry,
 )
```

Important:

```txt id="czzj67"
Do not call command.applyAfter directly.
Use applyBrushCommitResultToBitmapSurface.

Do not execute undo.
Do not execute cache invalidation.
Do not mutate input canvasState.
Do not mutate input historyState.
Do not mutate BrushEditHistoryEntry.
Do not add UI.
```

If the current surface does not match the command expectations, let the existing apply service error propagate.

## Required tests

Model tests:

```txt id="lyq0wp"
- stores canvasState, historyState, redoneEntry
- didRedo false when redoneEntry is null
- didRedo true when redoneEntry is non-null
- copyWith preserves omitted values
- copyWith updates canvasState
- copyWith updates historyState
- copyWith can set redoneEntry
- copyWith can clear redoneEntry with null
- equality / hashCode / toString
```

Service tests:

```txt id="lc29p5"
- no redo entry returns same canvasState instance
- no redo entry returns same historyState instance
- no redo entry has redoneEntry null
- redo reapplies currentSurface
- redo sets CanvasSurfaceState.lastEdit
- redo lastEdit.beforeSurface equals previous currentSurface
- redo lastEdit.afterSurface equals updated currentSurface
- redo removes latest entry from redoEntries
- redo appends redone entry to undoEntries
- redo preserves previous undo order
- redo returns redoneEntry
- redo does not mutate input CanvasSurfaceState
- redo does not mutate input BrushEditHistoryState
- redo does not mutate BrushEditHistoryEntry
- redo uses existing apply service behavior
- redo does not execute cache invalidation
- redo does not execute undo
- no UI/state management/timeline/storyboard changes
```

## Required references

Read before editing:

```txt id="aznxti"
docs/Phase_177_Codex_Task.md
docs/Phase_178_Codex_Task.md
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_surface_edit.dart
lib/src/models/brush_edit_history_entry.dart
lib/src/models/brush_edit_history_state.dart
lib/src/models/brush_edit_undo_result.dart
lib/src/services/brush_edit_history_stack.dart
lib/src/services/brush_edit_undo_service.dart
lib/src/services/brush_commit_result_apply.dart
lib/src/services/brush_commit_result_revert.dart
test/services/brush_edit_undo_service_test.dart
test/services/brush_commit_result_apply_test.dart
```

## Out of scope

Do not add:

```txt id="zt6jvl"
Canvas UI
Pointer input
Redo button
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

```bash id="g4uz8k"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Manual check list

This phase is model/service-only.

There is no required UI manual check.

If the app is run anyway, only confirm:

```txt id="s3wmj3"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```

## Report back

Report:

```txt id="au2lx8"
- changed files
- redo result model behavior
- redo service behavior
- no-redo behavior
- redo surface apply behavior
- undo/redo stack movement behavior
- lastEdit reconstruction behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
