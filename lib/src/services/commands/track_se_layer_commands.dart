import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/track_id.dart';
import '../command.dart';
import '../project_repository.dart';

/// Adds one SE row to a track's track-owned SE list (one undo step).
class AddTrackSeLayerCommand implements Command {
  AddTrackSeLayerCommand({
    required this.repository,
    required this.trackId,
    required this.layer,
    this.insertionIndex,
  });

  final ProjectRepository repository;
  final TrackId trackId;
  final Layer layer;
  final int? insertionIndex;

  @override
  String get description => 'Add SE row ${layer.name}';

  @override
  void execute() {
    repository.insertTrackSeLayer(
      trackId: trackId,
      layer: layer,
      index: insertionIndex,
    );
  }

  @override
  void undo() {
    repository.removeTrackSeLayer(trackId: trackId, layerId: layer.id);
  }
}

/// Removes one SE row from a track (one undo step; the row's content —
/// timeline, frames, sounds — restores on undo).
class RemoveTrackSeLayerCommand implements Command {
  RemoveTrackSeLayerCommand({
    required this.repository,
    required this.trackId,
    required this.layerId,
  });

  final ProjectRepository repository;
  final TrackId trackId;
  final LayerId layerId;

  Layer? _removed;
  int? _removedIndex;

  @override
  String get description => 'Delete SE row';

  @override
  void execute() {
    final project = repository.requireProject();
    for (final track in project.tracks) {
      if (track.id != trackId) {
        continue;
      }
      _removedIndex = track.seLayers.indexWhere((layer) => layer.id == layerId);
      if (_removedIndex! >= 0) {
        _removed = track.seLayers[_removedIndex!];
      }
      break;
    }
    if (_removed == null) {
      throw StateError('SE layer not found on track $trackId: $layerId');
    }
    repository.removeTrackSeLayer(trackId: trackId, layerId: layerId);
  }

  @override
  void undo() {
    final removed = _removed;
    final index = _removedIndex;
    if (removed == null || index == null) {
      throw StateError('Command has not been executed.');
    }
    repository.insertTrackSeLayer(
      trackId: trackId,
      layer: removed,
      index: index,
    );
  }
}
