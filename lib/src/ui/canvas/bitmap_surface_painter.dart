import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';

class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
    this.committedSourceDabs = const <BrushDab>[],
    this.committedSourceDabStrokes = const <List<BrushDab>>[],
  });

  final BitmapSurface surface;
  final bool showTransparentBackground;
  final List<BrushDab> committedSourceDabs;
  final List<List<BrushDab>> committedSourceDabStrokes;

  @override
  void paint(Canvas canvas, Size size) {
    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    final pixelPaint = Paint()..style = PaintingStyle.fill;
    for (final tile in surface.tiles.values) {
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
  }

  @override
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate) {
    return oldDelegate.surface != surface ||
        oldDelegate.showTransparentBackground != showTransparentBackground;
  }
}
