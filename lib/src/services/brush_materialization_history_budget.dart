import '../models/brush_bitmap_materialization_history_entry.dart';
import '../models/brush_bitmap_materialization_history_state.dart';

/// Approximate bytes one materialization snapshot pins.
///
/// Entries hold whole before/after surfaces, but [BitmapSurface] versions
/// structurally share unchanged tiles — the marginal retention per entry is
/// its CHANGED tiles' pixel bytes (each intermediate surface version keeps
/// one generation of the touched tiles alive).
int materializationEntryByteEstimate(
  BrushBitmapMaterializationHistoryEntry entry,
) {
  final tileSize = entry.commitResult.beforeSurface.tileSize;
  return entry.changedTileCount * tileSize * tileSize * 4;
}

/// Trims a frame's bitmap undo/redo snapshots to [maxBytes].
///
/// Drops the entries FURTHEST from the present first — the deepest undo
/// entries (stack bottom), then the furthest redo entries (list front) —
/// so the stack TOPS stay aligned with the unified history and recent
/// undo/redo stays on the fast tile-revert path. The newest undo entry is
/// always kept even when it alone exceeds the budget (the immediate undo
/// of a giant stroke must stay fast). Undoing PAST a trimmed entry falls
/// back to the command replay (the canvas-resize mechanism) — correct,
/// just slower.
///
/// Returns [state] identically when nothing needs to drop.
BrushBitmapMaterializationHistoryState trimMaterializationHistoryToByteBudget(
  BrushBitmapMaterializationHistoryState state, {
  required int maxBytes,
}) {
  var total = 0;
  for (final entry in state.undoEntries) {
    total += materializationEntryByteEstimate(entry);
  }
  for (final entry in state.redoEntries) {
    total += materializationEntryByteEstimate(entry);
  }
  if (total <= maxBytes) {
    return state;
  }

  var undoStart = 0;
  final undoEntries = state.undoEntries;
  while (total > maxBytes && undoStart < undoEntries.length - 1) {
    total -= materializationEntryByteEstimate(undoEntries[undoStart]);
    undoStart += 1;
  }

  var redoStart = 0;
  final redoEntries = state.redoEntries;
  while (total > maxBytes && redoStart < redoEntries.length) {
    total -= materializationEntryByteEstimate(redoEntries[redoStart]);
    redoStart += 1;
  }

  return state.copyWith(
    undoEntries: undoEntries.sublist(undoStart),
    redoEntries: redoEntries.sublist(redoStart),
  );
}
