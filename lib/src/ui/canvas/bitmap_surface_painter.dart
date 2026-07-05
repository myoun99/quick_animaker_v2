import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/canvas_viewport.dart';
import 'active_stroke_overlay.dart';
import 'bitmap_tile_image_cache.dart';

/// Paints the brush canvas — committed artwork plus the in-progress stroke —
/// with the viewport transform applied INSIDE the picture.
///
/// The zoom/pan used to live in a Transform widget above the paint layers.
/// Under a fractional zoom the compositor then resampled each rasterized
/// layer texture through the transform, and starting/stopping the overlay's
/// per-move repaints changed how that resampling landed — boundary pixels of
/// every line on the canvas visibly jittered while drawing (stable at 100% /
/// 200% where texel edges align with device pixels). Applying
/// `canvas.translate/scale` here means every frame rasterizes the canvas
/// content directly at final resolution through one code path, so idle and
/// drawing frames are pixel-identical at any zoom by construction.
class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.viewport,
    this.overlayModel,
    this.showTransparentBackground = true,
    this.staleScope,
    BitmapTileImageCache? tileImageCache,
  }) : tileImageCache = tileImageCache ?? BitmapTileImageCache.instance,
       super(
         repaint: Listenable.merge([
           tileImageCache ?? BitmapTileImageCache.instance,
           ?overlayModel,
         ]),
       );

  final BitmapSurface surface;

  /// Zoom/pan applied inside the picture; `null` paints at identity.
  final CanvasViewport? viewport;

  /// Live in-progress stroke; drawn above the committed tiles with plain
  /// source-over. Its notifications repaint this painter directly.
  final ActiveStrokeOverlayModel? overlayModel;

  final bool showTransparentBackground;

  /// Identifies this surface's lineage (e.g. the brush frame) so the stale
  /// tile fallback never shows another frame's artwork; see
  /// [BitmapTileImageCache.latestImageForCoord].
  final Object? staleScope;

  final BitmapTileImageCache tileImageCache;

  @override
  void paint(Canvas canvas, Size size) {
    final canvasWidth = surface.canvasSize.width.toDouble();
    final canvasHeight = surface.canvasSize.height.toDouble();

    canvas.save();
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      canvas.translate(resolvedViewport.panX, resolvedViewport.panY);
      canvas.scale(resolvedViewport.zoom, resolvedViewport.zoom);
    }
    canvas.clipRect(Rect.fromLTWH(0, 0, canvasWidth, canvasHeight));

    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        backgroundPaint,
      );
    }

    final tileImagePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (final tile in surface.tiles.values) {
      tileImageCache.ensureDecoded(tile, staleScope: staleScope);
      // While this tile version's decode is pending, show the latest decoded
      // image at the same coordinate (slightly stale content) instead of a
      // per-pixel redraw: scanning up to 65k pixels per changed tile froze
      // the UI after large strokes. The active overlay keeps the in-progress
      // stroke visible until the new tiles are decoded.
      final tileImage =
          tileImageCache.imageFor(tile) ??
          tileImageCache.latestImageForCoord(tile.coord, scope: staleScope);
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

    final overlay = overlayModel;
    if (overlay != null) {
      // The live stroke renders through the EXACT pipeline the committed
      // tiles use — premultiplied bytes decoded to images, drawn with
      // nearest sampling — so live and committed pixels rasterize
      // identically at any zoom (one code path; rect-geometry replay
      // diverged from image sampling at fractional zoom). Overlay tiles
      // never overlap, so plain source-over per tile is exact.
      final overlayTileSize = overlay.tileSize.toDouble();
      for (final entry in overlay.tileImages.entries) {
        canvas.drawImage(
          entry.value,
          Offset(
            entry.key.x * overlayTileSize,
            entry.key.y * overlayTileSize,
          ),
          tileImagePaint,
        );
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
        oldDelegate.showTransparentBackground != showTransparentBackground ||
        oldDelegate.viewport != viewport ||
        !identical(oldDelegate.overlayModel, overlayModel);
  }
}
