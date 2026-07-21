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

  /// [encode] overrides the file bytes (the JPG path, later PSD); the
  /// default stays the engine PNG + the sRGB tag. A null encode result
  /// skips the file like a null render does.
  Future<ExportWriteSummary> exportImages({
    required int count,
    required Future<ui.Image?> Function(int index) renderImage,
    required String Function(int index) fileNameFor,
    required String directoryPath,
    Future<List<int>?> Function(ui.Image image)? encode,
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
          final List<int>? fileBytes;
          if (encode != null) {
            fileBytes = await encode(image);
          } else {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            // C1-v1: delivered PNGs declare the working color space
            // (sRGB) so downstream tools stop guessing. Pixels untouched.
            fileBytes = bytes == null
                ? null
                : tagPngAsSrgb(bytes.buffer.asUint8List());
          }
          if (fileBytes != null) {
            final file = File(
              '$directoryPath${Platform.pathSeparator}${fileNameFor(index)}',
            );
            // File names may carry subfolders (per-cut/per-layer cels).
            await file.parent.create(recursive: true);
            await file.writeAsBytes(fileBytes, flush: true);
            written += 1;
          }
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
