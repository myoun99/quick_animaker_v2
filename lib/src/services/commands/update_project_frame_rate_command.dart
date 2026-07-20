import '../../models/project_frame_rate.dart';
import '../command.dart';
import '../project_repository.dart';

/// One project FRAME RATE change as one undo step (R26 #32).
///
/// The rate is a PROJECT-wide axis — the ruler's second boundaries, the
/// timesheet's per-second rows, playback timing and audio placement all
/// read it — so it lives on the project, never per cut.
///
/// RT: the payload is the exact rational rate, not an int, so moving a
/// project to 23.976 is the same single undoable write as moving it to 24.
class UpdateProjectFrameRateCommand implements Command {
  UpdateProjectFrameRateCommand({
    required this.repository,
    required this.frameRate,
  });

  final ProjectRepository repository;
  final ProjectFrameRate frameRate;

  ProjectFrameRate? _previousFrameRate;
  bool _hasExecuted = false;

  @override
  String get description => 'Change frame rate';

  @override
  void execute() {
    _previousFrameRate ??= repository.requireProject().frameRate;
    repository.updateProjectFrameRate(frameRate);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousFrameRate;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateProjectFrameRate(previous);
  }
}
