import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Toggles a layer's fill-reference flag (R20-C2) — one undo step.
class UpdateLayerFillReferenceCommand implements Command {
  UpdateLayerFillReferenceCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.isFillReference,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final bool isFillReference;

  bool? _previous;
  bool _hasExecuted = false;

  @override
  String get description => 'Update layer fill-reference flag $layerId';

  @override
  void execute() {
    // Anywhere lookup, like the mark/timesheet flags: layer ids are
    // globally unique and track-owned SE rows reach the same commands.
    final layer = requireLayerAnywhere(repository.requireProject(), layerId);
    _previous ??= layer.isFillReference;

    repository.updateLayerFillReference(
      cutId: cutId,
      layerId: layerId,
      isFillReference: isFillReference,
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previous = _previous;
    if (!_hasExecuted || previous == null) {
      throw StateError('Command has not been executed.');
    }

    requireLayerAnywhere(repository.requireProject(), layerId);
    repository.updateLayerFillReference(
      cutId: cutId,
      layerId: layerId,
      isFillReference: previous,
    );
  }
}
