import 'frame_id.dart';
import 'timeline_exposure_type.dart';

/// One authored timeline entry: a drawing block start (frame + an explicit
/// hold length in frames).
///
/// The hold length lives HERE, not on `Frame.duration`: linked uses of the
/// same frame at different timeline positions can hold for different
/// lengths. A drawing at index `s` covers `[s, s + length)`; indexes not
/// covered by any drawing are empty ("X" cells) without any entry existing.
///
/// UI-R9 #8: the inbetween DOTS (중간나누기 ●) are BLOCK-OWNED now —
/// [breakdownOffsets] inside the entry, so they ride every move/copy of
/// the block for free. The standalone `mark` entry type is retired
/// (free-floating dots on empty cells are no longer a thing; want one
/// there, author an unnamed frame). Legacy mark entries migrate on load:
/// covered marks fold into their block's offsets, free marks drop.
class TimelineExposure {
  const TimelineExposure.drawing(
    FrameId this.frameId, {
    required int this.length,
    this.ghost = false,
    this.repeatRegionId,
    this.breakdownOffsets = const [],
  }) : type = TimelineExposureType.drawing,
       assert(length >= 1, 'Drawing exposure length must be at least 1.');

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

  /// The inbetween DOTS (중간나누기 ●) inside this block, as offsets from
  /// the block start — sorted, unique, each in `1..length-1` (offset 0 is
  /// the drawing itself). Owned by the block: moves/copies carry them,
  /// and a length shrink through [copyWith] drops the offsets it cut off
  /// ([copyWith] and [fromJson] normalize; direct const construction
  /// trusts the caller).
  final List<int> breakdownOffsets;

  static List<int> _normalizedOffsets(List<int> offsets, int length) {
    if (offsets.isEmpty) {
      return const [];
    }
    final kept = offsets.where((offset) => offset >= 1 && offset < length)
        .toSet()
        .toList()
      ..sort();
    return List.unmodifiable(kept);
  }

  bool get isDrawing => type == TimelineExposureType.drawing;

  bool hasBreakdownAt(int offset) => breakdownOffsets.contains(offset);

  TimelineExposure copyWith({
    FrameId? frameId,
    int? length,
    List<int>? breakdownOffsets,
  }) {
    final nextLength = length ?? this.length!;
    return TimelineExposure.drawing(
      frameId ?? this.frameId!,
      length: nextLength,
      ghost: ghost,
      repeatRegionId: repeatRegionId,
      // Normalization clamps offsets to the (possibly new) length — a
      // shrink drops what it cut off.
      breakdownOffsets: _normalizedOffsets(
        breakdownOffsets ?? this.breakdownOffsets,
        nextLength,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.toJson(),
    if (frameId != null) 'frameId': frameId!.toJson(),
    if (length != null) 'length': length,
    if (ghost) 'ghost': true,
    if (repeatRegionId != null) 'repeatRegionId': repeatRegionId,
    if (breakdownOffsets.isNotEmpty) 'breakdown': breakdownOffsets,
  };

  /// Decodes the CURRENT format only. Legacy entries (`blank`/`mark`
  /// types, drawing entries without `length`) are migrated in
  /// `Layer.fromJson`, which needs whole-timeline context.
  factory TimelineExposure.fromJson(Map<String, dynamic> json) {
    final type = TimelineExposureType.fromJson(json['type']);
    if (type != TimelineExposureType.drawing) {
      throw const FormatException(
        'Standalone mark timeline entries are legacy; Layer.fromJson '
        'migrates them into block breakdown offsets.',
      );
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
      breakdownOffsets: _normalizedOffsets([
        for (final offset in (json['breakdown'] as List<dynamic>? ?? const []))
          offset as int,
      ], length),
    );
  }

  bool _sameOffsets(List<int> other) {
    if (other.length != breakdownOffsets.length) {
      return false;
    }
    for (var i = 0; i < other.length; i += 1) {
      if (other[i] != breakdownOffsets[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineExposure &&
          other.type == type &&
          other.frameId == frameId &&
          other.length == length &&
          other.ghost == ghost &&
          other.repeatRegionId == repeatRegionId &&
          _sameOffsets(other.breakdownOffsets);

  @override
  int get hashCode => Object.hash(
    type,
    frameId,
    length,
    ghost,
    repeatRegionId,
    Object.hashAll(breakdownOffsets),
  );

  @override
  String toString() =>
      'TimelineExposure(type: $type, frameId: $frameId, length: $length'
      '${ghost ? ', ghost($repeatRegionId)' : ''}'
      '${breakdownOffsets.isEmpty ? '' : ', breakdown: $breakdownOffsets'})';
}
