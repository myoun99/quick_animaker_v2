import 'dart:io';
import 'dart:ui' as ui;

import '../camera/camera_frame_render_service.dart';

/// Streams a rendered frame sequence to disk as `frame_0001.png`… — one
/// frame rendered, encoded and released at a time, so a full-resolution
/// sequence never lives in memory at once.
class PngSequenceExportService {
  const PngSequenceExportService();

  Future<void> exportFrames({
    required int frameCount,
    required Future<ui.Image> Function(int frameIndex) renderFrame,
    required String directoryPath,
    void Function(int completed, int total)? onProgress,
  }) async {
    for (var index = 0; index < frameCount; index += 1) {
      final image = await renderFrame(index);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$directoryPath${Platform.pathSeparator}${cameraSequenceFileName(index)}',
        ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      } finally {
        image.dispose();
      }
      onProgress?.call(index + 1, frameCount);
    }
  }
}
