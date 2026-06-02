import '../../models/frame_id.dart';
import '../../models/project.dart';
import '../../models/stroke.dart';
import '../command.dart';
import '../project_repository.dart';

class AddStrokeCommand implements Command {
  AddStrokeCommand({
    required this.repository,
    required this.frameId,
    required this.stroke,
  });

  final ProjectRepository repository;
  final FrameId frameId;
  final Stroke stroke;

  Project? _previousProject;

  @override
  String get description => 'Add stroke ${stroke.id}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.addStroke(frameId: frameId, stroke: stroke);
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
