import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../command.dart';
import '../project_repository.dart';

class DuplicateLayerCommand implements Command {
  DuplicateLayerCommand({
    required this.repository,
    required this.cutId,
    required this.layer,
    required this.insertionIndex,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final Layer layer;
  final int insertionIndex;

  bool _hasExecuted = false;

  @override
  String get description => 'Duplicate layer ${layer.name}';

  @override
  void execute() {
    _requireCut();
    repository.insertLayer(cutId: cutId, layer: layer, index: insertionIndex);
    _hasExecuted = true;
  }

  @override
  void undo() {
    if (!_hasExecuted) {
      throw StateError('Command has not been executed.');
    }

    repository.deleteLayer(cutId: cutId, layerId: layer.id);
  }

  Cut _requireCut() {
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
