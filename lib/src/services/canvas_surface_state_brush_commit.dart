import '../models/brush_dab_sequence.dart';
import '../models/canvas_surface_state.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_surface_edit_builder.dart';
import 'canvas_surface_state_edit.dart';

CanvasSurfaceState commitBrushDabSequenceToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  final edit = brushSurfaceEditForBrushDabSequenceOnBitmapSurface(
    surface: state.currentSurface,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );

  return applyBrushSurfaceEditToCanvasSurfaceState(state: state, edit: edit);
}
