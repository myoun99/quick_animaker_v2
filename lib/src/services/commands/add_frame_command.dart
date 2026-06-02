import '../../models/frame.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';
import '../command.dart';
import '../project_repository.dart';

class AddFrameCommand implements Command {
  AddFrameCommand({
    required this.repository,
    required this.layerId,
    required this.frame,
  });

  final ProjectRepository repository;
  final LayerId layerId;
  final Frame frame;

  Project? _previousProject;

  @override
  String get description => 'Add frame ${frame.id}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.addFrame(layerId: layerId, frame: frame);
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
