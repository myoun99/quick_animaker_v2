import 'package:flutter/material.dart';

import '../../services/audio/audio_peaks_extractor.dart';

/// Paints a clip's |peak| envelope as a filled band mirrored around the
/// row's center line, along [axis] (horizontal timeline rows, vertical
/// X-sheet columns). The widget's main-axis extent is expected to be
/// `durationFrames(fps) * pixelsPerFrame` — each bucket maps to
/// `pixelsPerFrame * fps / bucketsPerSecond` pixels.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({
    required this.peaks,
    required this.fps,
    required this.pixelsPerFrame,
    required this.color,
    this.axis = Axis.horizontal,
  });

  final AudioPeaks peaks;
  final int fps;
  final double pixelsPerFrame;
  final Color color;
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (peaks.peaks.isEmpty || fps <= 0 || pixelsPerFrame <= 0) {
      return;
    }
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    final crossExtent = axis == Axis.horizontal ? size.height : size.width;
    final center = crossExtent / 2;
    final maxAmplitude = (crossExtent / 2) - 1;
    final pixelsPerBucket = pixelsPerFrame * fps / peaks.bucketsPerSecond;
    if (pixelsPerBucket <= 0) {
      return;
    }

    Offset at(double main, double cross) =>
        axis == Axis.horizontal ? Offset(main, cross) : Offset(cross, main);

    final path = Path();
    final top = <Offset>[];
    final bottom = <Offset>[];
    for (var bucket = 0; bucket < peaks.peaks.length; bucket += 1) {
      final main = bucket * pixelsPerBucket;
      if (main > mainExtent) {
        break;
      }
      final amplitude = peaks.peaks[bucket] * maxAmplitude;
      top.add(at(main, center - amplitude));
      bottom.add(at(main, center + amplitude));
    }
    if (top.isEmpty) {
      return;
    }
    path.moveTo(top.first.dx, top.first.dy);
    for (final point in top.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final point in bottom.reversed) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return !identical(oldDelegate.peaks, peaks) ||
        oldDelegate.fps != fps ||
        oldDelegate.pixelsPerFrame != pixelsPerFrame ||
        oldDelegate.color != color ||
        oldDelegate.axis != axis;
  }
}
