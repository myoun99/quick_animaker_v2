import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project.dart';
import '../command.dart';
import '../project_repository.dart';

/// Creates one cel on an ATTACH layer and links it to a base cel (W5) —
/// the attach-row counterpart of "Create Drawing": the new cel shows
/// wherever the base exposes [baseFrameId], now and after any base timing
/// edit (cell-level link).
class CreateAttachedCelCommand implements Command {
  CreateAttachedCelCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.baseFrameId,
    required this.frameId,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;

  /// The BASE layer's cel the new attach cel rides.
  final FrameId baseFrameId;

  /// The new attach cel's id.
  final FrameId frameId;

  Project? _previousProject;

  @override
  String get description => 'Create attached cel';

  @override
  void execute() {
    _previousProject = repository.requireProject();
    repository.updateLayer(
      layerId: layerId,
      update: (layer) {
        if (layer.attachedToLayerId == null) {
          throw StateError('Layer is not an attach layer: $layerId');
        }
        if (layer.baseFrameLinks.containsKey(baseFrameId)) {
          throw StateError(
            'Base cel already linked on attach layer $layerId: $baseFrameId',
          );
        }
        return layer.copyWith(
          frames: [
            ...layer.frames,
            Frame(id: frameId, duration: 1, strokes: const []),
          ],
          baseFrameLinks: {...layer.baseFrameLinks, baseFrameId: frameId},
        );
      },
    );
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
