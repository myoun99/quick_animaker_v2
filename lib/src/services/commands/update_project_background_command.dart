import '../../models/project_background.dart';
import '../command.dart';
import '../project_repository.dart';

/// One project-background change (R10-⑥) as one undo step.
class UpdateProjectBackgroundCommand implements Command {
  UpdateProjectBackgroundCommand({
    required this.repository,
    required this.background,
  });

  final ProjectRepository repository;
  final ProjectBackground background;

  ProjectBackground? _previousBackground;
  bool _hasExecuted = false;

  @override
  String get description => 'Change project background';

  @override
  void execute() {
    _previousBackground ??= repository.requireProject().background;
    repository.updateProjectBackground(background);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousBackground;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateProjectBackground(previous);
  }
}
