import '../models/brush_edit_history_state.dart';
import '../models/brush_edit_undo_result.dart';
import '../models/canvas_surface_state.dart';
import 'brush_commit_result_revert.dart';

BrushEditUndoResult undoLatestBrushEdit({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
}) {
  if (!historyState.canUndo) {
    return BrushEditUndoResult(
      canvasState: canvasState,
      historyState: historyState,
      undoneEntry: null,
    );
  }

  final entry = historyState.latestUndoEntry!;
  final revertedSurface = revertBrushCommitResultOnBitmapSurface(
    surface: canvasState.currentSurface,
    result: entry.commitResult,
  );

  return BrushEditUndoResult(
    canvasState: canvasState.copyWith(
      currentSurface: revertedSurface,
      lastEdit: null,
    ),
    historyState: historyState.copyWith(
      undoEntries: historyState.undoEntries.sublist(
        0,
        historyState.undoEntries.length - 1,
      ),
      redoEntries: [...historyState.redoEntries, entry],
    ),
    undoneEntry: entry,
  );
}
