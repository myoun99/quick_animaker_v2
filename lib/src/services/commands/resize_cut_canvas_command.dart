import '../../models/canvas_size.dart';
import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../command.dart';
import '../project_repository.dart';

class ResizeCutCanvasCommand implements Command {
  ResizeCutCanvasCommand({
    required this.repository,
    required this.cutId,
    required this.canvasSize,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final CanvasSize canvasSize;

  Project? _previousProject;

  @override
  String get description =>
      'Resize canvas to ${canvasSize.width}x${canvasSize.height}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.updateCutCanvasSize(cutId: cutId, canvasSize: canvasSize);
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
