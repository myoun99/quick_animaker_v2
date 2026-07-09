import '../../models/cut_id.dart';
import '../../models/project.dart';
import '../../models/transform_track.dart';
import '../command.dart';
import '../project_repository.dart';

/// Replaces a cut's CUT-level transform track (the V-track's track
/// transforms — cut fades key the opacity lane) in one undo step.
class UpdateCutTransformCommand implements Command {
  UpdateCutTransformCommand({
    required this.repository,
    required this.cutId,
    required this.transformTrack,
    required this.description,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final TransformTrack transformTrack;

  @override
  final String description;

  Project? _previousProject;

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.updateCutTransform(cutId: cutId, transformTrack: transformTrack);
  }

  @override
  void undo() {
    final previousProject = _previousProject;
    if (previousProject == null) {
      throw StateError('Command has not been executed.');
    }

    repository.replaceProject(previousProject);
  }
}
