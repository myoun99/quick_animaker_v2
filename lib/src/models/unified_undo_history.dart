import 'undo_history_entry.dart';

class UnifiedUndoHistoryPushResult {
  const UnifiedUndoHistoryPushResult({required this.history, this.trimmedEntries = const []});

  final UnifiedUndoHistory history;
  final List<UndoHistoryEntry> trimmedEntries;
}

class UnifiedUndoHistory {
  const UnifiedUndoHistory({
    required this.userUndoLimit,
    List<UndoHistoryEntry> undoStack = const [],
    List<UndoHistoryEntry> redoStack = const [],
  }) : _undoStack = undoStack,
       _redoStack = redoStack,
       assert(userUndoLimit > 0);

  final int userUndoLimit;
  final List<UndoHistoryEntry> _undoStack;
  final List<UndoHistoryEntry> _redoStack;

  List<UndoHistoryEntry> get undoStack => List.unmodifiable(_undoStack);
  List<UndoHistoryEntry> get redoStack => List.unmodifiable(_redoStack);

  UnifiedUndoHistoryPushResult pushNewEntry(UndoHistoryEntry entry) {
    final nextUndo = [..._undoStack, entry];
    final trimCount = nextUndo.length > userUndoLimit ? nextUndo.length - userUndoLimit : 0;
    final trimmed = trimCount == 0 ? <UndoHistoryEntry>[] : nextUndo.take(trimCount).toList();
    final kept = trimCount == 0 ? nextUndo : nextUndo.skip(trimCount).toList();
    return UnifiedUndoHistoryPushResult(
      history: UnifiedUndoHistory(userUndoLimit: userUndoLimit, undoStack: kept),
      trimmedEntries: trimmed,
    );
  }

  UndoHistoryEntry? get latestUndoEntry => _undoStack.isEmpty ? null : _undoStack.last;
  UndoHistoryEntry? get latestRedoEntry => _redoStack.isEmpty ? null : _redoStack.last;

  UnifiedUndoHistoryTakeResult takeUndo() => _take(fromUndo: true);
  UnifiedUndoHistoryTakeResult takeRedo() => _take(fromUndo: false);

  UnifiedUndoHistoryTakeResult _take({required bool fromUndo}) {
    final source = fromUndo ? _undoStack : _redoStack;
    if (source.isEmpty) return UnifiedUndoHistoryTakeResult(history: this);
    final entry = source.last;
    final nextUndo = fromUndo
        ? _undoStack.sublist(0, _undoStack.length - 1)
        : [..._undoStack, entry];
    final nextRedo = fromUndo
        ? [..._redoStack, entry]
        : _redoStack.sublist(0, _redoStack.length - 1);
    return UnifiedUndoHistoryTakeResult(
      history: UnifiedUndoHistory(
        userUndoLimit: userUndoLimit,
        undoStack: nextUndo,
        redoStack: nextRedo,
      ),
      entry: entry,
    );
  }
}

class UnifiedUndoHistoryTakeResult {
  const UnifiedUndoHistoryTakeResult({required this.history, this.entry});

  final UnifiedUndoHistory history;
  final UndoHistoryEntry? entry;
}
