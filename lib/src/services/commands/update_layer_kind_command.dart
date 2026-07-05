import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../command.dart';
import '../project_lookup.dart';
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
    final layer = requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
    );
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

    requireLayer(repository.requireProject(), cutId: cutId, layerId: layerId);
    repository.updateLayerKind(
      cutId: cutId,
      layerId: layerId,
      kind: previousKind,
    );
  }
}
