import '../../models/cut_id.dart';
import '../../models/track_id.dart';
import '../command.dart';
import '../project_repository.dart';

class ReorderCutCommand implements Command {
  ReorderCutCommand({
    required this.repository,
    required this.trackId,
    required this.cutId,
    required this.newIndex,
  });

  final ProjectRepository repository;
  final TrackId trackId;
  final CutId cutId;
  final int newIndex;

  int? _originalIndex;
  bool _hasExecuted = false;

  @override
  String get description => 'Reorder cut $cutId';

  @override
  void execute() {
    _originalIndex ??= _indexOfCut();
    repository.reorderCut(trackId: trackId, cutId: cutId, newIndex: newIndex);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final originalIndex = _originalIndex;
    if (!_hasExecuted || originalIndex == null) {
      throw StateError('Command has not been executed.');
    }

    repository.reorderCut(
      trackId: trackId,
      cutId: cutId,
      newIndex: originalIndex,
    );
  }

  int _indexOfCut() {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      if (track.id != trackId) {
        continue;
      }

      final index = track.cuts.indexWhere((cut) => cut.id == cutId);
      if (index == -1) {
        throw StateError('Cut not found in track $trackId: $cutId');
      }

      return index;
    }

    throw StateError('Track not found: $trackId');
  }
}
