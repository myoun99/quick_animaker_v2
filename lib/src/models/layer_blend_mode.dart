import 'dart:ui' show BlendMode;

/// The layer's compositing blend against everything below it (R26 #30).
///
/// Applied at COMPOSITE time on every route (playback cache, editing
/// stack, camera renders, export) — never baked into the artwork.
/// [normal] is plain srcOver and the serialized default (omitted from
/// JSON, so pre-blend files read back unchanged). Mirrors across link
/// groups like the eye/opacity ("레인만 각자, 나머지는 하나").
enum LayerBlendMode {
  normal,
  darken,
  multiply,
  colorBurn,
  lighten,
  screen,
  colorDodge,
  add,
  overlay,
  softLight,
  hardLight,
  difference,
  exclusion;

  /// The ui.Paint blend for the composite draw.
  BlendMode get paintBlendMode => switch (this) {
    normal => BlendMode.srcOver,
    darken => BlendMode.darken,
    multiply => BlendMode.multiply,
    colorBurn => BlendMode.colorBurn,
    lighten => BlendMode.lighten,
    screen => BlendMode.screen,
    colorDodge => BlendMode.colorDodge,
    add => BlendMode.plus,
    overlay => BlendMode.overlay,
    softLight => BlendMode.softLight,
    hardLight => BlendMode.hardLight,
    difference => BlendMode.difference,
    exclusion => BlendMode.exclusion,
  };

  /// The menu label (the industry-standard English terms every paint
  /// tool shares).
  String get label => switch (this) {
    normal => 'Normal',
    darken => 'Darken',
    multiply => 'Multiply',
    colorBurn => 'Color Burn',
    lighten => 'Lighten',
    screen => 'Screen',
    colorDodge => 'Color Dodge',
    add => 'Add',
    overlay => 'Overlay',
    softLight => 'Soft Light',
    hardLight => 'Hard Light',
    difference => 'Difference',
    exclusion => 'Exclusion',
  };

  String toJson() => name;

  static LayerBlendMode fromJson(Object? json) {
    return LayerBlendMode.values.firstWhere(
      (value) => value.name == json,
      orElse: () => LayerBlendMode.normal,
    );
  }
}
