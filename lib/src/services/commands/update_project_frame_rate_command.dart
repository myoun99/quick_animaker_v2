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
///
/// EXPORT-AUDIO ④: a pulldown-pair change may carry the audio pull along
/// ([audioSpeedNumerator]/[audioSpeedDenominator] non-null) — ONE undo
/// step moves both, because they are one decision ("frame-exact") and
/// undoing half of it would reintroduce the 0.1% drift the pair removes.
class UpdateProjectFrameRateCommand implements Command {
  UpdateProjectFrameRateCommand({
    required this.repository,
    required this.frameRate,
    this.audioSpeedNumerator,
    this.audioSpeedDenominator,
  });

  final ProjectRepository repository;
  final ProjectFrameRate frameRate;
  final int? audioSpeedNumerator;
  final int? audioSpeedDenominator;

  ProjectFrameRate? _previousFrameRate;
  int? _previousSpeedNumerator;
  int? _previousSpeedDenominator;
  bool _hasExecuted = false;

  @override
  String get description => 'Change frame rate';

  @override
  void execute() {
    final project = repository.requireProject();
    _previousFrameRate ??= project.frameRate;
    _previousSpeedNumerator ??= project.audioSpeedNumerator;
    _previousSpeedDenominator ??= project.audioSpeedDenominator;
    repository.updateProjectFrameRate(frameRate);
    final speedNumerator = audioSpeedNumerator;
    final speedDenominator = audioSpeedDenominator;
    if (speedNumerator != null && speedDenominator != null) {
      repository.updateProjectAudioSpeed(speedNumerator, speedDenominator);
    }
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousFrameRate;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateProjectFrameRate(previous);
    if (audioSpeedNumerator != null && audioSpeedDenominator != null) {
      repository.updateProjectAudioSpeed(
        _previousSpeedNumerator!,
        _previousSpeedDenominator!,
      );
    }
  }
}
