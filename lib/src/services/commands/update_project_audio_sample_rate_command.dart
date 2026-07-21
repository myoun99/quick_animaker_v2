import '../command.dart';
import '../project_repository.dart';

/// One project AUDIO SAMPLE RATE change as one undo step (EXPORT-AUDIO ③).
///
/// Like the frame rate, the audio rate is a project-wide axis: every
/// conform lands at it and the mixer runs at it. The caller invalidates
/// the conform cache after executing (and after undoing — the session
/// funnels both through the same history listener), so existing sounds
/// re-conform to the new rate in the background.
class UpdateProjectAudioSampleRateCommand implements Command {
  UpdateProjectAudioSampleRateCommand({
    required this.repository,
    required this.audioSampleRate,
  });

  final ProjectRepository repository;
  final int audioSampleRate;

  int? _previousRate;
  bool _hasExecuted = false;

  @override
  String get description => 'Change audio sample rate';

  @override
  void execute() {
    _previousRate ??= repository.requireProject().audioSampleRate;
    repository.updateProjectAudioSampleRate(audioSampleRate);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previousRate;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateProjectAudioSampleRate(previous);
  }
}
