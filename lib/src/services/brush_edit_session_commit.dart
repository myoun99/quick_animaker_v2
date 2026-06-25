import '../models/brush_dab_sequence.dart';
import '../models/brush_edit_history_state.dart';
import '../models/brush_edit_session_commit_result.dart';
import '../models/canvas_surface_state.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_edit_history_entry_builder.dart';
import 'brush_edit_history_stack.dart';
import 'brush_surface_edit_builder.dart';
import 'canvas_surface_state_edit.dart';

BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSession({
  required CanvasSurfaceState canvasState,
  required BrushEditHistoryState historyState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  final edit = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
    surface: canvasState.currentSurface,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );
  final updatedCanvasState = applyBrushSurfaceEditToCanvasSurfaceState(
    state: canvasState,
    edit: edit,
  );
  final historyEntry = brushEditHistoryEntryFromBrushSurfaceEdit(
    edit: edit,
    layerId: layerId,
    frameId: frameId,
  );

  if (historyEntry == null) {
    return BrushEditSessionCommitResult(
      canvasState: updatedCanvasState,
      historyState: historyState,
      historyEntry: null,
    );
  }

  final updatedHistoryState = pushBrushEditHistoryEntry(
    history: historyState,
    entry: historyEntry,
  );

  return BrushEditSessionCommitResult(
    canvasState: updatedCanvasState,
    historyState: updatedHistoryState,
    historyEntry: historyEntry,
  );
}
