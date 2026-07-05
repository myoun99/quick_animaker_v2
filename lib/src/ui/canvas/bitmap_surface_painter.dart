import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/brush_dab.dart';
import 'bitmap_tile_image_cache.dart';

class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
    this.committedSourceDabs = const <BrushDab>[],
    this.committedSourceDabStrokes = const <List<BrushDab>>[],
    BitmapTileImageCache? tileImageCache,
  }) : tileImageCache = tileImageCache ?? BitmapTileImageCache.instance,
       super(repaint: tileImageCache ?? BitmapTileImageCache.instance);

  final BitmapSurface surface;
  final bool showTransparentBackground;
  final List<BrushDab> committedSourceDabs;
  final List<List<BrushDab>> committedSourceDabStrokes;
  final BitmapTileImageCache tileImageCache;

  @override
  void paint(Canvas canvas, Size size) {
    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    // Tiles can only carry pixels inside the canvas, but clip anyway so a
    // decoded tile image can never bleed past the canvas edge.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        surface.canvasSize.width.toDouble(),
        surface.canvasSize.height.toDouble(),
      ),
    );

    final tileImagePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (final tile in surface.tiles.values) {
      tileImageCache.ensureDecoded(tile);
      final tileImage = tileImageCache.imageFor(tile);
      if (tileImage != null) {
        canvas.drawImage(
          tileImage,
          Offset(
            (tile.coord.x * tile.size).toDouble(),
            (tile.coord.y * tile.size).toDouble(),
          ),
          tileImagePaint,
        );
      } else {
        // Decode still pending: draw this tile per pixel for this frame.
        _paintTilePixels(canvas, tile);
      }
    }

    canvas.restore();

    _paintCommittedSourceDabs(canvas);
  }

  void _paintTilePixels(Canvas canvas, BitmapTile tile) {
    final pixelPaint = Paint()..style = PaintingStyle.fill;
    final pixels = tile.pixels;
    final tileOriginX = tile.coord.x * tile.size;
    final tileOriginY = tile.coord.y * tile.size;

    for (var localY = 0; localY < tile.size; localY += 1) {
      final globalY = tileOriginY + localY;
      if (globalY < 0 || globalY >= surface.canvasSize.height) {
        continue;
      }

      for (var localX = 0; localX < tile.size; localX += 1) {
        final globalX = tileOriginX + localX;
        if (globalX < 0 || globalX >= surface.canvasSize.width) {
          continue;
        }

        final offset = (localY * tile.size + localX) * 4;
        final r = pixels[offset];
        final g = pixels[offset + 1];
        final b = pixels[offset + 2];
        final a = pixels[offset + 3];
        if (a == 0) {
          continue;
        }

        pixelPaint.color = Color.fromARGB(a, r, g, b);
        canvas.drawRect(
          Rect.fromLTWH(globalX.toDouble(), globalY.toDouble(), 1, 1),
          pixelPaint,
        );
      }
    }
  }

  void _paintCommittedSourceDabs(Canvas canvas) {
    if (committedSourceDabStrokes.isEmpty) {
      _paintDabs(canvas, committedSourceDabs);
      return;
    }

    for (final stroke in committedSourceDabStrokes) {
      _paintDabs(canvas, stroke);
    }
  }

  void _paintDabs(Canvas canvas, List<BrushDab> dabs) {
    if (dabs.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    for (final dab in dabs) {
      paint.color = _colorForDab(dab);
      _paintPixelGridStamp(canvas, paint, dab);
    }
  }

  void _paintPixelGridStamp(Canvas canvas, Paint paint, BrushDab dab) {
    final diameter = dab.size.clamp(1, double.infinity).ceilToDouble();
    final left = (dab.center.x - diameter / 2).roundToDouble();
    final top = (dab.center.y - diameter / 2).roundToDouble();
    canvas.drawRect(Rect.fromLTWH(left, top, diameter, diameter), paint);
  }

  Color _colorForDab(BrushDab dab) {
    final argb = dab.color;
    final alpha = (argb >> 24) & 0xFF;
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return Color.fromARGB(
      (alpha * dab.opacity).clamp(0, 255).round(),
      red,
      green,
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate) {
    // Identity comparison: BitmapSurface is immutable with structural tile
    // sharing, so a changed surface is always a new instance. The previous
    // deep `!=` compared every tile's pixel bytes on each rebuild (megabytes
    // per pointer move while drawing).
    return !identical(oldDelegate.surface, surface) ||
        oldDelegate.showTransparentBackground != showTransparentBackground ||
        oldDelegate.committedSourceDabs != committedSourceDabs ||
        oldDelegate.committedSourceDabStrokes != committedSourceDabStrokes;
  }
}
