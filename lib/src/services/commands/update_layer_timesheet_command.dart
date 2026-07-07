import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

class UpdateLayerTimesheetCommand implements Command {
  UpdateLayerTimesheetCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.onTimesheet,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final bool onTimesheet;

  bool? _previousOnTimesheet;
  bool _hasExecuted = false;

  @override
  String get description => 'Update layer timesheet flag $layerId';

  @override
  void execute() {
    final layer = requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
    );
    _previousOnTimesheet ??= layer.onTimesheet;

    repository.updateLayerTimesheet(
      cutId: cutId,
      layerId: layerId,
      onTimesheet: onTimesheet,
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousOnTimesheet = _previousOnTimesheet;
    if (!_hasExecuted || previousOnTimesheet == null) {
      throw StateError('Command has not been executed.');
    }

    requireLayer(repository.requireProject(), cutId: cutId, layerId: layerId);
    repository.updateLayerTimesheet(
      cutId: cutId,
      layerId: layerId,
      onTimesheet: previousOnTimesheet,
    );
  }
}
