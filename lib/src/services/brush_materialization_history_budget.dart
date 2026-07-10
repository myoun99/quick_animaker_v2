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

/// Trims a frame's bitmap undo/redo snapshots to [maxBytes] and, when
/// [maxEntries] is given, to that COUNT per stack.
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
/// The count cap exists because the byte budget alone let SMALL strokes
/// pile up hundreds of snapshots: the unified history can only reach
/// `userUndoLimit` entries deep, so everything below that is unreachable
/// dead weight — yet it pinned the full byte budget (256MB of tiles for
/// 24 usable undos), and that heap ballooning was a main accumulation
/// source behind the progressive brush lag on long drawing runs.
///
/// Returns [state] identically when nothing needs to drop.
BrushBitmapMaterializationHistoryState trimMaterializationHistoryToByteBudget(
  BrushBitmapMaterializationHistoryState state, {
  required int maxBytes,
  int? maxEntries,
}) {
  var undoEntries = state.undoEntries;
  var redoEntries = state.redoEntries;
  var droppedByCount = false;
  if (maxEntries != null) {
    if (undoEntries.length > maxEntries) {
      undoEntries = undoEntries.sublist(undoEntries.length - maxEntries);
      droppedByCount = true;
    }
    if (redoEntries.length > maxEntries) {
      redoEntries = redoEntries.sublist(redoEntries.length - maxEntries);
      droppedByCount = true;
    }
  }

  var total = 0;
  for (final entry in undoEntries) {
    total += materializationEntryByteEstimate(entry);
  }
  for (final entry in redoEntries) {
    total += materializationEntryByteEstimate(entry);
  }
  if (total <= maxBytes) {
    return droppedByCount
        ? state.copyWith(undoEntries: undoEntries, redoEntries: redoEntries)
        : state;
  }

  var undoStart = 0;
  while (total > maxBytes && undoStart < undoEntries.length - 1) {
    total -= materializationEntryByteEstimate(undoEntries[undoStart]);
    undoStart += 1;
  }

  var redoStart = 0;
  while (total > maxBytes && redoStart < redoEntries.length) {
    total -= materializationEntryByteEstimate(redoEntries[redoStart]);
    redoStart += 1;
  }

  return state.copyWith(
    undoEntries: undoEntries.sublist(undoStart),
    redoEntries: redoEntries.sublist(redoStart),
  );
}
