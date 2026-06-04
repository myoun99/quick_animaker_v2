import '../../models/layer.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateLayerTimelineCommand implements Command {
  UpdateLayerTimelineCommand({
    required this.repository,
    required this.before,
    required this.after,
  });

  final ProjectRepository repository;
  final Layer before;
  final Layer after;

  @override
  String get description => 'Update layer timeline ${after.id}';

  @override
  void execute() {
    repository.replaceLayer(layer: after);
  }

  @override
  void undo() {
    repository.replaceLayer(layer: before);
  }
}
