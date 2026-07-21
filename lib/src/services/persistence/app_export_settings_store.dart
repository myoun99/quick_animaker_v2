import 'dart:convert';
import 'dart:io';

import 'app_export_settings.dart';

/// Loads and saves the export UI state (presets, last specs, location).
/// App state — an app-support JSON beside the save/input/audio settings;
/// missing/corrupt/newer files yield the defaults.
class AppExportSettingsStore {
  AppExportSettingsStore({String? filePath})
    : filePath = filePath ?? defaultFilePath();

  final String filePath;

  static String defaultFilePath() {
    final environment = Platform.environment;
    final base =
        environment['APPDATA'] ??
        environment['HOME'] ??
        environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    const separator = '/';
    final normalizedBase = base.replaceAll('\\', separator);
    return '$normalizedBase$separator'
        'quick_animaker_v2${separator}export_settings.json';
  }

  static const int version = 1;

  Future<AppExportSettings?> load() async {
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
      return AppExportSettings.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> save(AppExportSettings settings) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'version': version, ...settings.toJson()}),
    );
  }
}
