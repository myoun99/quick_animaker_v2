import '../../models/cut_id.dart';
import '../command.dart';
import '../project_lookup.dart';
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
    _previousName ??= requireCut(repository.requireProject(), cutId).name;
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
}
