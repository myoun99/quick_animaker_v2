import 'brush_edit_history_state.dart';
import 'canvas_surface_state.dart';

class BrushEditSessionState {
  BrushEditSessionState({
    required this.canvasState,
    required this.historyState,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;

  bool get canUndo => historyState.canUndo;

  bool get canRedo => historyState.canRedo;

  bool get hasLastEdit => canvasState.hasLastEdit;

  BrushEditSessionState copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
  }) {
    return BrushEditSessionState(
      canvasState: canvasState ?? this.canvasState,
      historyState: historyState ?? this.historyState,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditSessionState &&
          other.canvasState == canvasState &&
          other.historyState == historyState;

  @override
  int get hashCode => Object.hash(canvasState, historyState);

  @override
  String toString() =>
      'BrushEditSessionState(canvasState: $canvasState, '
      'historyState: $historyState)';
}
