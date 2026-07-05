import 'dart:convert';
import 'dart:io';

import '../models/brush_preset.dart';
import 'brush_preset_defaults.dart';

/// Loads and saves the app-level brush preset library.
///
/// Presets are editor/app state, not project data: they live in an
/// app-support JSON file and never enter the project save schema (per the
/// brush settings boundary in `Current_Brush_Architecture.md`).
class BrushPresetFileService {
  BrushPresetFileService({String? filePath})
    : filePath = filePath ?? defaultBrushPresetFilePath();

  /// Absolute path of the preset library file.
  final String filePath;

  /// Resolves the platform's per-user app-data directory without extra
  /// dependencies: `%APPDATA%` on Windows, the home directory elsewhere,
  /// falling back to the system temp directory.
  static String defaultBrushPresetFilePath() {
    final environment = Platform.environment;
    final base =
        environment['APPDATA'] ??
        environment['HOME'] ??
        environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    const separator = '/';
    final normalizedBase = base.replaceAll('\\', separator);
    return '$normalizedBase$separator'
        'quick_animaker_v2${separator}brush_presets.json';
  }

  /// Reads the preset library; a missing or unreadable file yields the
  /// built-in defaults (nothing is written back until the next save).
  Future<List<BrushPreset>> loadOrDefaults() async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return List.of(defaultBrushPresets);
      }
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final entries = decoded['presets'] as List<dynamic>;
      // An empty saved library is a valid user choice (all presets deleted).
      return [
        for (final entry in entries)
          BrushPreset.fromJson(entry as Map<String, dynamic>),
      ];
    } catch (_) {
      // A corrupt library must not fail the editor: fall back to the
      // defaults; the file is replaced on the next save.
      return List.of(defaultBrushPresets);
    }
  }

  /// Writes the preset library, creating the app-data directory as needed.
  Future<void> save(List<BrushPreset> presets) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'presets': [for (final preset in presets) preset.toJson()],
      }),
    );
  }
}
