// Internal session-local BitmapSurface materialization bridge.
// UI-facing/user undo-redo must route through BrushFrameEditingCoordinator.
import '../models/brush_bitmap_materialization_history_state.dart';
import '../models/brush_bitmap_materialization_redo_result.dart';
import '../models/brush_surface_edit.dart';
import '../models/canvas_surface_state.dart';
import 'brush_commit_result_apply.dart';

BrushBitmapMaterializationRedoResult redoLatestBrushBitmapMaterialization({
  required CanvasSurfaceState canvasState,
  required BrushBitmapMaterializationHistoryState materializationHistoryState,
}) {
  if (!materializationHistoryState.canRedo) {
    return BrushBitmapMaterializationRedoResult(
      canvasState: canvasState,
      materializationHistoryState: materializationHistoryState,
      redoneMaterializationEntry: null,
    );
  }

  final entry = materializationHistoryState.latestRedoEntry!;
  final appliedSurface = applyBrushCommitResultToBitmapSurface(
    surface: canvasState.currentSurface,
    result: entry.commitResult,
  );
  final reconstructedEdit = BrushSurfaceEdit(
    beforeSurface: canvasState.currentSurface,
    afterSurface: appliedSurface,
    commitResult: entry.commitResult,
  );

  return BrushBitmapMaterializationRedoResult(
    canvasState: canvasState.copyWith(
      currentSurface: appliedSurface,
      lastEdit: reconstructedEdit,
    ),
    materializationHistoryState: materializationHistoryState.copyWith(
      undoEntries: [...materializationHistoryState.undoEntries, entry],
      redoEntries: materializationHistoryState.redoEntries.sublist(
        0,
        materializationHistoryState.redoEntries.length - 1,
      ),
    ),
    redoneMaterializationEntry: entry,
  );
}
