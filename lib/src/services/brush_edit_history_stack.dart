import '../models/brush_edit_history_entry.dart';
import '../models/brush_edit_history_state.dart';

BrushEditHistoryState pushBrushEditHistoryEntry({
  required BrushEditHistoryState history,
  required BrushEditHistoryEntry entry,
}) {
  return BrushEditHistoryState(
    undoEntries: [...history.undoEntries, entry],
    redoEntries: const [],
  );
}

BrushEditHistoryState clearBrushEditHistoryState({
  required BrushEditHistoryState history,
}) {
  return BrushEditHistoryState();
}

BrushEditHistoryState clearRedoEntries({
  required BrushEditHistoryState history,
}) {
  return history.copyWith(redoEntries: const []);
}
