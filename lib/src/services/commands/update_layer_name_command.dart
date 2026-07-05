import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
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
    final layer = requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
    );
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

    requireLayer(repository.requireProject(), cutId: cutId, layerId: layerId);
    repository.updateLayerName(
      cutId: cutId,
      layerId: layerId,
      name: previousName,
    );
  }
}
