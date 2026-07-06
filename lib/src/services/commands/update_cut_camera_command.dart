import '../../models/cut_camera.dart';
import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateCutCameraCommand implements Command {
  UpdateCutCameraCommand({
    required this.repository,
    required this.cutId,
    required this.camera,
    required this.description,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final CutCamera camera;

  @override
  final String description;

  Project? _previousProject;

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.updateCutCamera(cutId: cutId, camera: camera);
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
