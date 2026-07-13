import 'dart:typed_data';

import '../models/brush_dab_sequence.dart';
import '../models/dirty_region.dart';
import '../models/brush_bitmap_materialization_history_state.dart';
import '../models/brush_edit_session_commit_result.dart';
import '../models/canvas_surface_state.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import '../ui/dev_profile.dart';
import 'brush_bitmap_materialization_history_entry_builder.dart';
import 'brush_bitmap_materialization_history_stack.dart';
import 'brush_surface_edit_builder.dart';
import 'canvas_surface_state_edit.dart';

BrushEditSessionCommitResult commitBrushDabSequenceToBrushEditSession({
  required CanvasSurfaceState canvasState,
  required BrushBitmapMaterializationHistoryState materializationHistoryState,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
  Uint8List? prerasterizedStrokePixels,
  DirtyRegion? prerasterizedStrokeBounds,
}) {
  final edit = labProbe(
    'commit.edit',
    () => brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
      surface: canvasState.currentSurface,
      sequence: sequence,
      layerId: layerId,
      frameId: frameId,
      prerasterizedStrokePixels: prerasterizedStrokePixels,
      prerasterizedStrokeBounds: prerasterizedStrokeBounds,
    ),
  );
  final updatedCanvasState = labProbe(
    'commit.applyState',
    () => applyBrushSurfaceEditToCanvasSurfaceState(
      state: canvasState,
      edit: edit,
    ),
  );
  final historyEntry = labProbe(
    'commit.snapshot',
    () => brushBitmapMaterializationHistoryEntryFromBrushSurfaceEdit(
      edit: edit,
      layerId: layerId,
      frameId: frameId,
    ),
  );

  if (historyEntry == null) {
    return BrushEditSessionCommitResult(
      canvasState: updatedCanvasState,
      materializationHistoryState: materializationHistoryState,
      historyEntry: null,
    );
  }

  final updatedHistoryState = pushBrushBitmapMaterializationHistoryEntry(
    history: materializationHistoryState,
    entry: historyEntry,
  );

  return BrushEditSessionCommitResult(
    canvasState: updatedCanvasState,
    materializationHistoryState: updatedHistoryState,
    historyEntry: historyEntry,
  );
}
