import '../../models/app_language.dart';

/// NOTATION-language strings (UI-R10 #7): what PRINTS on the timesheet —
/// the header box labels and the sheet vocabulary (the repeat word,
/// UI-R10 #6). Independent of the program language: submissions follow
/// the studio's paper convention (default Japanese).
class TimesheetNotation {
  const TimesheetNotation._({
    required this.episode,
    required this.title,
    required this.scene,
    required this.cut,
    required this.duration,
    required this.name,
    required this.page,
    required this.repeat,
  });

  final String episode;
  final String title;
  final String scene;
  final String cut;
  final String duration;
  final String name;
  final String page;

  /// The word a repeat ghost span prints instead of re-listing its cel
  /// numbers (UI-R10 #6) — display only, the underlying data keeps the
  /// expanded 1,2,3,1,2,3 for XDTS/TDTS export.
  final String repeat;

  static TimesheetNotation of(AppLanguage language) => switch (language) {
    AppLanguage.en => english,
    AppLanguage.ja => _ja,
    AppLanguage.ko => _ko,
    AppLanguage.fr => _fr,
    AppLanguage.zhHans => _zhHans,
  };

  /// The pre-UI-R10 wording (the reference forms' English, R7-⑥) — the
  /// painter's default so focused tests stay wording-stable.
  static const TimesheetNotation english = TimesheetNotation._(
    episode: 'Ep.no',
    title: 'Title',
    scene: 'Scene',
    cut: 'Cut.no',
    duration: 'Duration',
    name: 'Name',
    page: 'Page',
    repeat: 'REPEAT',
  );

  static const TimesheetNotation _ja = TimesheetNotation._(
    episode: '話数',
    title: '題名',
    scene: 'シーン',
    cut: 'カット',
    duration: '秒数',
    name: '氏名',
    page: '頁',
    repeat: 'リピート',
  );

  static const TimesheetNotation _ko = TimesheetNotation._(
    episode: '화수',
    title: '제목',
    scene: '씬',
    cut: '컷',
    duration: '초수',
    name: '이름',
    page: '페이지',
    repeat: '리피트',
  );

  static const TimesheetNotation _fr = TimesheetNotation._(
    episode: 'Ép.',
    title: 'Titre',
    scene: 'Scène',
    cut: 'Plan',
    duration: 'Durée',
    name: 'Nom',
    page: 'Page',
    repeat: 'RÉPÉT.',
  );

  static const TimesheetNotation _zhHans = TimesheetNotation._(
    episode: '话数',
    title: '标题',
    scene: '场景',
    cut: '镜头',
    duration: '秒数',
    name: '姓名',
    page: '页',
    repeat: '重复',
  );
}
