import 'dart:convert';
import 'dart:io';

import '../models/brush_preset.dart';
import '../models/brush_preset_id.dart';
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

  /// Library file format version. Bump when a release adds new built-in
  /// presets: libraries saved with an older version get the new built-ins
  /// merged in once on load (an explicitly deleted built-in stays deleted
  /// within the same version).
  static const int libraryVersion = 2;

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
      final presets = _withUniqueIds([
        for (final entry in entries)
          BrushPreset.fromJson(entry as Map<String, dynamic>),
      ]);
      final savedVersion = decoded['version'] as int? ?? 1;
      if (savedVersion < libraryVersion) {
        final knownIds = {for (final preset in presets) preset.id};
        presets.addAll([
          for (final builtin in defaultBrushPresets)
            if (!knownIds.contains(builtin.id)) builtin,
        ]);
      }
      return presets;
    } catch (_) {
      // A corrupt library must not fail the editor: fall back to the
      // defaults; the file is replaced on the next save.
      return List.of(defaultBrushPresets);
    }
  }

  /// Ids must be unique (they key preset chips and drive replace-on-import),
  /// so duplicates in a saved library — e.g. written by the pre-fix ABR
  /// importer when several brushes shared one tip — are healed on load by
  /// suffixing later occurrences deterministically.
  static List<BrushPreset> _withUniqueIds(List<BrushPreset> presets) {
    final seen = <BrushPresetId>{};
    return [
      for (final preset in presets)
        if (seen.add(preset.id))
          preset
        else
          preset.copyWith(id: _nextFreeId(preset.id, seen)),
    ];
  }

  static BrushPresetId _nextFreeId(BrushPresetId id, Set<BrushPresetId> seen) {
    var suffix = 2;
    while (true) {
      final candidate = BrushPresetId('${id.value}-$suffix');
      if (seen.add(candidate)) {
        return candidate;
      }
      suffix += 1;
    }
  }

  /// Writes the preset library, creating the app-data directory as needed.
  Future<void> save(List<BrushPreset> presets) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'version': libraryVersion,
        'presets': [for (final preset in presets) preset.toJson()],
      }),
    );
  }
}
