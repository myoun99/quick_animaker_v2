import '../../models/camera_instruction.dart';
import '../command.dart';
import '../project_repository.dart';

/// Replaces the project's instruction vocabulary in one undo step.
class UpdateCameraInstructionSetCommand implements Command {
  UpdateCameraInstructionSetCommand({
    required this.repository,
    required this.instructionSet,
  });

  final ProjectRepository repository;
  final CameraInstructionSet instructionSet;

  CameraInstructionSet? _previousSet;
  bool _hasExecuted = false;

  @override
  String get description => 'Edit instruction set';

  @override
  void execute() {
    _previousSet ??= repository.requireProject().cameraInstructions;
    repository.updateCameraInstructionSet(instructionSet);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousSet = _previousSet;
    if (!_hasExecuted || previousSet == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateCameraInstructionSet(previousSet);
  }
}
