import 'cut_id.dart';
import 'frame_id.dart';
import 'layer_id.dart';
import 'project_id.dart';
import 'track_id.dart';

class BrushFrameKey {
  const BrushFrameKey({
    required this.projectId,
    required this.trackId,
    required this.cutId,
    required this.layerId,
    required this.frameId,
  });

  final ProjectId projectId;
  final TrackId trackId;
  final CutId cutId;
  final LayerId layerId;
  final FrameId frameId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrushFrameKey &&
          other.projectId == projectId &&
          other.trackId == trackId &&
          other.cutId == cutId &&
          other.layerId == layerId &&
          other.frameId == frameId;

  @override
  int get hashCode => Object.hash(projectId, trackId, cutId, layerId, frameId);

  @override
  String toString() =>
      'BrushFrameKey('
      'projectId: $projectId, '
      'trackId: $trackId, '
      'cutId: $cutId, '
      'layerId: $layerId, '
      'frameId: $frameId'
      ')';
}
