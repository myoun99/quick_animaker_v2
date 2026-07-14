import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../../models/bitmap_surface.dart';
import '../../models/brush_frame_key.dart';
import '../../models/project.dart';
import '../brush_frame_store.dart';
import 'brush_drawing_binary_codec.dart';
import 'qap_project_archive.dart';

/// A loaded .qap: the project with media paths already RESOLVED (relative
/// manifest entries that exist next to the file win over the stored
/// absolute paths — the Drive-portability rule) plus the BAKED cels to
/// seed the brush store with (R19 bake-only).
class QapOpenResult {
  const QapOpenResult({required this.project, required this.cels});

  final Project project;
  final Map<BrushFrameKey, BitmapSurface> cels;
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
    // commit and undo donates into it; opens bake v1 files on the way in).
    // R19-Z: snapshot to plain BYTES here — native-backed tiles are
    // Finalizable and cannot cross the encode isolate (the old implicit
    // graph copy cost the same, so this is not a new copy).
    final baked = brushFrameStore.bakedSnapshotForSave();
    final cels = [
      for (final entry in baked.entries)
        QapCelEntry.fromSurface(entry.key, entry.value),
    ];
    final saveDirectory = _parentDirectory(filePath);
    // Encode + deflate OFF the UI isolate: the archive build cost grows
    // with every stroke in the project, and running it inline froze the
    // editor for the whole encode on autosave ticks and manual saves
    // (R11-⑦). The snapshot is immutable model data, so the isolate send
    // is a plain graph copy; the result bytes return via Isolate.exit
    // (zero-copy).
    final bytes = await Isolate.run(
      () => buildQapArchiveBytes(
        project: project,
        cels: cels,
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
    // Inflate + decode off the UI isolate (the mirror of save's encode).
    // R19-Z: the isolate boundary ships PLAIN-BYTES cel entries (native
    // tiles are Finalizable = unsendable).
    final (:project, :celEntries, :mediaRelativePaths) = await Isolate.run(() {
      final contents = parseQapArchiveBytes(bytes);
      return (
        project: contents.project,
        celEntries: contents.cels,
        mediaRelativePaths: contents.mediaRelativePaths,
      );
    });
    final cels = {for (final entry in celEntries) entry.key: entry.toSurface()};

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
