import 'brush_bitmap_materialization_history_entry.dart';
import 'brush_bitmap_materialization_history_state.dart';
import 'canvas_surface_state.dart';

const Object _copyWithSentinel = Object();

class BrushEditSessionCommitResult {
  BrushEditSessionCommitResult({
    required this.canvasState,
    required this.materializationHistoryState,
    required this.historyEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushBitmapMaterializationHistoryState materializationHistoryState;
  final BrushBitmapMaterializationHistoryEntry? historyEntry;

  bool get didCommit => historyEntry != null;

  BrushEditSessionCommitResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushBitmapMaterializationHistoryState? materializationHistoryState,
    Object? historyEntry = _copyWithSentinel,
  }) {
    return BrushEditSessionCommitResult(
      canvasState: canvasState ?? this.canvasState,
      materializationHistoryState:
          materializationHistoryState ?? this.materializationHistoryState,
      historyEntry: identical(historyEntry, _copyWithSentinel)
          ? this.historyEntry
          : historyEntry as BrushBitmapMaterializationHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditSessionCommitResult &&
          other.canvasState == canvasState &&
          other.materializationHistoryState == materializationHistoryState &&
          other.historyEntry == historyEntry;

  @override
  int get hashCode =>
      Object.hash(canvasState, materializationHistoryState, historyEntry);

  @override
  String toString() =>
      'BrushEditSessionCommitResult(canvasState: $canvasState, '
      'materializationHistoryState: $materializationHistoryState, historyEntry: $historyEntry)';
}
