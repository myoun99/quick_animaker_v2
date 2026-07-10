abstract class Command {
  String get description;

  void execute();

  void undo();
}

/// Several commands as ONE undo step: executes in order, undoes in
/// reverse. For flows where one user action legitimately touches two
/// stores (e.g. adding an instruction also writes its memo shorthand into
/// the cut note) without splitting the undo.
class CompositeCommand implements Command {
  CompositeCommand({required this.description, required this.commands});

  @override
  final String description;

  final List<Command> commands;

  @override
  void execute() {
    for (final command in commands) {
      command.execute();
    }
  }

  @override
  void undo() {
    for (final command in commands.reversed) {
      command.undo();
    }
  }
}
