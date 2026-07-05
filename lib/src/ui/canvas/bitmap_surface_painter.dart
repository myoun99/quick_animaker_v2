import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import 'bitmap_tile_image_cache.dart';

/// Paints the committed brush artwork from the session bitmap surface.
///
/// Committed strokes are materialized into the surface on commit, so this
/// painter is the WYSIWYG base layer; the in-progress stroke renders above it
/// through `ActiveStrokeOverlayPainter`.
class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
    BitmapTileImageCache? tileImageCache,
  }) : tileImageCache = tileImageCache ?? BitmapTileImageCache.instance,
       super(repaint: tileImageCache ?? BitmapTileImageCache.instance);

  final BitmapSurface surface;
  final bool showTransparentBackground;
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
      // While this tile version's decode is pending, show the latest decoded
      // image at the same coordinate (slightly stale content) instead of a
      // per-pixel redraw: scanning up to 65k pixels per changed tile froze
      // the UI after large strokes. The active overlay keeps the in-progress
      // stroke visible until the new tiles are decoded.
      final tileImage =
          tileImageCache.imageFor(tile) ??
          tileImageCache.latestImageForCoord(tile.coord);
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
        // First-ever content at this coordinate and not decoded yet: draw
        // per pixel for this frame only.
        _paintTilePixels(canvas, tile);
      }
    }

    canvas.restore();
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

  @override
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate) {
    // Identity comparison: BitmapSurface is immutable with structural tile
    // sharing, so a changed surface is always a new instance. The previous
    // deep `!=` compared every tile's pixel bytes on each rebuild (megabytes
    // per pointer move while drawing).
    return !identical(oldDelegate.surface, surface) ||
        oldDelegate.showTransparentBackground != showTransparentBackground;
  }
}
