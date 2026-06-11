import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateLayerKindCommand implements Command {
  UpdateLayerKindCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.kind,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final LayerKind kind;

  LayerKind? _previousKind;
  bool _hasExecuted = false;

  @override
  String get description => 'Update layer kind $layerId';

  @override
  void execute() {
    final layer = _requireLayer();
    _previousKind ??= layer.kind;

    repository.updateLayerKind(cutId: cutId, layerId: layerId, kind: kind);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousKind = _previousKind;
    if (!_hasExecuted || previousKind == null) {
      throw StateError('Command has not been executed.');
    }

    _requireLayer();
    repository.updateLayerKind(
      cutId: cutId,
      layerId: layerId,
      kind: previousKind,
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
