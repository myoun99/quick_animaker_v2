import 'dart:convert';
import 'dart:io';

import 'app_save_settings.dart';
import 'app_support_path.dart';

/// Loads and saves the save/autosave policy (SAVE-1). App state — an
/// app-support JSON beside the language/accent/input settings;
/// missing/corrupt files yield the defaults.
class AppSaveSettingsStore {
  AppSaveSettingsStore({String? filePath})
    : filePath = filePath ?? defaultFilePath();

  final String filePath;

  static String defaultFilePath() =>
      appSupportFilePath('save_settings.json');

  static const int version = 1;

  Future<AppSaveSettings?> load() async {
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
      return AppSaveSettings.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  Future<void> save(AppSaveSettings settings) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'version': version, ...settings.toJson()}),
    );
  }
}
