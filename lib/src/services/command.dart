abstract class Command {
  String get description;

  void execute();

  void undo();
}
