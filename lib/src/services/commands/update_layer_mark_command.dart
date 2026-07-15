import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

class UpdateLayerMarkCommand implements Command {
  UpdateLayerMarkCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.mark,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final LayerMark mark;

  LayerMark? _previousMark;
  bool _hasExecuted = false;

  @override
  String get description => 'Update layer mark $layerId';

  @override
  void execute() {
    // Anywhere lookup: track-owned SE rows are not in the cut's layer list
    // but carry marks like every row (unified layer controls).
    final layer = requireLayerAnywhere(repository.requireProject(), layerId);
    _previousMark ??= layer.mark;

    repository.updateLayerMark(cutId: cutId, layerId: layerId, mark: mark);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousMark = _previousMark;
    if (!_hasExecuted || previousMark == null) {
      throw StateError('Command has not been executed.');
    }

    requireLayerAnywhere(repository.requireProject(), layerId);
    repository.updateLayerMark(
      cutId: cutId,
      layerId: layerId,
      mark: previousMark,
    );
  }
}
