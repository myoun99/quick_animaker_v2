import '../models/brush_surface_edit.dart';
import '../models/canvas_surface_state.dart';

CanvasSurfaceState applyBrushSurfaceEditToCanvasSurfaceState({
  required CanvasSurfaceState state,
  required BrushSurfaceEdit edit,
}) {
  if (edit.beforeSurface != state.currentSurface) {
    throw StateError(
      'BrushSurfaceEdit beforeSurface must match CanvasSurfaceState currentSurface.',
    );
  }

  if (edit.isNoOp) {
    return state;
  }

  return CanvasSurfaceState(currentSurface: edit.afterSurface, lastEdit: edit);
}
