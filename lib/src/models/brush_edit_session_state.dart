import 'brush_bitmap_materialization_history_state.dart';
import 'canvas_surface_state.dart';

class BrushEditSessionState {
  BrushEditSessionState({
    required this.canvasState,
    required this.materializationHistoryState,
  });

  final CanvasSurfaceState canvasState;
  final BrushBitmapMaterializationHistoryState materializationHistoryState;

  bool get canUndo => materializationHistoryState.canUndo;

  bool get canRedo => materializationHistoryState.canRedo;

  bool get hasLastEdit => canvasState.hasLastEdit;

  BrushEditSessionState copyWith({
    CanvasSurfaceState? canvasState,
    BrushBitmapMaterializationHistoryState? materializationHistoryState,
  }) {
    return BrushEditSessionState(
      canvasState: canvasState ?? this.canvasState,
      materializationHistoryState:
          materializationHistoryState ?? this.materializationHistoryState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditSessionState &&
          other.canvasState == canvasState &&
          other.materializationHistoryState == materializationHistoryState;

  @override
  int get hashCode => Object.hash(canvasState, materializationHistoryState);

  @override
  String toString() =>
      'BrushEditSessionState(canvasState: $canvasState, '
      'materializationHistoryState: $materializationHistoryState)';
}
