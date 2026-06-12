import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateLayerNameCommand implements Command {
  UpdateLayerNameCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.name,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final String name;

  String? _previousName;
  bool _hasExecuted = false;

  @override
  String get description => 'Update layer name $layerId';

  @override
  void execute() {
    final layer = _requireLayer();
    _previousName ??= layer.name;

    repository.updateLayerName(cutId: cutId, layerId: layerId, name: name);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousName = _previousName;
    if (!_hasExecuted || previousName == null) {
      throw StateError('Command has not been executed.');
    }

    _requireLayer();
    repository.updateLayerName(
      cutId: cutId,
      layerId: layerId,
      name: previousName,
    );
  }

  Layer _requireLayer() {
    final cut = _requireCut(cutId);
    for (final layer in cut.layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }

    throw StateError('Layer not found in cut $cutId: $layerId');
  }

  Cut _requireCut(CutId cutId) {
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
