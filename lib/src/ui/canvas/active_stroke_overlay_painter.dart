import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/dirty_region.dart';

/// One pre-rendered piece of the in-progress stroke: an exact GPU copy of a
/// dirty region of the live CPU stroke buffer.
class ActiveStrokeOverlaySegment {
  ActiveStrokeOverlaySegment({required this.image, required this.offset});

  final ui.Image image;
  final Offset offset;

  void dispose() => image.dispose();
}

/// Mutable state of the in-progress stroke overlay.
///
/// A lightweight editor-local [ChangeNotifier]: the interactive view blends
/// new dabs into its live CPU stroke buffer, converts the touched region to a
/// segment sprite, and notifies — the overlay painter listens through the
/// `CustomPainter.repaint` hook, so pointer moves repaint the overlay layer
/// directly without rebuilding any widgets.
class ActiveStrokeOverlayModel extends ChangeNotifier {
  /// Dabs of the current stroke, kept for observability and tests; rendering
  /// uses [segments]/[flattened], which carry the exact rasterized pixels.
  final List<BrushDab> dabs = <BrushDab>[];

  /// Region sprites in paint order. Later segments contain the accumulated
  /// buffer content for their region, so they are drawn with
  /// [BlendMode.src] and the overlay always equals the live buffer.
  final List<ActiveStrokeOverlaySegment> segments =
      <ActiveStrokeOverlaySegment>[];

  /// Older segments folded into one canvas-sized image so repaints and
  /// flattens never re-touch the whole stroke.
  ui.Image? flattened;

  /// Notifies listeners after the owner mutated the overlay content.
  void markChanged() => notifyListeners();

  /// Clears the overlay and disposes all images.
  void reset() {
    flattened?.dispose();
    flattened = null;
    for (final segment in segments) {
      segment.dispose();
    }
    segments.clear();
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    flattened?.dispose();
    flattened = null;
    for (final segment in segments) {
      segment.dispose();
    }
    segments.clear();
    super.dispose();
  }
}

/// Converts a dirty region of a straight-alpha canvas RGBA buffer into a
/// small GPU image, synchronously.
///
/// Horizontal runs of identical pixels collapse into single rects, so solid
/// stroke interiors record a handful of ops per row. Skia premultiplies the
/// straight-alpha colors on record with its own rounding — the same
/// conversion the committed tile images go through — keeping the live
/// overlay and the committed display byte-consistent.
ui.Image strokeRegionSprite({
  required Uint8List pixels,
  required int canvasWidth,
  required DirtyRegion region,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()..isAntiAlias = false;
  final width = region.rightExclusive - region.left;
  final height = region.bottomExclusive - region.top;

  for (var y = 0; y < height; y += 1) {
    final rowOffset = (region.top + y) * canvasWidth;
    var x = 0;
    while (x < width) {
      final offset = (rowOffset + region.left + x) * 4;
      final a = pixels[offset + 3];
      if (a == 0) {
        x += 1;
        continue;
      }
      final r = pixels[offset];
      final g = pixels[offset + 1];
      final b = pixels[offset + 2];

      // Extend the run while the pixel value repeats.
      var runEnd = x + 1;
      while (runEnd < width) {
        final nextOffset = (rowOffset + region.left + runEnd) * 4;
        if (pixels[nextOffset + 3] != a ||
            pixels[nextOffset] != r ||
            pixels[nextOffset + 1] != g ||
            pixels[nextOffset + 2] != b) {
          break;
        }
        runEnd += 1;
      }

      paint.color = Color.fromARGB(a, r, g, b);
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), y.toDouble(), (runEnd - x).toDouble(), 1),
        paint,
      );
      x = runEnd;
    }
  }

  final picture = recorder.endRecording();
  final image = picture.toImageSync(width, height);
  picture.dispose();
  return image;
}

/// Paints the in-progress stroke from its exact rasterized pixels.
///
/// The live stroke is CPU-rasterized incrementally with the same math as the
/// commit path (`BrushLiveStrokeRasterizer`), so what this painter shows is
/// byte-identical to what pen-up commits — the fundamental unification of
/// live and committed pixels. No bitmap work happens per repaint: it draws
/// the flattened image plus a bounded number of region sprites.
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({this.model}) : super(repaint: model);

  /// Live overlay state; pointer moves repaint this painter through the
  /// model's notifications without any widget rebuild.
  final ActiveStrokeOverlayModel? model;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayModel = model;
    if (overlayModel == null) {
      return;
    }

    final flattened = overlayModel.flattened;
    if (flattened != null) {
      canvas.drawImage(
        flattened,
        Offset.zero,
        Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none,
      );
    }
    // Each segment carries the accumulated buffer for its region, so src
    // replacement keeps the overlay exactly equal to the live buffer even
    // where segments overlap.
    final segmentPaint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none
      ..blendMode = BlendMode.src;
    for (final segment in overlayModel.segments) {
      canvas.drawImage(segment.image, segment.offset, segmentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ActiveStrokeOverlayPainter oldDelegate) {
    return !identical(oldDelegate.model, model);
  }
}
