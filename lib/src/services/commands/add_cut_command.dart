import '../../models/cut.dart';
import '../../models/project.dart';
import '../../models/track_id.dart';
import '../command.dart';
import '../project_repository.dart';

class AddCutCommand implements Command {
  AddCutCommand({
    required this.repository,
    required this.trackId,
    required this.cut,
  });

  final ProjectRepository repository;
  final TrackId trackId;
  final Cut cut;

  Project? _previousProject;

  @override
  String get description => 'Add cut ${cut.name}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.addCut(trackId: trackId, cut: cut);
  }

  @override
  void undo() {
    final previousProject = _previousProject;
    if (previousProject == null) {
      throw StateError('Command has not been executed.');
    }

    repository.replaceProject(previousProject);
  }
}
