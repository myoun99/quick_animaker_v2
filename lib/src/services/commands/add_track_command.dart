import '../../models/project.dart';
import '../../models/track.dart';
import '../command.dart';
import '../project_repository.dart';

class AddTrackCommand implements Command {
  AddTrackCommand({required this.repository, required this.track});

  final ProjectRepository repository;
  final Track track;

  Project? _previousProject;

  @override
  String get description => 'Add track ${track.name}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.addTrack(track);
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
