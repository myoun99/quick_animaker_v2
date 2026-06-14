import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_repository.dart';

class DeleteLayerCommand implements Command {
  DeleteLayerCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;

  Layer? _deletedLayer;
  int? _deletedIndex;
  bool _hasExecuted = false;

  @override
  String get description => 'Delete layer $layerId';

  @override
  void execute() {
    final cut = _requireCut();
    if (cut.layers.length <= 1) {
      throw StateError('Cannot delete the last layer in cut $cutId.');
    }

    final index = cut.layers.indexWhere((layer) => layer.id == layerId);
    if (index == -1) {
      throw StateError('Layer not found in cut $cutId: $layerId');
    }

    _deletedLayer ??= cut.layers[index];
    _deletedIndex ??= index;
    repository.deleteLayer(cutId: cutId, layerId: layerId);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final deletedLayer = _deletedLayer;
    final deletedIndex = _deletedIndex;
    if (!_hasExecuted || deletedLayer == null || deletedIndex == null) {
      throw StateError('Command has not been executed.');
    }

    repository.insertLayer(
      cutId: cutId,
      layer: deletedLayer,
      index: deletedIndex,
    );
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
