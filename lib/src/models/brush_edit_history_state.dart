import 'brush_edit_history_entry.dart';

class BrushEditHistoryState {
  BrushEditHistoryState({
    Iterable<BrushEditHistoryEntry> undoEntries = const [],
    Iterable<BrushEditHistoryEntry> redoEntries = const [],
  }) : _undoEntries = List<BrushEditHistoryEntry>.unmodifiable(undoEntries),
       _redoEntries = List<BrushEditHistoryEntry>.unmodifiable(redoEntries);

  final List<BrushEditHistoryEntry> _undoEntries;
  final List<BrushEditHistoryEntry> _redoEntries;

  List<BrushEditHistoryEntry> get undoEntries => _undoEntries;

  List<BrushEditHistoryEntry> get redoEntries => _redoEntries;

  bool get canUndo => _undoEntries.isNotEmpty;

  bool get canRedo => _redoEntries.isNotEmpty;

  bool get isEmpty => _undoEntries.isEmpty && _redoEntries.isEmpty;

  int get undoCount => _undoEntries.length;

  int get redoCount => _redoEntries.length;

  BrushEditHistoryEntry? get latestUndoEntry =>
      _undoEntries.isEmpty ? null : _undoEntries.last;

  BrushEditHistoryEntry? get latestRedoEntry =>
      _redoEntries.isEmpty ? null : _redoEntries.last;

  BrushEditHistoryState copyWith({
    Iterable<BrushEditHistoryEntry>? undoEntries,
    Iterable<BrushEditHistoryEntry>? redoEntries,
  }) {
    return BrushEditHistoryState(
      undoEntries: undoEntries ?? _undoEntries,
      redoEntries: redoEntries ?? _redoEntries,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushEditHistoryState &&
          _listEquals(other._undoEntries, _undoEntries) &&
          _listEquals(other._redoEntries, _redoEntries);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(_undoEntries),
    Object.hashAll(_redoEntries),
  );

  @override
  String toString() =>
      'BrushEditHistoryState(undoEntries: $_undoEntries, '
      'redoEntries: $_redoEntries)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i += 1) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
