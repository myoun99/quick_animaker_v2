import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../../models/project.dart';
import '../command.dart';
import '../project_repository.dart';

class AddLayerCommand implements Command {
  AddLayerCommand({
    required this.repository,
    required this.cutId,
    required this.layer,
    this.insertionIndex,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final Layer layer;
  final int? insertionIndex;

  Project? _previousProject;

  @override
  String get description => 'Add layer ${layer.name}';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.insertLayer(
      cutId: cutId,
      layer: layer,
      index: insertionIndex,
    );
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
