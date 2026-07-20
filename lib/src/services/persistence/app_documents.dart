import 'dart:io';

/// SAVE-1: the app's USER-VISIBLE project home — the default location
/// every save/open surface starts in (the initial-save window, Save As,
/// Open). Deliberately a folder ordinary file managers show:
///
/// - Windows: `%USERPROFILE%/Documents/QuickAnimaker`
/// - macOS/Linux: `$HOME/Documents/QuickAnimaker`
/// - Android: the app's external files dir until SAVE-1c wires the
///   storage channel (앱 문서 폴더 = "내 파일"에서 보이는 위치)
/// - iOS: the sandbox Documents dir (Files-app visible once the Info
///   flags land in SAVE-1d)
String appDocumentsDirectory() {
  final environment = Platform.environment;
  final home = environment['USERPROFILE'] ?? environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final normalized = home.replaceAll('\\', '/');
    return '$normalized/Documents/QuickAnimaker';
  }
  // Environment-less platforms (mobile embedders): the system temp keeps
  // dev/test harmless until the platform channels land.
  return '${Directory.systemTemp.path.replaceAll('\\', '/')}/QuickAnimaker';
}

/// [appDocumentsDirectory], created if missing.
Future<String> ensuredAppDocumentsDirectory() async {
  final path = appDocumentsDirectory();
  await Directory(path).create(recursive: true);
  return path;
}
