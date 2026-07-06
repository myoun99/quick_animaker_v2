enum LayerKind {
  animation('animation'),
  storyboard('storyboard'),

  /// The cut's camera track: selecting it puts the canvas into camera
  /// manipulation mode and its timeline row shows camera keyframes. Exactly
  /// one per cut, auto-created, holds no drawing frames.
  camera('camera');

  const LayerKind(this.jsonValue);

  final String jsonValue;

  String toJson() => jsonValue;

  static LayerKind fromJson(Object? json) {
    for (final kind in LayerKind.values) {
      if (json == kind.jsonValue) {
        return kind;
      }
    }

    throw ArgumentError.value(
      json,
      'kind',
      'Layer kind must be "animation", "storyboard" or "camera".',
    );
  }
}
