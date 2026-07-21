import 'dart:ui' show BlendMode;

import 'app_language.dart';

/// The BRUSH's own composite against the cel it paints on (R26 #9, BB-1).
///
/// Distinct from the layer blend: this decides how a STROKE lands on the
/// active cel's pixels — [color] is plain srcOver (the default), [behind]
/// paints only where the cel is still empty (PS 'Behind'), [erase] uses
/// the brush as an eraser (rides the existing dab erase flag), and the
/// separable modes share the layer vocabulary. Applied ONCE per stroke at
/// pen-up (never dab-by-dab — overlapping dabs must not double-apply),
/// with the live overlay previewing through the matching ui.BlendMode.
///
/// Independence rule (R26 #10): like the stabilizer, this is a HAND
/// setting — brush preset application carries it over unchanged.
enum BrushBlendMode {
  color,
  behind,
  erase,
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

  /// Whether this mode composites through the SEPARABLE blend kernel at
  /// commit (everything except the three porter-duff-style modes).
  bool get isSeparable => switch (this) {
    color || behind || erase => false,
    _ => true,
  };

  /// The live overlay's preview blend. The GPU float math approximates
  /// the integer commit kernel within ±1/255 — the committed pixels are
  /// the truth.
  BlendMode get previewBlendMode => switch (this) {
    color => BlendMode.srcOver,
    behind => BlendMode.dstOver,
    erase => BlendMode.dstOut,
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

  /// The industry-standard English label.
  String get label => switch (this) {
    color => 'Color',
    behind => 'Behind',
    erase => 'Erase',
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

  /// The label in the program language — ja follows the PS/CSP Japanese
  /// terms (user rule 07-22: ja localized first, other languages keep
  /// the shared English vocabulary).
  String labelFor(AppLanguage language) => switch (language) {
    AppLanguage.ja => switch (this) {
      color => '通常',
      behind => '背面',
      erase => '消去',
      darken => '比較（暗）',
      multiply => '乗算',
      colorBurn => '焼き込みカラー',
      lighten => '比較（明）',
      screen => 'スクリーン',
      colorDodge => '覆い焼きカラー',
      add => '加算',
      overlay => 'オーバーレイ',
      softLight => 'ソフトライト',
      hardLight => 'ハードライト',
      difference => '差の絶対値',
      exclusion => '除外',
    },
    _ => label,
  };

  String toJson() => name;

  static BrushBlendMode fromJson(Object? json) {
    return BrushBlendMode.values.firstWhere(
      (value) => value.name == json,
      orElse: () => BrushBlendMode.color,
    );
  }
}
