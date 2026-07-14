import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../models/brush_frame_key.dart';
import '../../models/project.dart';
import '../brush_frame_store.dart';
import 'brush_drawing_binary_codec.dart';
import 'qap_project_archive.dart';

/// A loaded .qap: the project with media paths already RESOLVED (relative
/// manifest entries that exist next to the file win over the stored
/// absolute paths — the Drive-portability rule) plus the baked cels in
/// COLD form (R20-A1): headers parsed, pixels still deflated — the store
/// materializes each cel on first access, so opening a 1500-cut project
/// costs archive-read time, not a full decode.
class QapOpenResult {
  const QapOpenResult({required this.project, required this.cels});

  final Project project;
  final Map<BrushFrameKey, QapCelBlob> cels;
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
    // R19 bake-only: the save payload IS the baked raster truth (every
    // commit and undo donates into it). R20-A1: cold cels are ALREADY
    // archive bytes — they pass through with zero re-encode; only hot
    // cels snapshot to plain byte entries here (native-backed tiles are
    // Finalizable and cannot cross the encode isolate).
    final baked = brushFrameStore.bakedSnapshotForSave();
    final hotEntries = [
      for (final entry in baked.hot.entries)
        QapCelEntry.fromSurface(entry.key, entry.value),
    ];
    final coldBlobs = baked.cold.values.toList();
    final saveDirectory = _parentDirectory(filePath);
    // Encode + deflate OFF the UI isolate: the archive build cost grows
    // with edited cels, and running it inline froze the editor on
    // autosave ticks and manual saves (R11-⑦). The result bytes return
    // via Isolate.exit (zero-copy).
    final bytes = await Isolate.run(
      () => buildQapArchiveBytes(
        project: project,
        cels: [
          ...coldBlobs,
          for (final entry in hotEntries) QapCelBlob.encode(entry),
        ],
        saveDirectory: saveDirectory,
      ),
    );

    final temp = File('$filePath.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await temp.parent.create(recursive: true);
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(filePath);
  }

  Future<QapOpenResult> open({required String filePath}) async {
    final bytes = Uint8List.fromList(await File(filePath).readAsBytes());
    // Archive parse off the UI isolate. R20-A1: cels come back COLD (a
    // header parse per cel, no pixel inflate/decode anywhere on open) and
    // return via Isolate.exit (zero-copy).
    final (:project, :celBlobs, :mediaRelativePaths) = await Isolate.run(() {
      final contents = parseQapArchiveBytes(bytes);
      return (
        project: contents.project,
        celBlobs: contents.cels,
        mediaRelativePaths: contents.mediaRelativePaths,
      );
    });
    final cels = {for (final blob in celBlobs) blob.key: blob};

    // Relative media resolution: an entry whose relative path exists next
    // to the .qap wins (the folder traveled whole); otherwise the stored
    // absolute path stays and the existing missing-media relink flow takes
    // over.
    final directory = _parentDirectory(filePath);
    final remap = <String, String>{};
    for (final entry in mediaRelativePaths.entries) {
      final resolved = '$directory/${entry.value}';
      if (await File(resolved).exists()) {
        remap[entry.key] = resolved;
      }
    }

    return QapOpenResult(
      project: remapProjectMediaPaths(project, remap),
      cels: cels,
    );
  }

  static String _parentDirectory(String filePath) {
    final normalized = filePath.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash <= 0 ? '.' : normalized.substring(0, slash);
  }
}
