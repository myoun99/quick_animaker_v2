import 'dart:convert';
import 'dart:io';

/// Loads and saves the user's shortcut overrides ({actionId: [activator
/// json]}). Editor/app state like the workspace layout: an app-support
/// JSON file; missing or corrupt files simply yield no overrides (the
/// registry defaults win).
class ShortcutSettingsStore {
  ShortcutSettingsStore({String? filePath})
    : filePath = filePath ?? defaultShortcutSettingsFilePath();

  final String filePath;

  static String defaultShortcutSettingsFilePath() {
    final environment = Platform.environment;
    final base =
        environment['APPDATA'] ??
        environment['HOME'] ??
        environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    const separator = '/';
    final normalizedBase = base.replaceAll('\\', separator);
    return '$normalizedBase$separator'
        'quick_animaker_v2${separator}shortcut_overrides.json';
  }

  static const int version = 1;

  /// The saved overrides payload; null when missing/corrupt/newer.
  Future<Map<String, Object?>?> load() async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if ((decoded['version'] as int? ?? 0) > version) {
        return null;
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, Object?> payload) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'version': version, ...payload}));
  }
}
