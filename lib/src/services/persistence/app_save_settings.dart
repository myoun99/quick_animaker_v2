import 'dart:io';

import 'package:flutter/foundation.dart';

/// SAVE-1: the save/autosave policy (the 2026-07 저장 설계 확정).
///
/// - Autosave writes a recovery SIDECAR only — the project file changes
///   on an explicit save alone ("저장 안 하고 닫기 = 버리기" stays real).
/// - ON by default at a 5-minute cadence; every knob user-customizable.
/// - The sidecar lives BESIDE the project file by default; a custom
///   directory serves setups where "beside" is unwanted (cloud-synced
///   folders uploading a big sidecar every tick) or impossible.
/// - REC1-B2: never-saved projects record onto a visible take shelf
///   (`<app documents>/Recordings` by default) instead of the hidden OS
///   temp; a custom folder is a desktop-only choice.
class AppSaveSettings {
  const AppSaveSettings({
    this.autosaveEnabled = true,
    this.autosaveIntervalMinutes = 5,
    this.sidecarDirectory,
    this.recordingsDirectory,
  });

  final bool autosaveEnabled;

  /// Minutes between dirty-session snapshots (clamped ≥ 1 on use).
  final int autosaveIntervalMinutes;

  /// Where sidecars live; null/empty = beside the project file.
  final String? sidecarDirectory;

  /// Where a never-saved project's voice takes land; null/empty = the
  /// app documents `Recordings` folder.
  final String? recordingsDirectory;

  static const Object _unset = Object();

  AppSaveSettings copyWith({
    bool? autosaveEnabled,
    int? autosaveIntervalMinutes,
    Object? sidecarDirectory = _unset,
    Object? recordingsDirectory = _unset,
  }) => AppSaveSettings(
    autosaveEnabled: autosaveEnabled ?? this.autosaveEnabled,
    autosaveIntervalMinutes:
        autosaveIntervalMinutes ?? this.autosaveIntervalMinutes,
    sidecarDirectory: identical(sidecarDirectory, _unset)
        ? this.sidecarDirectory
        : sidecarDirectory as String?,
    recordingsDirectory: identical(recordingsDirectory, _unset)
        ? this.recordingsDirectory
        : recordingsDirectory as String?,
  );

  Map<String, dynamic> toJson() => {
    'autosaveEnabled': autosaveEnabled,
    'autosaveIntervalMinutes': autosaveIntervalMinutes,
    'sidecarDirectory': sidecarDirectory,
    'recordingsDirectory': recordingsDirectory,
  };

  static AppSaveSettings fromJson(Map<String, dynamic> json) {
    final directory = json['sidecarDirectory'];
    final recordings = json['recordingsDirectory'];
    return AppSaveSettings(
      autosaveEnabled: json['autosaveEnabled'] as bool? ?? true,
      autosaveIntervalMinutes:
          (json['autosaveIntervalMinutes'] as num?)?.round() ?? 5,
      sidecarDirectory: directory is String && directory.isNotEmpty
          ? directory
          : null,
      recordingsDirectory: recordings is String && recordings.isNotEmpty
          ? recordings
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSaveSettings &&
      other.autosaveEnabled == autosaveEnabled &&
      other.autosaveIntervalMinutes == autosaveIntervalMinutes &&
      other.sidecarDirectory == sidecarDirectory &&
      other.recordingsDirectory == recordingsDirectory;

  @override
  int get hashCode => Object.hash(
    autosaveEnabled,
    autosaveIntervalMinutes,
    sidecarDirectory,
    recordingsDirectory,
  );
}

/// The LIVE save policy (the [AppInput] idiom): the session restores and
/// persists it; the autosave service and the Preferences dialog read it.
abstract final class AppSave {
  static final ValueNotifier<AppSaveSettings> settings =
      ValueNotifier<AppSaveSettings>(const AppSaveSettings());

  static Duration get autosaveInterval =>
      Duration(minutes: settings.value.autosaveIntervalMinutes.clamp(1, 1440));

  /// The sidecar path for [projectFilePath] under the CURRENT settings:
  /// beside the file, or inside the custom directory under a name that
  /// encodes the ORIGIN path (basename + a stable hash of the full path,
  /// so same-named projects in different folders never collide).
  static String sidecarPathFor(String projectFilePath) {
    final directory = settings.value.sidecarDirectory;
    if (directory == null || directory.isEmpty) {
      return '$projectFilePath.autosave';
    }
    final normalizedDirectory = directory.replaceAll('\\', '/');
    return '$normalizedDirectory/${encodeSidecarFileName(projectFilePath)}';
  }

  /// Every location an older sidecar may live for [projectFilePath] —
  /// the location setting may have changed between runs, so recovery
  /// checks them all.
  static List<String> sidecarCandidatesFor(String projectFilePath) {
    final candidates = <String>['$projectFilePath.autosave'];
    final custom = sidecarPathFor(projectFilePath);
    if (custom != candidates.first) {
      candidates.add(custom);
    }
    return candidates;
  }

  /// The NEWEST existing sidecar among the candidates, or null.
  static String? newestExistingSidecarFor(String projectFilePath) {
    String? newest;
    DateTime? newestModified;
    for (final candidate in sidecarCandidatesFor(projectFilePath)) {
      final file = File(candidate);
      if (!file.existsSync()) {
        continue;
      }
      final modified = file.lastModifiedSync();
      if (newestModified == null || modified.isAfter(newestModified)) {
        newest = candidate;
        newestModified = modified;
      }
    }
    return newest;
  }

  /// `basename.<fnv1a32-of-full-path>.autosave` — stable across runs,
  /// filesystem-safe, and collision-resistant across folders.
  static String encodeSidecarFileName(String projectFilePath) {
    final normalized = projectFilePath.replaceAll('\\', '/');
    var hash = 0x811c9dc5;
    for (final unit in normalized.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    final base = normalized.split('/').last;
    return '$base.${hash.toRadixString(16).padLeft(8, '0')}.autosave';
  }
}
