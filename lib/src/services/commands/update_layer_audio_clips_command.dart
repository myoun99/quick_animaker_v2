import '../../models/audio_clip.dart';
import '../../models/cut_id.dart';
import '../../models/layer_id.dart';
import '../command.dart';
import '../project_lookup.dart';
import '../project_repository.dart';

/// Replaces an SE layer's audio clip list in one undo step.
class UpdateLayerAudioClipsCommand implements Command {
  UpdateLayerAudioClipsCommand({
    required this.repository,
    required this.cutId,
    required this.layerId,
    required this.audioClips,
    this.description = 'Edit audio clips',
  });

  final ProjectRepository repository;
  final CutId cutId;
  final LayerId layerId;
  final List<AudioClip> audioClips;

  @override
  final String description;

  List<AudioClip>? _previousClips;
  bool _hasExecuted = false;

  @override
  void execute() {
    final layer = requireLayer(
      repository.requireProject(),
      cutId: cutId,
      layerId: layerId,
    );
    _previousClips ??= layer.audioClips;

    repository.updateLayerAudioClips(
      cutId: cutId,
      layerId: layerId,
      audioClips: audioClips,
    );
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousClips = _previousClips;
    if (!_hasExecuted || previousClips == null) {
      throw StateError('Command has not been executed.');
    }

    requireLayer(repository.requireProject(), cutId: cutId, layerId: layerId);
    repository.updateLayerAudioClips(
      cutId: cutId,
      layerId: layerId,
      audioClips: previousClips,
    );
  }
}
