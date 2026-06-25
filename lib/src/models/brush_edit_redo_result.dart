import 'brush_edit_history_entry.dart';
import 'brush_edit_history_state.dart';
import 'canvas_surface_state.dart';

const Object _copyWithSentinel = Object();

class BrushEditRedoResult {
  BrushEditRedoResult({
    required this.canvasState,
    required this.historyState,
    required this.redoneEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? redoneEntry;

  bool get didRedo => redoneEntry != null;

  BrushEditRedoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? redoneEntry = _copyWithSentinel,
  }) {
    return BrushEditRedoResult(
      canvasState: canvasState ?? this.canvasState,
      historyState: historyState ?? this.historyState,
      redoneEntry: identical(redoneEntry, _copyWithSentinel)
          ? this.redoneEntry
          : redoneEntry as BrushEditHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditRedoResult &&
          other.canvasState == canvasState &&
          other.historyState == historyState &&
          other.redoneEntry == redoneEntry;

  @override
  int get hashCode => Object.hash(canvasState, historyState, redoneEntry);

  @override
  String toString() =>
      'BrushEditRedoResult(canvasState: $canvasState, '
      'historyState: $historyState, redoneEntry: $redoneEntry)';
}
