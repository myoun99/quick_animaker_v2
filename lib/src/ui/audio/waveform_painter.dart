import 'dart:math' as math;

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
    this.leadingFrames = 0,
    this.gain = 1.0,
    this.fadeInFrames = 0,
    this.fadeOutFrames = 0,
  });

  final AudioPeaks peaks;
  final int fps;
  final double pixelsPerFrame;
  final Color color;
  final Axis axis;

  /// Frames skipped into the FILE before main-axis 0 — the clip's
  /// offsetFrames trim: the envelope starts mid-file, so the painted band
  /// stays aligned with what actually plays.
  final int leadingFrames;

  /// The clip's volume envelope, drawn INTO the band (amplitudes scale
  /// with what actually plays): [gain] scales the whole envelope (capped
  /// at 1 — the band cannot outgrow the row), [fadeInFrames] ramps up from
  /// the span start and [fadeOutFrames] ramps down toward the audible end
  /// (span end or file end, whichever comes first).
  final double gain;
  final int fadeInFrames;
  final int fadeOutFrames;

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
    final leadingPixels = leadingFrames * pixelsPerFrame;
    final startBucket = leadingPixels <= 0
        ? 0
        : (leadingPixels / pixelsPerBucket).floor();

    // Where the audible part ends on the main axis: the span's own end or
    // the file running out, whichever is first — the fade-out anchor.
    final audibleEndPixels = math.min(
      mainExtent,
      (peaks.durationFrames(fps) - leadingFrames) * pixelsPerFrame,
    );
    final fadeInPixels = fadeInFrames * pixelsPerFrame;
    final fadeOutPixels = fadeOutFrames * pixelsPerFrame;
    final envelopeGain = math.min(1.0, gain);

    double envelopeAt(double main) {
      var factor = envelopeGain;
      if (fadeInPixels > 0 && main < fadeInPixels) {
        factor *= math.max(0, main / fadeInPixels);
      }
      final remaining = audibleEndPixels - main;
      if (fadeOutPixels > 0 && remaining < fadeOutPixels) {
        factor *= math.max(0, remaining / fadeOutPixels);
      }
      return factor;
    }

    Offset at(double main, double cross) =>
        axis == Axis.horizontal ? Offset(main, cross) : Offset(cross, main);

    final path = Path();
    final top = <Offset>[];
    final bottom = <Offset>[];
    for (var bucket = startBucket; bucket < peaks.peaks.length; bucket += 1) {
      final main = bucket * pixelsPerBucket - leadingPixels;
      if (main < 0) {
        continue;
      }
      if (main > mainExtent) {
        break;
      }
      final amplitude = peaks.peaks[bucket] * maxAmplitude * envelopeAt(main);
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
        oldDelegate.axis != axis ||
        oldDelegate.leadingFrames != leadingFrames ||
        oldDelegate.gain != gain ||
        oldDelegate.fadeInFrames != fadeInFrames ||
        oldDelegate.fadeOutFrames != fadeOutFrames;
  }
}
