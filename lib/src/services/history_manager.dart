import 'command.dart';

class HistoryManager {
  final List<Command> _undoStack = <Command>[];
  final List<Command> _redoStack = <Command>[];

  bool get canUndo => _undoStack.isNotEmpty;

  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;

  int get redoCount => _redoStack.length;

  void execute(Command command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) {
      throw StateError('No commands to undo.');
    }

    final command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
  }

  void redo() {
    if (_redoStack.isEmpty) {
      throw StateError('No commands to redo.');
    }

    final command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
