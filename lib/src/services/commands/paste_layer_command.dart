import '../../models/cut_id.dart';
import '../../models/layer.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

class PasteLayerCommand implements Command {
  PasteLayerCommand({
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
  String get description => 'Paste layer ${layer.name}';

  @override
  void execute() {
    requireCut(repository.requireProject(), cutId);
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
}
