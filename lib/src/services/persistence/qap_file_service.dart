import 'dart:io';
import 'dart:typed_data';

import '../../models/project.dart';
import '../brush_frame_store.dart';
import 'brush_drawing_binary_codec.dart';
import 'qap_project_archive.dart';

/// A loaded .qap: the project with media paths already RESOLVED (relative
/// manifest entries that exist next to the file win over the stored
/// absolute paths — the Drive-portability rule) plus the drawings to seed
/// the brush store with.
class QapOpenResult {
  const QapOpenResult({required this.project, required this.drawings});

  final Project project;
  final List<QapDrawingEntry> drawings;
}

/// Saves/loads .qap project files (P3). Writes are ATOMIC: the archive is
/// finished in a temp sibling then renamed over the target, so a crash or
/// a mid-write Drive sync never leaves a corrupt half-file. No file locks
/// are held while the project is open (sync-friendly).
class QapFileService {
  const QapFileService();

  Future<void> save({
    required Project project,
    required BrushFrameStore brushFrameStore,
    required String filePath,
  }) async {
    final drawings = [
      for (final entry in brushFrameStore.drawingsSnapshotForSave().entries)
        QapDrawingEntry(key: entry.key, commands: entry.value),
    ];
    final bytes = buildQapArchiveBytes(
      project: project,
      drawings: drawings,
      saveDirectory: _parentDirectory(filePath),
    );

    final temp = File('$filePath.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await temp.parent.create(recursive: true);
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(filePath);
  }

  Future<QapOpenResult> open({required String filePath}) async {
    final bytes = Uint8List.fromList(await File(filePath).readAsBytes());
    final contents = parseQapArchiveBytes(bytes);

    // Relative media resolution: an entry whose relative path exists next
    // to the .qap wins (the folder traveled whole); otherwise the stored
    // absolute path stays and the existing missing-media relink flow takes
    // over.
    final directory = _parentDirectory(filePath);
    final remap = <String, String>{};
    for (final entry in contents.mediaRelativePaths.entries) {
      final resolved = '$directory/${entry.value}';
      if (await File(resolved).exists()) {
        remap[entry.key] = resolved;
      }
    }

    return QapOpenResult(
      project: remapProjectMediaPaths(contents.project, remap),
      drawings: contents.drawings,
    );
  }

  static String _parentDirectory(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash <= 0 ? '.' : normalized.substring(0, slash);
  }
}
