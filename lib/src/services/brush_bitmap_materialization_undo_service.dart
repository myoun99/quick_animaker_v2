import '../models/brush_bitmap_materialization_history_state.dart';
import '../models/brush_bitmap_materialization_undo_result.dart';
import '../models/canvas_surface_state.dart';
import 'brush_commit_result_revert.dart';

BrushBitmapMaterializationUndoResult undoLatestBrushBitmapMaterialization({
  required CanvasSurfaceState canvasState,
  required BrushBitmapMaterializationHistoryState materializationHistoryState,
}) {
  if (!materializationHistoryState.canUndo) {
    return BrushBitmapMaterializationUndoResult(
      canvasState: canvasState,
      materializationHistoryState: materializationHistoryState,
      undoneMaterializationEntry: null,
    );
  }

  final entry = materializationHistoryState.latestUndoEntry!;
  final revertedSurface = revertBrushCommitResultOnBitmapSurface(
    surface: canvasState.currentSurface,
    result: entry.commitResult,
  );

  return BrushBitmapMaterializationUndoResult(
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
    undoneMaterializationEntry: entry,
  );
}
