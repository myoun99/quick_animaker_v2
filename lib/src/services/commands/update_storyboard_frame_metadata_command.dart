import '../../models/cut.dart';
import '../../models/cut_id.dart';
import '../../models/frame.dart';
import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/storyboard_frame_metadata.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateStoryboardFrameMetadataCommand implements Command {
  UpdateStoryboardFrameMetadataCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.frameId,
    required this.metadata,
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final FrameId frameId;
  final StoryboardFrameMetadata metadata;

  StoryboardFrameMetadata? _previousMetadata;
  bool _hasExecuted = false;

  @override
  String get description => 'Update storyboard frame metadata $frameId';

  @override
  void execute() {
    final target = _requireTarget();
    _previousMetadata ??= target.frame.storyboardMetadata;

    repository.updateFrameStoryboardMetadata(
      cutId: cutId,
      layerId: layerId,
      frameId: frameId,
      metadata: metadata,
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousMetadata = _previousMetadata;
    if (!_hasExecuted || previousMetadata == null) {
      throw StateError('Command has not been executed.');
    }

    _requireTarget();
    repository.updateFrameStoryboardMetadata(
      cutId: cutId,
      layerId: layerId,
      frameId: frameId,
      metadata: previousMetadata,
    );
  }

  _StoryboardFrameTarget _requireTarget() {
    final project = repository.requireProject();
    Cut? targetCut;
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == cutId) {
          targetCut = cut;
          break;
        }
      }
      if (targetCut != null) {
        break;
      }
    }

    if (targetCut == null) {
      throw StateError('Cut not found: $cutId');
    }

    Layer? targetLayer;
    for (final layer in targetCut.layers) {
      if (layer.id == layerId) {
        targetLayer = layer;
        break;
      }
    }

    if (targetLayer == null) {
      throw StateError('Layer not found in cut $cutId: $layerId');
    }
    if (targetLayer.kind != LayerKind.storyboard) {
      throw StateError('Layer is not a storyboard layer: $layerId');
    }

    Frame? targetFrame;
    for (final frame in targetLayer.frames) {
      if (frame.id == frameId) {
        targetFrame = frame;
        break;
      }
    }

    if (targetFrame == null) {
      throw StateError('Frame not found in layer $layerId: $frameId');
    }

    return _StoryboardFrameTarget(frame: targetFrame);
  }
}

class _StoryboardFrameTarget {
  const _StoryboardFrameTarget({required this.frame});

  final Frame frame;
}
