import 'brush_bitmap_materialization_history_entry.dart';
import 'brush_bitmap_materialization_history_state.dart';
import 'canvas_surface_state.dart';

const Object _copyWithSentinel = Object();

class BrushBitmapMaterializationRedoResult {
  BrushBitmapMaterializationRedoResult({
    required this.canvasState,
    required this.materializationHistoryState,
    required this.redoneMaterializationEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushBitmapMaterializationHistoryState materializationHistoryState;
  final BrushBitmapMaterializationHistoryEntry? redoneMaterializationEntry;

  bool get didRedo => redoneMaterializationEntry != null;

  BrushBitmapMaterializationRedoResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushBitmapMaterializationHistoryState? materializationHistoryState,
    Object? redoneMaterializationEntry = _copyWithSentinel,
  }) {
    return BrushBitmapMaterializationRedoResult(
      canvasState: canvasState ?? this.canvasState,
      materializationHistoryState: materializationHistoryState ?? this.materializationHistoryState,
      redoneMaterializationEntry: identical(redoneMaterializationEntry, _copyWithSentinel)
          ? this.redoneMaterializationEntry
          : redoneMaterializationEntry as BrushBitmapMaterializationHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushBitmapMaterializationRedoResult &&
          other.canvasState == canvasState &&
          other.materializationHistoryState == materializationHistoryState &&
          other.redoneMaterializationEntry == redoneMaterializationEntry;

  @override
  int get hashCode => Object.hash(canvasState, materializationHistoryState, redoneMaterializationEntry);

  @override
  String toString() =>
      'BrushBitmapMaterializationRedoResult(canvasState: $canvasState, '
      'materializationHistoryState: $materializationHistoryState, redoneMaterializationEntry: $redoneMaterializationEntry)';
}
