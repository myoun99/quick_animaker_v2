import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../command.dart';
import '../project_repository.dart';

class RenameCutCommand implements Command {
  RenameCutCommand({
    required this.repository,
    required this.cutId,
    required this.newName,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final String newName;

  String? _previousName;
  bool _hasExecuted = false;

  @override
  String get description => 'Rename cut $cutId';

  @override
  void execute() {
    _previousName ??= _requireCut(cutId).name;
    repository.renameCut(cutId: cutId, name: newName);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousName = _previousName;
    if (!_hasExecuted || previousName == null) {
      throw StateError('Command has not been executed.');
    }

    repository.renameCut(cutId: cutId, name: previousName);
  }

  Cut _requireCut(CutId cutId) {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == cutId) {
          return cut;
        }
      }
    }

    throw StateError('Cut not found: $cutId');
  }
}
