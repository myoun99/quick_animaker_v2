import '../../models/app_language.dart';

/// PROGRAM-language strings (UI-R10 #7): what the app chrome reads in.
/// Coverage rolls out incrementally — panels adopt entries as they get
/// touched; untabled strings simply stay English in the widgets.
class AppStrings {
  const AppStrings._({
    required this.languageSettingsTitle,
    required this.programLanguageLabel,
    required this.notationLanguageLabel,
    required this.programLanguageHelp,
    required this.notationLanguageHelp,
    required this.noCutSelected,
    required this.pageLabel,
    required this.continuousLabel,
    required this.noticeNoFrameHere,
    required this.noticeActionSectionOnly,
    required this.noticeNothingToTransform,
  });

  final String languageSettingsTitle;
  final String programLanguageLabel;
  final String notationLanguageLabel;
  final String programLanguageHelp;
  final String notationLanguageHelp;

  /// The timeline/timesheet gap empty state.
  final String noCutSelected;

  /// The timesheet panel-frame position label: page view prints
  /// '`<pageLabel>` N'.
  final String pageLabel;

  /// The continuous-view position label.
  final String continuousLabel;

  /// R26 #35/#13 — the shared CURSOR NOTICES: every refused action says
  /// why, right where the user is looking.
  final String noticeNoFrameHere;
  final String noticeActionSectionOnly;
  final String noticeNothingToTransform;

  static AppStrings of(AppLanguage language) => switch (language) {
    AppLanguage.en => _en,
    AppLanguage.ja => _ja,
    AppLanguage.ko => _ko,
    AppLanguage.fr => _fr,
    AppLanguage.zhHans => _zhHans,
  };

  static const _en = AppStrings._(
    languageSettingsTitle: 'Language Settings',
    programLanguageLabel: 'Program language',
    notationLanguageLabel: 'Notation language',
    programLanguageHelp: 'Menus, panels and labels.',
    notationLanguageHelp: 'What prints on the timesheet and exports.',
    noCutSelected: 'No cut selected',
    pageLabel: 'Page',
    continuousLabel: 'Continuous',
    noticeNoFrameHere: 'No frame here',
    noticeActionSectionOnly: 'Only the Action section can be drawn on',
    noticeNothingToTransform: 'Nothing to transform',
  );

  static const _ja = AppStrings._(
    languageSettingsTitle: '言語設定',
    programLanguageLabel: 'プログラム言語',
    notationLanguageLabel: '表記言語',
    programLanguageHelp: 'メニュー・パネル・ラベルの言語。',
    notationLanguageHelp: 'タイムシートなど提出物に印字される言語。',
    noCutSelected: 'カット未選択',
    pageLabel: 'ページ',
    continuousLabel: '連続表示',
    noticeNoFrameHere: 'フレームがありません',
    noticeActionSectionOnly: 'アクション欄でのみ描けます',
    noticeNothingToTransform: '変形する絵がありません',
  );

  static const _ko = AppStrings._(
    languageSettingsTitle: '언어 설정',
    programLanguageLabel: '프로그램 언어',
    notationLanguageLabel: '표기용 언어',
    programLanguageHelp: '메뉴·패널·라벨의 언어.',
    notationLanguageHelp: '타임시트 등 제출물에 인쇄되는 언어.',
    noCutSelected: '선택된 컷 없음',
    pageLabel: '페이지',
    continuousLabel: '콘티너스',
    noticeNoFrameHere: '프레임이 존재하지 않습니다',
    noticeActionSectionOnly: '액션 섹션에서만 그릴 수 있습니다',
    noticeNothingToTransform: '변형할 그림이 없습니다',
  );

  static const _fr = AppStrings._(
    languageSettingsTitle: 'Paramètres de langue',
    programLanguageLabel: 'Langue du programme',
    notationLanguageLabel: 'Langue de notation',
    programLanguageHelp: 'Menus, panneaux et libellés.',
    notationLanguageHelp: 'Ce qui s\'imprime sur la feuille d\'exposition.',
    noCutSelected: 'Aucun plan sélectionné',
    pageLabel: 'Page',
    continuousLabel: 'Continu',
    noticeNoFrameHere: 'Aucune image ici',
    noticeActionSectionOnly:
        'Dessin possible uniquement dans la section Action',
    noticeNothingToTransform: 'Rien a transformer',
  );

  static const _zhHans = AppStrings._(
    languageSettingsTitle: '语言设置',
    programLanguageLabel: '程序语言',
    notationLanguageLabel: '标注语言',
    programLanguageHelp: '菜单、面板与标签的语言。',
    notationLanguageHelp: '打印在摄影表等提交物上的语言。',
    noCutSelected: '未选择镜头',
    pageLabel: '页',
    continuousLabel: '连续视图',
    noticeNoFrameHere: '此处没有帧',
    noticeActionSectionOnly: '只能在动作区绘制',
    noticeNothingToTransform: '没有可变形的内容',
  );
}
