import 'brush_edit_history_entry.dart';
import 'brush_edit_history_state.dart';
import 'canvas_surface_state.dart';

const Object _copyWithSentinel = Object();

class BrushEditUndoResult {
  BrushEditUndoResult({
    required this.canvasState,
    required this.historyState,
    required this.undoneEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? undoneEntry;

  bool get didUndo => undoneEntry != null;

  BrushEditUndoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? undoneEntry = _copyWithSentinel,
  }) {
    return BrushEditUndoResult(
      canvasState: canvasState ?? this.canvasState,
      historyState: historyState ?? this.historyState,
      undoneEntry: identical(undoneEntry, _copyWithSentinel)
          ? this.undoneEntry
          : undoneEntry as BrushEditHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditUndoResult &&
          other.canvasState == canvasState &&
          other.historyState == historyState &&
          other.undoneEntry == undoneEntry;

  @override
  int get hashCode => Object.hash(canvasState, historyState, undoneEntry);

  @override
  String toString() =>
      'BrushEditUndoResult(canvasState: $canvasState, '
      'historyState: $historyState, undoneEntry: $undoneEntry)';
}
