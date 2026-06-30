# Phase 178 Codex Task

## Title

Create brush edit undo execution service

## Current position

```txt id="dcok6v"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-8. Undo execution service
```

## Brush work detailed roadmap

```txt id="b1gku2"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - current
1-9. Redo execution service - next
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit
1-11. Cache invalidation execution
1-12. Real Canvas UI integration
1-13. Brush work v1 complete
```

## Goal

Add undo execution for brush edits.

This phase should take:

```txt id="x0x3pe"
CanvasSurfaceState
BrushEditHistoryState
```

and undo the latest brush edit if possible.

It should:

```txt id="ec71f3"
- revert currentSurface using the latest undo entry
- move that entry from undoEntries to redoEntries
- clear CanvasSurfaceState.lastEdit
```

This is still service/model only.

Do not add UI.

Do not add redo execution yet.

Do not execute cache invalidation yet.

## Required files

Create:

```txt id="od1axp"
lib/src/models/brush_edit_undo_result.dart
lib/src/services/brush_edit_undo_service.dart
test/models/brush_edit_undo_result_test.dart
test/services/brush_edit_undo_service_test.dart
```

## Required model

Create:

```dart id="vri3gm"
class BrushEditUndoResult {
  BrushEditUndoResult({
    required this.canvasState,
    required this.historyState,
    required this.undoneEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? undoneEntry;

  bool get didUndo;

  BrushEditUndoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? undoneEntry,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

`undoneEntry` is nullable.

If there was no undoable entry:

```txt id="ogz2hk"
undoneEntry == null
didUndo == false
```

If undo happened:

```txt id="m4camc"
undoneEntry != null
didUndo == true
```

Use a nullable sentinel in `copyWith` for `undoneEntry`.

Do not add JSON.

## Required service

Create:

```dart id="t9xxif"
BrushEditUndoResult undoLatestBrushEdit({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
})
```

Behavior:

```txt id="crvw4z"
1. If historyState.canUndo is false:
   return BrushEditUndoResult(
     canvasState: canvasState,
     historyState: historyState,
     undoneEntry: null,
   )

2. Get entry = historyState.latestUndoEntry!

3. Revert the surface by calling existing service:

   revertBrushCommitResultOnBitmapSurface(
     surface: canvasState.currentSurface,
     result: entry.commitResult,
   )

4. Create updated CanvasSurfaceState:
   currentSurface = reverted surface
   lastEdit = null

5. Create updated BrushEditHistoryState:
   undoEntries = historyState.undoEntries without the last entry
   redoEntries = [...historyState.redoEntries, entry]

6. Return BrushEditUndoResult(
   canvasState: updatedCanvasState,
   historyState: updatedHistoryState,
   undoneEntry: entry,
 )
```

Important:

```txt id="we1ge2"
Do not call command.applyBefore directly.
Use revertBrushCommitResultOnBitmapSurface.

Do not execute redo.
Do not execute cache invalidation.
Do not mutate input canvasState.
Do not mutate input historyState.
Do not mutate BrushEditHistoryEntry.
Do not add UI.
```

If the current surface does not match the command expectations, let the existing revert service error propagate.

## Required tests

Model tests:

```txt id="orctyr"
- stores canvasState, historyState, undoneEntry
- didUndo false when undoneEntry is null
- didUndo true when undoneEntry is non-null
- copyWith preserves omitted values
- copyWith updates canvasState
- copyWith updates historyState
- copyWith can set undoneEntry
- copyWith can clear undoneEntry with null
- equality / hashCode / toString
```

Service tests:

```txt id="r70m0y"
- no undo entry returns same canvasState instance
- no undo entry returns same historyState instance
- no undo entry has undoneEntry null
- undo reverts currentSurface
- undo clears CanvasSurfaceState.lastEdit
- undo removes latest entry from undoEntries
- undo appends undone entry to redoEntries
- undo preserves previous redo order
- undo returns undoneEntry
- undo does not mutate input CanvasSurfaceState
- undo does not mutate input BrushEditHistoryState
- undo does not mutate BrushEditHistoryEntry
- undo uses existing revert service behavior
- undo does not execute cache invalidation
- undo does not execute redo
- no UI/state management/timeline/storyboard changes
```

## Required references

Read before editing:

```txt id="fz2cv9"
docs/Phase_176_Codex_Task.md
docs/Phase_177_Codex_Task.md
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_edit_history_entry.dart
lib/src/models/brush_edit_history_state.dart
lib/src/services/brush_edit_history_stack.dart
lib/src/services/brush_commit_result_revert.dart
lib/src/services/canvas_surface_state_brush_commit.dart
test/services/brush_edit_history_stack_test.dart
test/services/brush_commit_result_revert_test.dart
```

## Out of scope

Do not add:

```txt id="d6nfa2"
Redo execution
Canvas UI
Pointer input
Undo button
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

```bash id="lk21gf"
git diff --check
dart format lib test
flutter analyze
flutter test
git status
```

If Dart/Flutter are unavailable, report that clearly.

## Report back

Report:

```txt id="r1g8jw"
- changed files
- undo result model behavior
- undo service behavior
- no-undo behavior
- undo surface revert behavior
- undo/redo stack movement behavior
- lastEdit clearing behavior
- immutability behavior
- scope confirmations
- check results
- git status summary
```
