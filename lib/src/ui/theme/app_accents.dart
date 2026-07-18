import 'package:flutter/material.dart';

/// The two program accents (UI-R22 #5).
///
/// ACCENT 1 is the primary highlight (selection, playhead, active
/// toggles — the historical teal). ACCENT 2 is the SECONDARY highlight
/// for states that must read differently from plain selection: the
/// selection-repeat pattern span and the selected key-union diamonds.
/// By default accent 2 is the COMPLEMENT of accent 1 (teal → pink), so
/// the pair always contrasts; both are customizable and persisted.
class AppAccentSettings {
  const AppAccentSettings({this.accent = defaultAccent, Color? accent2})
    : _accent2 = accent2;

  /// The historical program teal.
  static const Color defaultAccent = Color(0xFF4FA8A0);

  final Color accent;
  final Color? _accent2;

  /// Whether accent 2 follows accent 1 automatically (no explicit value).
  bool get accent2FollowsComplement => _accent2 == null;

  Color get accent2 => _accent2 ?? complementOf(accent);

  /// The explicit accent-2 override, when set.
  Color? get accent2Override => _accent2;

  /// The complementary hue (HSL +180°) at the same saturation/lightness.
  static Color complementOf(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + 180.0) % 360.0).toColor();
  }

  /// [clearAccent2] resets accent 2 back to the automatic complement.
  AppAccentSettings copyWith({
    Color? accent,
    Color? accent2,
    bool clearAccent2 = false,
  }) => AppAccentSettings(
    accent: accent ?? this.accent,
    accent2: clearAccent2 ? null : (accent2 ?? _accent2),
  );

  Map<String, dynamic> toJson() => {
    'accent': accent.toARGB32(),
    if (_accent2 != null) 'accent2': _accent2.toARGB32(),
  };

  static AppAccentSettings fromJson(Map<String, dynamic> json) {
    final accent2 = json['accent2'] as int?;
    return AppAccentSettings(
      accent: Color(json['accent'] as int? ?? defaultAccent.toARGB32()),
      accent2: accent2 == null ? null : Color(accent2),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppAccentSettings &&
      other.accent == accent &&
      other._accent2 == _accent2;

  @override
  int get hashCode => Object.hash(accent, _accent2);
}
