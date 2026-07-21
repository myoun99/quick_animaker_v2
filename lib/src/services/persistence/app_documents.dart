import 'dart:io';

import 'package:flutter/services.dart' show MethodChannel;

/// SAVE-1: the app's USER-VISIBLE project home — the default location
/// every save/open surface starts in (the initial-save window, Save As,
/// Open). Deliberately a folder ordinary file managers show:
///
/// - Windows: `%USERPROFILE%/Documents/QuickAnimaker`
/// - macOS/Linux: `$HOME/Documents/QuickAnimaker`
/// - Android: the PUBLIC Documents folder ("내 파일" shows it) via the
///   qa_storage channel (SAVE-1c)
/// - iOS: the sandbox Documents dir, Files-app visible (SAVE-1d flags)
String appDocumentsDirectory() {
  final fromChannel = AppStorage.channelDocumentsPath;
  if (fromChannel != null && fromChannel.isNotEmpty) {
    return fromChannel;
  }
  final environment = Platform.environment;
  final home = environment['USERPROFILE'] ?? environment['HOME'];
  if (home != null && home.isNotEmpty) {
    final normalized = home.replaceAll('\\', '/');
    return '$normalized/Documents/QuickAnimaker';
  }
  // Environment-less platforms before the channel answers: the system
  // temp keeps dev/test harmless.
  return '${Directory.systemTemp.path.replaceAll('\\', '/')}/QuickAnimaker';
}

/// [appDocumentsDirectory], created if missing.
Future<String> ensuredAppDocumentsDirectory() async {
  final path = appDocumentsDirectory();
  await Directory(path).create(recursive: true);
  return path;
}

/// The sync twin — for dialog-internal navigation (sync dart:io works
/// under the widget-test clock; async never completes there).
String ensuredAppDocumentsDirectorySync() {
  final path = appDocumentsDirectory();
  Directory(path).createSync(recursive: true);
  return path;
}

/// SAVE-1c: the platform storage glue over the `qa_storage` channel —
/// the Android real-path model's grants and the mobile app-documents
/// home. Desktop needs none of it (env paths + full FS access).
abstract final class AppStorage {
  static const MethodChannel _channel = MethodChannel('qa_storage');

  /// The platform-provided app documents home (mobile); null until
  /// [ensureInitialized] resolves it (or on desktop, always).
  static String? channelDocumentsPath;

  /// Test hook: forces the all-files-access answer.
  static bool? debugAllFilesAccessOverride;

  /// Resolves the mobile documents home once at startup (main()).
  static Future<void> ensureInitialized() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    try {
      channelDocumentsPath = await _channel.invokeMethod<String>(
        'appDocumentsPath',
      );
    } on Object {
      channelDocumentsPath = null;
    }
  }

  /// Whether shared-storage paths are writable (Android's All-Files
  /// grant; everywhere else the answer is yes).
  static Future<bool> isAllFilesAccessGranted() async {
    final override = debugAllFilesAccessOverride;
    if (override != null) {
      return override;
    }
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      return await _channel.invokeMethod<bool>('isAllFilesAccessGranted') ??
          false;
    } on Object {
      return false;
    }
  }

  /// Opens the system grant surface (Android settings toggle).
  static Future<void> requestAllFilesAccess() async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('requestAllFilesAccess');
    } on Object {
      // The settings screen failing to open leaves the notice visible.
    }
  }
}
