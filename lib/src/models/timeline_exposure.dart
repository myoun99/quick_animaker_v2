import 'frame_id.dart';
import 'timeline_exposure_type.dart';

/// One authored timeline entry: either a drawing block start (frame + an
/// explicit hold length in frames) or an inbetween mark.
///
/// The hold length lives HERE, not on `Frame.duration`: linked uses of the
/// same frame at different timeline positions can hold for different
/// lengths. A drawing at index `s` covers `[s, s + length)`; indexes not
/// covered by any drawing are empty ("X" cells) without any entry existing.
/// Marks never form blocks and never carry a frame — the canvas shows
/// whatever the covering block shows (or nothing when the mark sits in
/// empty space).
class TimelineExposure {
  const TimelineExposure.drawing(FrameId this.frameId, {required int this.length})
    : type = TimelineExposureType.drawing,
      assert(length >= 1, 'Drawing exposure length must be at least 1.');

  const TimelineExposure.mark()
    : type = TimelineExposureType.mark,
      frameId = null,
      length = null;

  final TimelineExposureType type;
  final FrameId? frameId;

  /// Hold length in frames; non-null iff [type] is drawing.
  final int? length;

  bool get isDrawing => type == TimelineExposureType.drawing;
  bool get isMark => type == TimelineExposureType.mark;

  TimelineExposure copyWith({FrameId? frameId, int? length}) {
    if (isMark) {
      return this;
    }
    return TimelineExposure.drawing(
      frameId ?? this.frameId!,
      length: length ?? this.length!,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    if (frameId != null) 'frameId': frameId!.toJson(),
    if (length != null) 'length': length,
  };

  /// Decodes the CURRENT format only. Legacy entries (`blank` type, drawing
  /// entries without `length`) are migrated in `Layer.fromJson`, which
  /// needs whole-timeline context to derive lengths.
  factory TimelineExposure.fromJson(Map<String, dynamic> json) {
    final type = TimelineExposureType.fromJson(json['type']);
    if (type == TimelineExposureType.mark) {
      if (json['frameId'] != null) {
        throw const FormatException('Mark timeline entry cannot have frameId.');
      }
      return const TimelineExposure.mark();
    }

    final frameIdJson = json['frameId'];
    final length = json['length'];
    if (frameIdJson == null || length is! int || length < 1) {
      throw const FormatException(
        'Drawing timeline entry requires frameId and a positive length.',
      );
    }
    return TimelineExposure.drawing(
      FrameId.fromJson(frameIdJson as Map<String, dynamic>),
      length: length,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineExposure &&
          other.type == type &&
          other.frameId == frameId &&
          other.length == length;

  @override
  int get hashCode => Object.hash(type, frameId, length);

  @override
  String toString() =>
      'TimelineExposure(type: $type, frameId: $frameId, length: $length)';
}
