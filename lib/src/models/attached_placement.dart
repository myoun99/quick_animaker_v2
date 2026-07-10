/// Where an attach layer draws relative to its base layer: directly above
/// (highlights, color) or directly below (shadows, fills). The cut's layer
/// list stores attach layers adjacent to their base — [below…, base,
/// above…] — so plain list order remains the compositing authority.
enum AttachedPlacement {
  below,
  above;

  String toJson() => name;

  static AttachedPlacement fromJson(Object? json) {
    return AttachedPlacement.values.firstWhere(
      (value) => value.name == json,
      orElse: () => AttachedPlacement.above,
    );
  }
}
