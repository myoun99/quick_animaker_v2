import 'package:flutter/foundation.dart';

import 'command.dart';

/// The undo/redo stacks. A [ChangeNotifier] so stack-state consumers (the
/// app bar's undo/redo buttons) can subscribe directly: brush strokes
/// execute here from the canvas WITHOUT a session notify, so nothing else
/// would ever tell them a stroke landed.
class HistoryManager extends ChangeNotifier {
  HistoryManager({this.maxEntries = defaultMaxEntries})
    : assert(maxEntries > 0);

  /// Undo-depth cap. The stack previously grew for the whole session —
  /// brush strokes land here at drawing speed, so long sessions pinned
  /// thousands of command objects (an accumulation source behind the
  /// progressive brush lag). Deep enough that nobody undoes past it in
  /// practice; the brush coordinator's own bitmap history is far shorter
  /// anyway.
  static const int defaultMaxEntries = 200;

  final int maxEntries;

  final List<Command> _undoStack = <Command>[];
  final List<Command> _redoStack = <Command>[];

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;

  int get redoCount => _redoStack.length;

  void execute(Command command) {
    command.execute();
    _undoStack.add(command);
    if (_undoStack.length > maxEntries) {
      // The oldest commands fall off the deep end, PS-style.
      _undoStack.removeRange(0, _undoStack.length - maxEntries);
    }
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      throw StateError('No commands to undo.');
    }

    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) {
      throw StateError('No commands to redo.');
    }

    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
    notifyListeners();
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}
