import 'dart:ui' show BlendMode;

import 'app_language.dart';

/// The 12 separable blend modes shared, byte-for-byte, by [BrushBlendMode]
/// (a stroke's composite onto the cel) and [LayerBlendMode] (a layer/group's
/// composite onto everything below). Their GPU [BlendMode] and localized
/// labels live here ONCE, so the two vocabularies cannot drift — before D5
/// each enum carried its own copy of all three tables, and a changed label
/// or mapping had to be edited in both.
///
/// Each blend enum still lists these as its own enum values (it needs them for
/// exhaustive `switch` and by-name JSON) and resolves the shared data through
/// [forName], keyed on the enum value's `name`. `separable_blend_mode_test`
/// pins that every separable case on both enums maps here, so a renamed value
/// fails a test instead of resolving to `null` at runtime.
enum SeparableBlendMode {
  darken(BlendMode.darken, 'Darken', '比較（暗）'),
  multiply(BlendMode.multiply, 'Multiply', '乗算'),
  colorBurn(BlendMode.colorBurn, 'Color Burn', '焼き込みカラー'),
  lighten(BlendMode.lighten, 'Lighten', '比較（明）'),
  screen(BlendMode.screen, 'Screen', 'スクリーン'),
  colorDodge(BlendMode.colorDodge, 'Color Dodge', '覆い焼きカラー'),
  add(BlendMode.plus, 'Add', '加算'),
  overlay(BlendMode.overlay, 'Overlay', 'オーバーレイ'),
  softLight(BlendMode.softLight, 'Soft Light', 'ソフトライト'),
  hardLight(BlendMode.hardLight, 'Hard Light', 'ハードライト'),
  difference(BlendMode.difference, 'Difference', '差の絶対値'),
  exclusion(BlendMode.exclusion, 'Exclusion', '除外');

  const SeparableBlendMode(this.blendMode, this.label, this._ja);

  /// The GPU blend this separable mode composites through.
  final BlendMode blendMode;

  /// The industry-standard English label every paint tool shares.
  final String label;

  final String _ja;

  /// The label in [language] — ja follows the PS/CSP Japanese terms (user
  /// rule 07-22: ja localized first, every other language keeps the shared
  /// English vocabulary).
  String labelFor(AppLanguage language) =>
      language == AppLanguage.ja ? _ja : label;

  /// The separable mode whose `name` equals [name], or `null` when none does
  /// — the non-separable heads (`color`/`behind`/`erase`, `passThrough`/
  /// `normal`) have no counterpart here.
  static SeparableBlendMode? forName(String name) => values.asNameMap()[name];
}
