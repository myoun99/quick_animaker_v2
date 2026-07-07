import '../../models/camera_instruction.dart';
import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Replaces an instruction row's whole span map in one undo step (edits
/// are computed as pure functions on the map, then committed here).
class UpdateLayerInstructionsCommand implements Command {
  UpdateLayerInstructionsCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.instructions,
    this.description = 'Edit instructions',
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final Map<int, InstructionEvent> instructions;

  @override
  final String description;

  Map<int, InstructionEvent>? _previousInstructions;
  bool _hasExecuted = false;

  @override
  void execute() {
    final layer = requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
    );
    _previousInstructions ??= layer.instructions;

    repository.updateLayerInstructions(
      cutId: cutId,
      layerId: layerId,
      instructions: instructions,
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousInstructions = _previousInstructions;
    if (!_hasExecuted || previousInstructions == null) {
      throw StateError('Command has not been executed.');
    }

    requireLayer(repository.requireProject(), cutId: cutId, layerId: layerId);
    repository.updateLayerInstructions(
      cutId: cutId,
      layerId: layerId,
      instructions: previousInstructions,
    );
  }
}
