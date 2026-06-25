import '../models/brush_dab_sequence.dart';
import '../models/brush_edit_redo_result.dart';
import '../models/brush_edit_session_commit_result.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_edit_undo_result.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_edit_redo_service.dart';
import 'brush_edit_session_commit.dart';
import 'brush_edit_undo_service.dart';

BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSessionState({
  required BrushEditSessionState sessionState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  return commitBrushDabSequenceToBrushEditSession(
    canvasState: sessionState.canvasState,
    historyState: sessionState.historyState,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );
}

BrushEditUndoResult undoLatestBrushEditInSessionState({
  required BrushEditSessionState sessionState,
}) {
  return undoLatestBrushEdit(
    canvasState: sessionState.canvasState,
    historyState: sessionState.historyState,
  );
}

BrushEditRedoResult redoLatestBrushEditInSessionState({
  required BrushEditSessionState sessionState,
}) {
  return redoLatestBrushEdit(
    canvasState: sessionState.canvasState,
    historyState: sessionState.historyState,
  );
}

BrushEditSessionState sessionStateFromCommitResult(
  BrushEditSessionCommitResult result,
) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    historyState: result.historyState,
  );
}

BrushEditSessionState sessionStateFromUndoResult(BrushEditUndoResult result) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    historyState: result.historyState,
  );
}

BrushEditSessionState sessionStateFromRedoResult(BrushEditRedoResult result) {
  return BrushEditSessionState(
    canvasState: result.canvasState,
    historyState: result.historyState,
  );
}
