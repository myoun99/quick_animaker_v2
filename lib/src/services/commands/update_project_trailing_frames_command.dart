import '../command.dart';
import '../project_repository.dart';

/// One movie-length change (UI-R20 #3: the storyboard end line drags the
/// project's TRAILING GAP) as one undo step.
class UpdateProjectTrailingFramesCommand implements Command {
  UpdateProjectTrailingFramesCommand({
    required this.repository,
    required this.trailingFrames,
  });

  final ProjectRepository repository;
  final int trailingFrames;

  int? _previousTrailingFrames;
  bool _hasExecuted = false;

  @override
  String get description => 'Change movie length';

  @override
  void execute() {
    _previousTrailingFrames ??= repository.requireProject().trailingFrames;
    repository.updateTrailingFrames(trailingFrames);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousTrailingFrames;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateTrailingFrames(previous);
  }
}
