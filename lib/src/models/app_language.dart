/// The languages the app speaks (UI-R10 #7) — used TWICE, independently:
/// the PROGRAM language (menus, panels, labels) and the NOTATION language
/// (what prints on submission artifacts like the timesheet). An American
/// studio working on Japanese anime runs the program in English and
/// prints the sheet in Japanese — hence two settings, not one.
enum AppLanguage {
  en,
  ja,
  ko,
  fr,
  zhHans;

  String toJson() => name;

  static AppLanguage fromJson(Object? value) => switch (value) {
    'en' => AppLanguage.en,
    'ja' => AppLanguage.ja,
    'ko' => AppLanguage.ko,
    'fr' => AppLanguage.fr,
    'zhHans' => AppLanguage.zhHans,
    _ => throw FormatException('Unknown app language: $value'),
  };

  /// The language's own name (settings dropdowns show every language in
  /// itself, the universal convention).
  String get displayName => switch (this) {
    AppLanguage.en => 'English',
    AppLanguage.ja => '日本語',
    AppLanguage.ko => '한국어',
    AppLanguage.fr => 'Français',
    AppLanguage.zhHans => '简体中文',
  };
}

/// The two language settings together (UI-R10 #7). Defaults follow the
/// user's rule: program = English, notation = Japanese.
class AppLanguageSettings {
  const AppLanguageSettings({
    this.programLanguage = AppLanguage.en,
    this.notationLanguage = AppLanguage.ja,
  });

  /// What the APP UI reads in (coverage rolls out incrementally — strings
  /// not yet tabled stay English).
  final AppLanguage programLanguage;

  /// What SUBMISSION artifacts print in (the timesheet header labels, the
  /// repeat word, …).
  final AppLanguage notationLanguage;

  AppLanguageSettings copyWith({
    AppLanguage? programLanguage,
    AppLanguage? notationLanguage,
  }) => AppLanguageSettings(
    programLanguage: programLanguage ?? this.programLanguage,
    notationLanguage: notationLanguage ?? this.notationLanguage,
  );

  Map<String, dynamic> toJson() => {
    'program': programLanguage.toJson(),
    'notation': notationLanguage.toJson(),
  };

  factory AppLanguageSettings.fromJson(Map<String, dynamic> json) =>
      AppLanguageSettings(
        programLanguage: AppLanguage.fromJson(json['program']),
        notationLanguage: AppLanguage.fromJson(json['notation']),
      );

  @override
  bool operator ==(Object other) =>
      other is AppLanguageSettings &&
      other.programLanguage == programLanguage &&
      other.notationLanguage == notationLanguage;

  @override
  int get hashCode => Object.hash(programLanguage, notationLanguage);

  @override
  String toString() =>
      'AppLanguageSettings(program: ${programLanguage.name}, '
      'notation: ${notationLanguage.name})';
}
