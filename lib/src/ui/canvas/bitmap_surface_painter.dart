import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../services/bitmap_tile_rgba.dart';

class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
  });

  final BitmapSurface surface;
  final bool showTransparentBackground;

  @override
  void paint(Canvas canvas, Size size) {
    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    final pixelPaint = Paint()..style = PaintingStyle.fill;
    for (final tile in surface.tiles.values) {
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

          final color = readRgbaColorFromBitmapTile(
            tile: tile,
            x: localX,
            y: localY,
          );
          if (color.a == 0) {
            continue;
          }

          pixelPaint.color = Color.fromARGB(
            color.a,
            color.r,
            color.g,
            color.b,
          );
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
