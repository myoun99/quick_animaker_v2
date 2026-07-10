import 'dart:async';
import 'dart:io';

/// Autosave (P3): a periodic tick snapshots a DIRTY session into a sidecar
/// — `<path>.autosave` next to the saved file, or an app-data
/// `autosave/<projectId>.qap.autosave` while the project has never been
/// saved. A successful MANUAL save deletes the sidecar; opening a file
/// with a newer sidecar offers recovery (the menu's open flow).
///
/// The service knows nothing about widgets: the shell starts it
/// (FLUTTER_TEST never runs the timer) and tests drive [tick] directly.
class ProjectAutosaveService {
  ProjectAutosaveService({
    required this.isDirty,
    required this.writeSnapshot,
    required this.autosavePath,
    this.interval = const Duration(minutes: 2),
  });

  /// Whether unsaved changes exist (the session's dirty flag).
  final bool Function() isDirty;

  /// Writes the current session snapshot to [path] (the session's .qap
  /// writer pointed at the sidecar — atomic like a manual save).
  final Future<void> Function(String path) writeSnapshot;

  /// The sidecar path for the CURRENT session state (moves when the
  /// project is saved under a new name).
  final String Function() autosavePath;

  final Duration interval;

  Timer? _timer;
  bool _ticking = false;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => unawaited(tick()));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// One autosave pass: dirty → snapshot to the sidecar (clean sessions
  /// write nothing). Never throws — a failed autosave must not disturb
  /// editing; the next tick retries.
  Future<void> tick() async {
    if (_ticking || !isDirty()) {
      return;
    }
    _ticking = true;
    try {
      await writeSnapshot(autosavePath());
    } catch (_) {
      // Swallowed by design; the next tick retries.
    } finally {
      _ticking = false;
    }
  }

  /// The app-data folder holding autosaves of never-saved projects.
  static String defaultUnsavedAutosaveDirectory() {
    final environment = Platform.environment;
    final base =
        environment['APPDATA'] ??
        environment['HOME'] ??
        environment['USERPROFILE'] ??
        Directory.systemTemp.path;
    final normalizedBase = base.replaceAll('\\', '/');
    return '$normalizedBase/quick_animaker_v2/autosave';
  }

  /// Deletes [sidecarPath] if present (after a successful manual save).
  static Future<void> deleteSidecar(String sidecarPath) async {
    try {
      final file = File(sidecarPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // A locked sidecar (cloud sync mid-upload) is harmless — recovery
      // compares timestamps.
    }
  }

  /// Whether [sidecarPath] holds a same-or-newer snapshot than [filePath]
  /// — the open flow's recovery prompt condition. Inclusive on ties: a
  /// surviving sidecar means the manual save never retired it, and
  /// filesystem mtime granularity can collapse close writes.
  static bool sidecarIsNewer({
    required String filePath,
    required String sidecarPath,
  }) {
    final file = File(filePath);
    final sidecar = File(sidecarPath);
    if (!sidecar.existsSync()) {
      return false;
    }
    if (!file.existsSync()) {
      return true;
    }
    return !sidecar.lastModifiedSync().isBefore(file.lastModifiedSync());
  }
}
