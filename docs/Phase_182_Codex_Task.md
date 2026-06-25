# Phase 182 Codex Task

## Title

Create BrushEditSessionState and session operation facade

## Current position

```txt id="p7i9hp"
Overall roadmap:
1. Brush work
2. Storyboard panel
3. Save / Run

Current:
1. Brush work
1-12. BrushEditSessionState + session operation facade
```

## Brush work detailed roadmap

```txt id="r8ykqt"
1-1. BitmapSurface / BitmapTile foundation - done
1-2. BrushDab / BrushDabSequence foundation - done
1-3. Brush pixel blend foundation - done
1-4. BrushDabSequence -> BitmapSurface commit - done
1-5. CanvasSurfaceState integration - done
1-6. BrushEditHistoryEntry - done
1-7. BrushEditHistoryState - done
1-8. Undo execution service - done
1-9. Redo execution service - done
1-10. CanvasSurfaceState + BrushEditHistoryState integrated commit - done
1-11. Cache invalidation execution service - done
1-12. BrushEditSessionState + session operation facade - current
1-13. Cache-aware commit / undo / redo facade
1-14. Real Canvas UI integration
1-15. Brush work v1 complete
```

## Goal

Create a small session-level state model that groups:

```txt id="xjc6yp"
CanvasSurfaceState
BrushEditHistoryState
```

Then create a facade service that lets future UI code call commit / undo / redo using this combined session state.

This phase should only compose existing services.

Do not add UI.

Do not execute cache invalidation in this phase.

Do not add save/load.

## Required files

Create:

```txt id="eh0a9o"
lib/src/models/brush_edit_session_state.dart
lib/src/services/brush_edit_session_state_operations.dart
test/models/brush_edit_session_state_test.dart
test/services/brush_edit_session_state_operations_test.dart
```

## Required model

Create:

```dart id="p8k0zt"
class BrushEditSessionState {
  BrushEditSessionState({
    required this.canvasState,
    required this.historyState,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;

  bool get canUndo;
  bool get canRedo;
  bool get hasLastEdit;

  BrushEditSessionState copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
  });

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;

  @override
  String toString();
}
```

Getter behavior:

```txt id="h2488w"
canUndo == historyState.canUndo
canRedo == historyState.canRedo
hasLastEdit == canvasState.hasLastEdit
```

No JSON.

## Required service

Create session operation facade functions.

```dart id="s2d2ms"
BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSessionState({
  required BrushEditSessionState sessionState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
})
```

Behavior:

```txt id="d8onvd"
Call existing commitBrushDabSequenceToBrushEditSession with:
- canvasState: sessionState.canvasState
- historyState: sessionState.historyState
- sequence
- layerId
- frameId

Return its result directly.
```

Create:

```dart id="njytf3"
BrushEditUndoResult undoLatestBrushEditInSessionState({
  required BrushEditSessionState sessionState,
})
```

Behavior:

```txt id="n5qae6"
Call existing undoLatestBrushEdit with:
- canvasState: sessionState.canvasState
- historyState: sessionState.historyState

Return its result directly.
```

Create:

```dart id="nmgier"
BrushEditRedoResult redoLatestBrushEditInSessionState({
  required BrushEditSessionState sessionState,
})
```

Behavior:

```txt id="rdwa7v"
Call existing redoLatestBrushEdit with:
- canvasState: sessionState.canvasState
- historyState: sessionState.historyState

Return its result directly.
```

Create helper converters:

```dart id="rjzk5a"
BrushEditSessionState sessionStateFromCommitResult(
  BrushEditSessionCommitResult result,
)

BrushEditSessionState sessionStateFromUndoResult(
  BrushEditUndoResult result,
)

BrushEditSessionState sessionStateFromRedoResult(
  BrushEditRedoResult result,
)
```

Behavior:

```txt id="ifcyc9"
Return BrushEditSessionState(
  canvasState: result.canvasState,
  historyState: result.historyState,
)
```

## Important constraints

```txt id="pe99my"
Do not manually build BrushCommitResult.
Do not manually build BrushSurfaceEdit.
Do not manually build BrushEditHistoryEntry.
Do not manually build TileDeltaCommand.
Do not manually build CacheInvalidationPlan.
Do not manually apply TileDelta objects.
Do not call command.applyBefore or command.applyAfter.
Do not call surface.putTile or surface.removeTile directly.
Do not execute cache invalidation.
Do not execute cache storage.
Do not add UI.
```

This phase is a facade/wrapper layer only.

## Required tests

Model tests:

```txt id="v1a1uk"
- stores canvasState and historyState
- canUndo delegates to historyState.canUndo
- canRedo delegates to historyState.canRedo
- hasLastEdit delegates to canvasState.hasLastEdit
- copyWith preserves omitted values
- copyWith updates canvasState
- copyWith updates historyState
- equality / hashCode / toString
```

Service tests:

```txt id="iu53xv"
- commit facade returns same result as commitBrushDabSequenceToBrushEditSession
- commit facade no-op behavior matches existing commit service
- commit facade changed behavior matches existing commit service
- undo facade returns same result as undoLatestBrushEdit
- undo facade no-op behavior matches existing undo service
- redo facade returns same result as redoLatestBrushEdit
- redo facade no-op behavior matches existing redo service
- sessionStateFromCommitResult maps canvasState and historyState
- sessionStateFromUndoResult maps canvasState and historyState
- sessionStateFromRedoResult maps canvasState and historyState
- commit -> sessionStateFromCommitResult -> undo works
- undo -> sessionStateFromUndoResult -> redo works
- does not mutate input BrushEditSessionState
- does not mutate input CanvasSurfaceState
- does not mutate input BrushEditHistoryState
- does not execute cache invalidation
- does not add UI/state management/timeline/storyboard changes
```

## Required references

Read before editing:

```txt id="w4aoph"
docs/Phase_178_Codex_Task.md
docs/Phase_179_Codex_Task.md
docs/Phase_180_Codex_Task.md
docs/Phase_181_Codex_Task.md
lib/src/models/canvas_surface_state.dart
lib/src/models/brush_edit_history_state.dart
lib/src/models/brush_edit_session_commit_result.dart
lib/src/models/brush_edit_undo_result.dart
lib/src/models/brush_edit_redo_result.dart
lib/src/services/brush_edit_session_commit.dart
lib/src/services/brush_edit_undo_service.dart
lib/src/services/brush_edit_redo_service.dart
lib/src/services/cache_invalidation_executor.dart
```

## Out of scope

Do not add:

```txt id="offmtq"
Canvas UI
Pointer input
Brush tool widget
HistoryService
Provider / Riverpod / Bloc / ChangeNotifier
Cache invalidation execution
Cache storage
Cache recomputation
Save / load
Timeline changes
Storyboard changes
```

## Required checks

Run:

```bash id="ti1u38"
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

```txt id="eggh0n"
- The app still launches.
- Existing canvas-related screen, if visible, appears as before.
- Existing StoryboardPanel behavior does not visibly change.
- Existing TimelinePanel behavior does not visibly change.
```

## Report back

Report:

```txt id="ze6q14"
- changed files
- BrushEditSessionState behavior
- commit facade behavior
- undo facade behavior
- redo facade behavior
- converter behavior
- no-op behavior
- changed behavior
- immutability behavior
- scope confirmations
- check results
- manual check list status
- git status summary
```
