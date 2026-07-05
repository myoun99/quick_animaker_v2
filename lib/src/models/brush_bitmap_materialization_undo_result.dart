import 'brush_bitmap_materialization_history_entry.dart';
import 'brush_bitmap_materialization_history_state.dart';
import '../core/copy_with_sentinel.dart';
import 'canvas_surface_state.dart';

class BrushBitmapMaterializationUndoResult {
  BrushBitmapMaterializationUndoResult({
    required this.canvasState,
    required this.materializationHistoryState,
    required this.undoneMaterializationEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushBitmapMaterializationHistoryState materializationHistoryState;
  final BrushBitmapMaterializationHistoryEntry? undoneMaterializationEntry;

  bool get didUndo => undoneMaterializationEntry != null;

  BrushBitmapMaterializationUndoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushBitmapMaterializationHistoryState? materializationHistoryState,
    Object? undoneMaterializationEntry = copyWithSentinel,
  }) {
    return BrushBitmapMaterializationUndoResult(
      canvasState: canvasState ?? this.canvasState,
      materializationHistoryState:
          materializationHistoryState ?? this.materializationHistoryState,
      undoneMaterializationEntry:
          identical(undoneMaterializationEntry, copyWithSentinel)
          ? this.undoneMaterializationEntry
          : undoneMaterializationEntry
                as BrushBitmapMaterializationHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushBitmapMaterializationUndoResult &&
          other.canvasState == canvasState &&
          other.materializationHistoryState == materializationHistoryState &&
          other.undoneMaterializationEntry == undoneMaterializationEntry;

  @override
  int get hashCode => Object.hash(
    canvasState,
    materializationHistoryState,
    undoneMaterializationEntry,
  );

  @override
  String toString() =>
      'BrushBitmapMaterializationUndoResult(canvasState: $canvasState, '
      'materializationHistoryState: $materializationHistoryState, undoneMaterializationEntry: $undoneMaterializationEntry)';
}
