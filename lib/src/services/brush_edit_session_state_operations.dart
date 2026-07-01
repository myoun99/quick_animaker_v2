import '../models/brush_dab_sequence.dart';
import '../models/brush_bitmap_materialization_redo_result.dart';
import '../models/brush_edit_session_commit_result.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_bitmap_materialization_undo_result.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_bitmap_materialization_redo_service.dart';
import 'brush_edit_session_commit.dart';
import 'brush_bitmap_materialization_undo_service.dart';

BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSessionState({
  required BrushEditSessionState sessionState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  return commitBrushDabSequenceToBrushEditSession(
    canvasState: sessionState.canvasState,
    materializationHistoryState: sessionState.materializationHistoryState,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );
}

BrushBitmapMaterializationUndoResult undoLatestBrushBitmapMaterializationInSessionState({
  required BrushEditSessionState sessionState,
}) {
  return undoLatestBrushBitmapMaterialization(
    canvasState: sessionState.canvasState,
    materializationHistoryState: sessionState.materializationHistoryState,
  );
}

BrushBitmapMaterializationRedoResult redoLatestBrushBitmapMaterializationInSessionState({
  required BrushEditSessionState sessionState,
}) {
  return redoLatestBrushBitmapMaterialization(
    canvasState: sessionState.canvasState,
    materializationHistoryState: sessionState.materializationHistoryState,
  );
}

BrushEditSessionState sessionStateFromCommitResult(
  BrushEditSessionCommitResult result,
) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    materializationHistoryState: result.materializationHistoryState,
  );
}

BrushEditSessionState sessionStateFromUndoResult(BrushBitmapMaterializationUndoResult result) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    materializationHistoryState: result.materializationHistoryState,
  );
}

BrushEditSessionState sessionStateFromRedoResult(BrushBitmapMaterializationRedoResult result) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    materializationHistoryState: result.materializationHistoryState,
  );
}
