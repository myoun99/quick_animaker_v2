import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/dirty_region.dart';

/// Mutable state of the in-progress stroke overlay.
///
/// A lightweight editor-local [ChangeNotifier]: the interactive view blends
/// new dabs into its live CPU stroke buffer, records the touched region as a
/// [ui.Picture], and notifies — the canvas painter listens through the
/// `CustomPainter.repaint` hook, so pointer moves repaint the canvas
/// directly without rebuilding any widgets.
///
/// The overlay is picture-based on purpose: pictures are replayed at final
/// device resolution every frame and hold no GPU resources, so a lost or
/// recreated GPU context (e.g. switching app focus) can never corrupt what
/// they show. The previous representation — synchronously converting the
/// picture to a GPU image per move — was context-backed and flashed one
/// frame of garbage at exactly the moments those images were created or
/// disposed (stroke start/end).
class ActiveStrokeOverlayModel extends ChangeNotifier {
  /// Dabs of the current stroke, kept for observability and tests; rendering
  /// uses [pictures], which carry the exact rasterized pixels.
  final List<BrushDab> dabs = <BrushDab>[];

  final List<ui.Picture> _pictures = <ui.Picture>[];

  /// Stroke region pictures in paint order. Each picture replaces
  /// (`BlendMode.src`) the pixels its region covers, so replaying the list
  /// in order inside an isolated layer reproduces the live stroke buffer;
  /// see [strokeRegionPicture].
  late final List<ui.Picture> pictures = UnmodifiableListView(_pictures);

  /// Whether the overlay currently has stroke content to draw.
  bool get hasStrokeContent => _pictures.isNotEmpty;

  /// Appends the picture of a freshly rasterized region.
  void addRegionPicture(ui.Picture picture) {
    _pictures.add(picture);
  }

  /// Replaces the accumulated region pictures with one picture covering the
  /// whole stroke, capping the per-frame replay cost of long strokes.
  void replaceWithFlattened(ui.Picture flattened) {
    _disposePictures();
    _pictures.add(flattened);
  }

  /// Notifies listeners after the owner mutated the overlay content.
  void markChanged() => notifyListeners();

  /// Clears the overlay and disposes its pictures.
  void reset() {
    _disposePictures();
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposePictures();
    super.dispose();
  }

  void _disposePictures() {
    for (final picture in _pictures) {
      picture.dispose();
    }
    _pictures.clear();
  }
}

/// Records a dirty region of the straight-alpha live stroke buffer as a
/// picture of horizontal run rects at absolute canvas coordinates.
///
/// Horizontal runs of identical pixels collapse into single rects, so solid
/// stroke interiors record a handful of ops per row. Skia premultiplies the
/// straight-alpha colors when rasterizing with its own rounding — the same
/// conversion the committed tile images go through — keeping the live
/// overlay and the committed display byte-consistent.
///
/// Every rect paints with `BlendMode.src`: the buffer accumulates the whole
/// stroke, so a region pixel always carries the complete blended value, and
/// a later region picture must REPLACE the stale value an earlier picture
/// painted where they overlap (source-over would blend it twice). Skipping
/// transparent pixels is compatible with replacement because source-over
/// blending never decreases alpha: a pixel that is transparent now was
/// transparent in every earlier region too. Replacement blending is only
/// valid inside an isolated layer over the rest of the stroke — the painter
/// composes the pictures in a `saveLayer`, never on the view canvas.
ui.Picture strokeRegionPicture({
  required Uint8List pixels,
  required int canvasWidth,
  required DirtyRegion region,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint = Paint()
    ..isAntiAlias = false
    ..blendMode = BlendMode.src;

  for (var y = region.top; y < region.bottomExclusive; y += 1) {
    final rowOffset = y * canvasWidth;
    var x = region.left;
    while (x < region.rightExclusive) {
      final offset = (rowOffset + x) * 4;
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
      while (runEnd < region.rightExclusive) {
        final nextOffset = (rowOffset + runEnd) * 4;
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

  return recorder.endRecording();
}
