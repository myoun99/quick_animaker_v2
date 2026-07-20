import '../command.dart';
import '../project_repository.dart';

/// One project FRAME RATE change as one undo step (R26 #32).
///
/// The rate is a PROJECT-wide axis — the ruler's second boundaries, the
/// timesheet's per-second rows, playback timing and audio placement all
/// read it — so it lives on the project, never per cut.
class UpdateProjectFpsCommand implements Command {
  UpdateProjectFpsCommand({required this.repository, required this.fps});

  final ProjectRepository repository;
  final int fps;

  int? _previousFps;
  bool _hasExecuted = false;

  @override
  String get description => 'Change frame rate';

  @override
  void execute() {
    _previousFps ??= repository.requireProject().fps;
    repository.updateProjectFps(fps);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousFps;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateProjectFps(previous);
  }
}
