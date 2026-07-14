abstract class Command {
  String get description;

  void execute();

  void undo();
}

/// Commands that retain SURFACE SNAPSHOTS as their undo payload (R19
/// P3b) report their approximate weight so the history stack can
/// byte-trim its deep end — a run of full-canvas fills at 8000² retains
/// ~256MB per entry, which the entry-count cap alone would never bound.
abstract interface class RetainedBytesCommand {
  int get estimatedRetainedBytes;
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
