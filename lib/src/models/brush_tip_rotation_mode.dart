/// How a dab's tip angle is chosen at placement time.
enum BrushTipRotationMode {
  /// The tip keeps the fixed `angleDegrees` setting.
  fixed,

  /// The tip follows the stroke direction; `angleDegrees` becomes an offset
  /// on top of it (Photoshop "Direction" angle control, Clip Studio 진행방향).
  direction;

  String toJson() => name;

  static BrushTipRotationMode fromJson(Object? value) {
    return BrushTipRotationMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => BrushTipRotationMode.fixed,
    );
  }
}
