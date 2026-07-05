// Internal session-local BitmapSurface materialization bridge.
// UI-facing/user undo-redo must route through BrushFrameEditingCoordinator.
import '../models/brush_bitmap_materialization_history_state.dart';
import '../models/brush_bitmap_materialization_step_result.dart';
import '../models/canvas_surface_state.dart';
import 'brush_commit_result_revert.dart';

BrushBitmapMaterializationStepResult undoLatestBrushBitmapMaterialization({
  required CanvasSurfaceState canvasState,
  required BrushBitmapMaterializationHistoryState materializationHistoryState,
}) {
  if (!materializationHistoryState.canUndo) {
    return BrushBitmapMaterializationStepResult(
      canvasState: canvasState,
      materializationHistoryState: materializationHistoryState,
      materializationEntry: null,
    );
  }

  final entry = materializationHistoryState.latestUndoEntry!;
  final revertedSurface = revertBrushCommitResultOnBitmapSurface(
    surface: canvasState.currentSurface,
    result: entry.commitResult,
  );

  return BrushBitmapMaterializationStepResult(
    canvasState: canvasState.copyWith(
      currentSurface: revertedSurface,
      lastEdit: null,
    ),
    materializationHistoryState: materializationHistoryState.copyWith(
      undoEntries: materializationHistoryState.undoEntries.sublist(
        0,
        materializationHistoryState.undoEntries.length - 1,
      ),
      redoEntries: [...materializationHistoryState.redoEntries, entry],
    ),
    materializationEntry: entry,
  );
}
