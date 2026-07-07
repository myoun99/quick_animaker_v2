/// Organizational color label on a layer (TVPaint-style layer mark).
/// Purely visual — shown as a chip on the layer label, never affects
/// compositing, playback, or export.
enum LayerMark {
  none('none'),
  red('red'),
  orange('orange'),
  yellow('yellow'),
  green('green'),
  teal('teal'),
  blue('blue'),
  purple('purple'),
  pink('pink');

  const LayerMark(this.jsonValue);

  final String jsonValue;

  String toJson() => jsonValue;

  static LayerMark fromJson(Object? json) {
    for (final mark in LayerMark.values) {
      if (json == mark.jsonValue) {
        return mark;
      }
    }

    throw ArgumentError.value(json, 'mark', 'Unknown layer mark.');
  }
}
