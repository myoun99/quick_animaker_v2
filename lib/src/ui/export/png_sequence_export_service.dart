import 'dart:io';
import 'dart:ui' as ui;

import 'png_srgb.dart';

/// What one export run did: [processed] tasks were attempted (fewer than the
/// plan when cancelled) and [written] files hit the disk ([renderImage]
/// returning `null` skips the file, e.g. empty cels).
typedef ExportWriteSummary = ({int written, int processed});

/// Streams rendered images to disk — one image rendered, encoded and
/// released at a time, so a full-resolution sequence never lives in memory
/// at once.
class PngSequenceExportService {
  const PngSequenceExportService();

  Future<ExportWriteSummary> exportImages({
    required int count,
    required Future<ui.Image?> Function(int index) renderImage,
    required String Function(int index) fileNameFor,
    required String directoryPath,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    var written = 0;
    var processed = 0;
    for (var index = 0; index < count; index += 1) {
      if (isCancelled?.call() ?? false) {
        break;
      }
      final image = await renderImage(index);
      if (image != null) {
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '$directoryPath${Platform.pathSeparator}${fileNameFor(index)}',
          );
          // File names may carry subfolders (per-cut/per-layer cel export).
          await file.parent.create(recursive: true);
          // C1-v1: delivered PNGs declare the working color space
          // (sRGB) so downstream tools stop guessing. Pixels untouched.
          await file.writeAsBytes(
            tagPngAsSrgb(bytes!.buffer.asUint8List()),
            flush: true,
          );
          written += 1;
        } finally {
          image.dispose();
        }
      }
      processed += 1;
      onProgress?.call(processed, count);
    }
    return (written: written, processed: processed);
  }
}
