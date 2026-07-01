import '../models/brush_bitmap_materialization_history_entry.dart';
import '../models/brush_bitmap_materialization_history_state.dart';

BrushBitmapMaterializationHistoryState pushBrushBitmapMaterializationHistoryEntry({
  required BrushBitmapMaterializationHistoryState history,
  required BrushBitmapMaterializationHistoryEntry entry,
}) {
  return BrushBitmapMaterializationHistoryState(
    undoEntries: [...history.undoEntries, entry],
    redoEntries: const [],
  );
}

BrushBitmapMaterializationHistoryState clearBrushBitmapMaterializationHistoryState({
  required BrushBitmapMaterializationHistoryState history,
}) {
  return BrushBitmapMaterializationHistoryState();
}

BrushBitmapMaterializationHistoryState clearBrushBitmapMaterializationRedoEntries({
  required BrushBitmapMaterializationHistoryState history,
}) {
  return history.copyWith(redoEntries: const []);
}
