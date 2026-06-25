import '../models/brush_edit_history_state.dart';
import '../models/brush_edit_redo_result.dart';
import '../models/brush_surface_edit.dart';
import '../models/canvas_surface_state.dart';
import 'brush_commit_result_apply.dart';

BrushEditRedoResult redoLatestBrushEdit({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
}) {
  if (!historyState.canRedo) {
    return BrushEditRedoResult(
      canvasState: canvasState,
      historyState: historyState,
      redoneEntry: null,
    );
  }

  final entry = historyState.latestRedoEntry!;
  final appliedSurface = applyBrushCommitResultToBitmapSurface(
    surface: canvasState.currentSurface,
    result: entry.commitResult,
  );
  final reconstructedEdit = BrushSurfaceEdit(
    beforeSurface: canvasState.currentSurface,
    afterSurface: appliedSurface,
    commitResult: entry.commitResult,
  );

  return BrushEditRedoResult(
    canvasState: canvasState.copyWith(
      currentSurface: appliedSurface,
      lastEdit: reconstructedEdit,
    ),
    historyState: historyState.copyWith(
      undoEntries: [...historyState.undoEntries, entry],
      redoEntries: historyState.redoEntries.sublist(
        0,
        historyState.redoEntries.length - 1,
      ),
    ),
    redoneEntry: entry,
  );
}
