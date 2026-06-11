enum LayerKind {
  animation('animation'),
  storyboard('storyboard');

  const LayerKind(this.jsonValue);

  final String jsonValue;

  String toJson() => jsonValue;

  static LayerKind fromJson(Object? json) {
    if (json == animation.jsonValue) return animation;
    if (json == storyboard.jsonValue) return storyboard;

    throw ArgumentError.value(
      json,
      'kind',
      'Layer kind must be "animation" or "storyboard".',
    );
  }
}
