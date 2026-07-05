import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/dirty_region.dart';

/// Mutable state of the in-progress stroke overlay.
///
/// A lightweight editor-local [ChangeNotifier]: the interactive view blends
/// new dabs into its live CPU stroke buffer, folds the touched region into
/// [overlayImage], and notifies — the overlay painter listens through the
/// `CustomPainter.repaint` hook, so pointer moves repaint the overlay layer
/// directly without rebuilding any widgets.
class ActiveStrokeOverlayModel extends ChangeNotifier {
  /// Dabs of the current stroke, kept for observability and tests; rendering
  /// uses [overlayImage], which carries the exact rasterized pixels.
  final List<BrushDab> dabs = <BrushDab>[];

  /// Canvas-sized image equal to the live stroke buffer. Composition happens
  /// off-screen in image space (integer pixel grid), so the on-screen painter
  /// only ever draws this image with plain source-over — replacement blending
  /// on the screen canvas would clip along fractional-zoom device pixels.
  ui.Image? overlayImage;

  /// Notifies listeners after the owner mutated the overlay content.
  void markChanged() => notifyListeners();

  /// Clears the overlay and disposes the image.
  void reset() {
    overlayImage?.dispose();
    overlayImage = null;
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    overlayImage?.dispose();
    overlayImage = null;
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

/// Folds a freshly rasterized region into the canvas-sized overlay image.
///
/// Runs entirely in image space (no view transform), so the src replacement
/// of the region lands on exact integer pixels regardless of the on-screen
/// zoom. Returns the new overlay image; the caller owns disposal of the
/// previous one.
ui.Image composeOverlayImage({
  required ui.Image? previous,
  required ui.Image regionSprite,
  required Offset regionOffset,
  required int canvasWidth,
  required int canvasHeight,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final basePaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;
  if (previous != null) {
    canvas.drawImage(previous, Offset.zero, basePaint);
  }
  final regionPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none
    ..blendMode = BlendMode.src;
  canvas.drawImage(regionSprite, regionOffset, regionPaint);
  final picture = recorder.endRecording();
  final image = picture.toImageSync(canvasWidth, canvasHeight);
  picture.dispose();
  return image;
}

/// Paints the in-progress stroke from its exact rasterized pixels.
///
/// The live stroke is CPU-rasterized incrementally with the same math as the
/// commit path (`BrushLiveStrokeRasterizer`), so what this painter shows is
/// byte-identical to what pen-up commits — the fundamental unification of
/// live and committed pixels. The painter itself is trivial: one plain
/// source-over image draw, which is stable at any fractional zoom.
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({this.model}) : super(repaint: model);

  /// Live overlay state; pointer moves repaint this painter through the
  /// model's notifications without any widget rebuild.
  final ActiveStrokeOverlayModel? model;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayImage = model?.overlayImage;
    if (overlayImage == null) {
      return;
    }
    canvas.drawImage(
      overlayImage,
      Offset.zero,
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokeOverlayPainter oldDelegate) {
    return !identical(oldDelegate.model, model);
  }
}
