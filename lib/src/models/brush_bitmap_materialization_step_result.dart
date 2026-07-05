import 'brush_bitmap_materialization_history_entry.dart';
import 'brush_bitmap_materialization_history_state.dart';
import '../core/copy_with_sentinel.dart';
import 'canvas_surface_state.dart';

/// Result of a single session-local bitmap-materialization step (undo or redo).
///
/// Undo and redo are symmetric — each moves one entry between the undo/redo
/// stacks and returns the resulting canvas + history state plus the entry that
/// moved (or `null` when nothing could move). A single value type is used for
/// both directions; [materializationEntry] is the entry that was undone or
/// redone.
class BrushBitmapMaterializationStepResult {
  BrushBitmapMaterializationStepResult({
    required this.canvasState,
    required this.materializationHistoryState,
    required this.materializationEntry,
  });

  final CanvasSurfaceState canvasState;
  final BrushBitmapMaterializationHistoryState materializationHistoryState;
  final BrushBitmapMaterializationHistoryEntry? materializationEntry;

  /// Whether a step was actually applied (an entry moved between stacks).
  bool get didApply => materializationEntry != null;

  BrushBitmapMaterializationStepResult copyWith({
    CanvasSurfaceState? canvasState,
    BrushBitmapMaterializationHistoryState? materializationHistoryState,
    Object? materializationEntry = copyWithSentinel,
  }) {
    return BrushBitmapMaterializationStepResult(
      canvasState: canvasState ?? this.canvasState,
      materializationHistoryState:
          materializationHistoryState ?? this.materializationHistoryState,
      materializationEntry: identical(materializationEntry, copyWithSentinel)
          ? this.materializationEntry
          : materializationEntry as BrushBitmapMaterializationHistoryEntry?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushBitmapMaterializationStepResult &&
          other.canvasState == canvasState &&
          other.materializationHistoryState == materializationHistoryState &&
          other.materializationEntry == materializationEntry;

  @override
  int get hashCode => Object.hash(
    canvasState,
    materializationHistoryState,
    materializationEntry,
  );

  @override
  String toString() =>
      'BrushBitmapMaterializationStepResult(canvasState: $canvasState, '
      'materializationHistoryState: $materializationHistoryState, '
      'materializationEntry: $materializationEntry)';
}
