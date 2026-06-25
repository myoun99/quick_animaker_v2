import 'brush_edit_history_entry.dart';
import 'brush_edit_history_state.dart';
import 'canvas_surface_state.dart';

const Object _copyWithSentinel = Object();

class BrushEditSessionCommitResult {
  BrushEditSessionCommitResult({
    required this.canvasState,
    required this.historyState,
    required this.historyEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushEditHistoryState historyState;
  final BrushEditHistoryEntry? historyEntry;

  bool get didCommit => historyEntry != null;

  BrushEditSessionCommitResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushEditHistoryState? historyState,
    Object? historyEntry = _copyWithSentinel,
  }) {
    return BrushEditSessionCommitResult(
      canvasState: canvasState ?? this.canvasState,
      historyState: historyState ?? this.historyState,
      historyEntry: identical(historyEntry, _copyWithSentinel)
          ? this.historyEntry
          : historyEntry as BrushEditHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditSessionCommitResult &&
          other.canvasState == canvasState &&
          other.historyState == historyState &&
          other.historyEntry == historyEntry;

  @override
  int get hashCode => Object.hash(canvasState, historyState, historyEntry);

  @override
  String toString() =>
      'BrushEditSessionCommitResult(canvasState: $canvasState, '
      'historyState: $historyState, historyEntry: $historyEntry)';
}
