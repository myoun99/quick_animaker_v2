import 'frame_id.dart';
import 'timeline_exposure_type.dart';

class TimelineExposure {
  const TimelineExposure({required this.type, this.frameId})
    : assert(
        type != TimelineExposureType.drawing || frameId != null,
        'Drawing exposure requires a frameId.',
      ),
      assert(
        type != TimelineExposureType.blank || frameId == null,
        'Blank exposure cannot have a frameId.',
      );

  factory TimelineExposure.drawing(FrameId frameId) {
    return TimelineExposure(type: TimelineExposureType.drawing, frameId: frameId);
  }

  const TimelineExposure.blank()
    : type = TimelineExposureType.blank,
      frameId = null;

  final TimelineExposureType type;
  final FrameId? frameId;

  TimelineExposure copyWith({TimelineExposureType? type, FrameId? frameId}) {
    final nextType = type ?? this.type;
    final nextFrameId = nextType == TimelineExposureType.blank
        ? null
        : frameId ?? this.frameId;
    return TimelineExposure(type: nextType, frameId: nextFrameId);
  }

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    if (frameId != null) 'frameId': frameId!.toJson(),
  };

  factory TimelineExposure.fromJson(Map<String, dynamic> json) {
    final type = TimelineExposureType.fromJson(json['type']);
    final frameIdJson = json['frameId'];
    final frameId = frameIdJson == null
        ? null
        : FrameId.fromJson(frameIdJson as Map<String, dynamic>);

    if (type == TimelineExposureType.drawing && frameId == null) {
      throw const FormatException('Drawing timeline exposure requires frameId.');
    }
    if (type == TimelineExposureType.blank && frameId != null) {
      throw const FormatException('Blank timeline exposure cannot have frameId.');
    }

    return TimelineExposure(type: type, frameId: frameId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineExposure && other.type == type && other.frameId == frameId;

  @override
  int get hashCode => Object.hash(type, frameId);

  @override
  String toString() => 'TimelineExposure(type: $type, frameId: $frameId)';
}
