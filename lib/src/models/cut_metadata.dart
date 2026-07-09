/// The cut fade's TARGET: fade-out to black (FO, the default convention)
/// or to white (WO). One target per cut — it colors both fade ramps.
enum CutFadeTarget {
  black,
  white;

  String toJson() => name;

  static CutFadeTarget fromJson(Object? json) =>
      values.asNameMap()[json] ?? CutFadeTarget.black;
}

class CutMetadata {
  const CutMetadata({
    this.note = '',
    this.thumbnailFrameIndex,
    this.fadeTarget = CutFadeTarget.black,
  });

  const CutMetadata.empty()
    : note = '',
      thumbnailFrameIndex = null,
      fadeTarget = CutFadeTarget.black;

  final String note;

  /// The cut-local frame the storyboard block's thumbnail shows; null means
  /// the first frame. Clamped to the playback range at render time, so a
  /// later trim never breaks it.
  final int? thumbnailFrameIndex;

  /// What the cut fade fades TO (FO=black default, WO=white) — playback and
  /// the MP4 bake consume the same value.
  final CutFadeTarget fadeTarget;

  /// [thumbnailFrameIndex] passes as a closure so callers can CLEAR the pin
  /// (`() => null`) — the plain-nullable convention cannot express that.
  CutMetadata copyWith({
    String? note,
    int? Function()? thumbnailFrameIndex,
    CutFadeTarget? fadeTarget,
  }) {
    return CutMetadata(
      note: note ?? this.note,
      thumbnailFrameIndex: thumbnailFrameIndex == null
          ? this.thumbnailFrameIndex
          : thumbnailFrameIndex(),
      fadeTarget: fadeTarget ?? this.fadeTarget,
    );
  }

  Map<String, dynamic> toJson() => {
    'note': note,
    if (thumbnailFrameIndex != null) 'thumbnailFrame': thumbnailFrameIndex,
    if (fadeTarget != CutFadeTarget.black) 'fadeTarget': fadeTarget.toJson(),
  };

  factory CutMetadata.fromJson(Map<String, dynamic> json) {
    return CutMetadata(
      note: json['note'] as String? ?? '',
      thumbnailFrameIndex: json['thumbnailFrame'] as int?,
      fadeTarget: CutFadeTarget.fromJson(json['fadeTarget']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CutMetadata &&
          other.note == note &&
          other.thumbnailFrameIndex == thumbnailFrameIndex &&
          other.fadeTarget == fadeTarget;

  @override
  int get hashCode => Object.hash(note, thumbnailFrameIndex, fadeTarget);

  @override
  String toString() =>
      'CutMetadata(note: $note, thumbnailFrameIndex: $thumbnailFrameIndex, '
      'fadeTarget: $fadeTarget)';
}
