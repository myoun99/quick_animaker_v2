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
  const TimelineExposure.drawing(
    FrameId this.frameId, {
    required int this.length,
    this.ghost = false,
    this.repeatRegionId,
  }) : type = TimelineExposureType.drawing,
       assert(length >= 1, 'Drawing exposure length must be at least 1.');

  const TimelineExposure.mark()
    : type = TimelineExposureType.mark,
      frameId = null,
      length = null,
      ghost = false,
      repeatRegionId = null;

  final TimelineExposureType type;
  final FrameId? frameId;

  /// Hold length in frames; non-null iff [type] is drawing.
  final int? length;

  /// A DERIVED repeat instance (UI-R8, TVP-style repeat): synthesized by
  /// the repeat rederive pass from its region's source span — never
  /// authored directly, wiped and rebuilt on every timeline edit. Ghosts
  /// share the source's frameId (drawing at a ghost index edits the
  /// source) and render dimmed on the timeline cells only; playback and
  /// the canvas treat them as ordinary exposures.
  final bool ghost;

  /// The owning [TimelineRepeatRegion.id] when [ghost] is true.
  final String? repeatRegionId;

  bool get isDrawing => type == TimelineExposureType.drawing;
  bool get isMark => type == TimelineExposureType.mark;

  TimelineExposure copyWith({FrameId? frameId, int? length}) {
    if (isMark) {
      return this;
    }
    return TimelineExposure.drawing(
      frameId ?? this.frameId!,
      length: length ?? this.length!,
      ghost: ghost,
      repeatRegionId: repeatRegionId,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    if (frameId != null) 'frameId': frameId!.toJson(),
    if (length != null) 'length': length,
    if (ghost) 'ghost': true,
    if (repeatRegionId != null) 'repeatRegionId': repeatRegionId,
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
      ghost: json['ghost'] == true,
      repeatRegionId: json['repeatRegionId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineExposure &&
          other.type == type &&
          other.frameId == frameId &&
          other.length == length &&
          other.ghost == ghost &&
          other.repeatRegionId == repeatRegionId;

  @override
  int get hashCode => Object.hash(type, frameId, length, ghost, repeatRegionId);

  @override
  String toString() =>
      'TimelineExposure(type: $type, frameId: $frameId, length: $length'
      '${ghost ? ', ghost($repeatRegionId)' : ''})';
}
