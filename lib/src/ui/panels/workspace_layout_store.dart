import 'dart:convert';
import 'dart:io';

import 'editor_panel_layout.dart';

/// Loads and saves the dockable-panel workspace layout (which tab lives in
/// which dock/section, section weights, dock extents, drag locks).
///
/// Like the brush preset library this is editor/app state, not project
/// data: it lives in an app-support JSON file. A missing or corrupt file
/// simply yields no layout (the workspace keeps its defaults).
class WorkspaceLayoutStore {
  WorkspaceLayoutStore({String? filePath})
    : filePath = filePath ?? defaultWorkspaceLayoutFilePath();

  /// Absolute path of the layout file.
  final String filePath;

  /// Resolves the platform's per-user app-data directory without extra
  /// dependencies: `%APPDATA%` on Windows, the home directory elsewhere,
  /// falling back to the system temp directory.
  static String defaultWorkspaceLayoutFilePath() {
    final environment = Platform.environment;
    final base =
        environment['APPDATA'] ??
        environment['HOME'] ??
        environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    const separator = '/';
    final normalizedBase = base.replaceAll('\\', separator);
    return '$normalizedBase$separator'
        'quick_animaker_v2${separator}workspace_layout.json';
  }

  static const int layoutVersion = 1;

  /// Reads the saved layout payload; null when missing/corrupt/newer.
  Future<Map<String, Object?>?> load() async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      final decoded =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if ((decoded['version'] as int? ?? 0) > layoutVersion) {
        return null;
      }
      return decoded;
    } catch (_) {
      // A corrupt layout must not fail the editor: the defaults win and
      // the file is replaced on the next save.
      return null;
    }
  }

  /// Writes the layout payload, creating the app-data directory as needed.
  Future<void> save(Map<String, Object?> payload) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'version': layoutVersion, ...payload}),
    );
  }
}

/// A sanitized restored workspace layout.
typedef RestoredWorkspaceLayout = ({
  Map<String, List<DockSection>> docks,
  Map<String, double> dockExtents,
  Set<String> lockedTabIds,
});

/// Rebuilds a dock layout from a saved payload, validated against the
/// CURRENT panel set given by [defaults]: unknown tab ids are dropped,
/// duplicates keep their first occurrence, and known tabs missing from the
/// saved layout return to their default dock (as a trailing section).
/// Returns null when the payload has no usable layout.
RestoredWorkspaceLayout? restoreWorkspaceLayout({
  required Map<String, Object?> payload,
  required Map<String, List<DockSection>> defaults,
}) {
  final layoutJson = payload['layout'];
  if (layoutJson is! Map) {
    return null;
  }
  final docksJson = layoutJson['docks'];
  if (docksJson is! Map) {
    return null;
  }

  final knownTabs = <String>{
    for (final sections in defaults.values)
      for (final section in sections) ...section.tabs,
  };

  final seen = <String>{};
  final docks = <String, List<DockSection>>{
    for (final dockId in defaults.keys) dockId: <DockSection>[],
  };
  for (final entry in docksJson.entries) {
    final dockId = entry.key;
    if (dockId is! String || !docks.containsKey(dockId)) {
      continue;
    }
    final sectionsJson = entry.value;
    if (sectionsJson is! List) {
      continue;
    }
    for (final sectionJson in sectionsJson) {
      if (sectionJson is! Map) {
        continue;
      }
      final tabsJson = sectionJson['tabs'];
      if (tabsJson is! List) {
        continue;
      }
      final tabs = <String>[
        for (final tab in tabsJson)
          if (tab is String && knownTabs.contains(tab) && seen.add(tab)) tab,
      ];
      if (tabs.isEmpty) {
        continue;
      }
      final active = sectionJson['active'];
      final weight = sectionJson['weight'];
      docks[dockId]!.add(
        DockSection(
          tabs: tabs,
          activeTabId: active is String && tabs.contains(active)
              ? active
              : null,
          weight: weight is num ? weight.toDouble() : 1,
        ),
      );
    }
  }

  // Panels the user CLOSED stay closed; anything else missing from the
  // save (panels added by an app update) returns to its default dock.
  final hiddenJson = payload['hiddenTabs'];
  final hiddenTabs = <String>{
    if (hiddenJson is List)
      for (final tab in hiddenJson)
        if (tab is String) tab,
  };
  for (final entry in defaults.entries) {
    for (final section in entry.value) {
      final missing = [
        for (final tab in section.tabs)
          if (!hiddenTabs.contains(tab) && seen.add(tab)) tab,
      ];
      if (missing.isNotEmpty) {
        docks[entry.key]!.add(DockSection(tabs: missing));
      }
    }
  }

  final extentsJson = layoutJson['extents'];
  final dockExtents = <String, double>{
    if (extentsJson is Map)
      for (final entry in extentsJson.entries)
        if (entry.key is String &&
            docks.containsKey(entry.key) &&
            entry.value is num)
          entry.key as String: (entry.value as num).toDouble(),
  };

  final lockedJson = payload['lockedTabs'];
  final lockedTabIds = <String>{
    if (lockedJson is List)
      for (final tab in lockedJson)
        if (tab is String && knownTabs.contains(tab)) tab,
  };

  return (docks: docks, dockExtents: dockExtents, lockedTabIds: lockedTabIds);
}
