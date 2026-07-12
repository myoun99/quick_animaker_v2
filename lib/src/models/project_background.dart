/// The project's background (R10-⑥): the paper under the artwork on the
/// canvas, what playback shows in cut gaps, and the blank-canvas color.
///
/// TRANSPARENT is display-only (the canvas shows an alpha checkerboard
/// for checking transparent regions while drawing); exports always bake
/// the opaque [argb] fallback — video formats carry no alpha, and the
/// user chose "표시 전용" over per-export choices.
class ProjectBackground {
  const ProjectBackground.color(this.argb) : transparent = false;

  const ProjectBackground.transparent() : transparent = true, argb = 0xFFFFFFFF;

  /// Whether the screen renders the alpha checkerboard instead of a
  /// solid color.
  final bool transparent;

  /// The opaque ARGB the background paints with — and, under
  /// [transparent], the color exports bake instead.
  final int argb;

  /// The classic paper the editor always used.
  static const ProjectBackground defaultBackground = ProjectBackground.color(
    0xFFEDEDED,
  );

  static const ProjectBackground white = ProjectBackground.color(0xFFFFFFFF);
  static const ProjectBackground black = ProjectBackground.color(0xFF000000);

  Map<String, dynamic> toJson() => {
    if (transparent) 'transparent': true,
    'argb': argb,
  };

  factory ProjectBackground.fromJson(Map<String, dynamic> json) {
    if (json['transparent'] == true) {
      return const ProjectBackground.transparent();
    }
    return ProjectBackground.color(json['argb'] as int? ?? 0xFFEDEDED);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjectBackground &&
          other.transparent == transparent &&
          other.argb == argb;

  @override
  int get hashCode => Object.hash(transparent, argb);

  @override
  String toString() =>
      'ProjectBackground(transparent: $transparent, '
      'argb: 0x${argb.toRadixString(16).toUpperCase()})';
}
