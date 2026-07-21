import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/canvas_viewport.dart';
import '../../models/pasteboard_bounds.dart';
import 'active_stroke_overlay.dart';
import 'bitmap_tile_image_cache.dart';
import 'viewport_canvas_transform.dart';

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
    final pasteboardRect = Rect.fromLTRB(
      surface.canvasSize.pasteboardLeft.toDouble(),
      surface.canvasSize.pasteboardTop.toDouble(),
      surface.canvasSize.pasteboardRightExclusive.toDouble(),
      surface.canvasSize.pasteboardBottomExclusive.toDouble(),
    );

    canvas.save();
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      applyViewportTransform(canvas, resolvedViewport);
    }
    // The clip is the PASTEBOARD: artwork past the canvas edge stays
    // visible while editing (dimmed below); composite/export raster at
    // canvas size, so output still crops to the stage.
    canvas.clipRect(pasteboardRect);

    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
        backgroundPaint,
      );
    }

    // An erasing overlay draws destination-out against the committed tiles.
    // The tiles + overlay MUST be isolated in their own layer: without it,
    // dstOut applies to the whole accumulated compositing buffer — the
    // painter's own background here, and in the production editing path
    // (paper in the separate underlay widget) the paper and panel chrome
    // BELOW this picture, which showed live erase strokes as dark
    // panel-background lines until the commit landed (R14-⑤). The layer
    // makes the hole transparent so whatever is underneath shows through.
    final eraseOverlayLayer =
        overlayModel != null &&
        overlayModel!.erase &&
        overlayModel!.hasStrokeContent;
    if (eraseOverlayLayer) {
      canvas.saveLayer(pasteboardRect, Paint());
    }

    final tileImagePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    // While a stroke settles, coordinates it touched draw their pinned
    // PRE-stroke tile (or nothing if the coordinate was empty) instead of
    // the committed tile: post-commit decodes land one by one, and drawing
    // them under the still-visible overlay flashed the stroke at double
    // density in tile-shaped patches. The pin and the overlay clear in one
    // notification, so the swap to committed pixels is atomic.
    final settleHold = overlayModel?.settleHoldTiles;
    // Per-pixel fallback budget (R17 measured): the first paint after a
    // FULL-CANVAS commit (a fill/lift stamp) used to draw ~130 undecoded
    // tiles pixel-by-pixel — 65k rects per tile, the multi-second "first
    // fill" freeze. A few tiles are fine; past the budget the tile waits
    // for its decode (it lands within a few frames — the repaint hook
    // brings it in).
    var pixelFallbackBudget = 4;
    // Decode-start chunking (R18 B-1): STARTING a decode costs a
    // synchronous tile copy + 65k-pixel premultiply on the UI thread, and
    // a full-canvas commit used to start every changed tile in one paint
    // (~130+ tiles — the post-commit hitch the R17 probe measured).
    // Pending tiles are collected here and at most [decodeStartBudget]
    // start per paint, visible tiles center-out first; each completion
    // notifies (coalesced per frame), which repaints this painter and
    // starts the next chunk, so the surface converges over a few frames
    // while the stale/settle-hold fallbacks keep on-screen content stable.
    List<BitmapTile>? pendingDecodes;
    for (final tile in surface.tiles.values) {
      if (tileImageCache.needsDecodeStart(tile)) {
        (pendingDecodes ??= <BitmapTile>[]).add(tile);
      }
      if (settleHold != null && settleHold.containsKey(tile.coord)) {
        final preTile = settleHold[tile.coord];
        if (preTile != null) {
          final preImage = tileImageCache.imageFor(preTile);
          if (preImage != null) {
            canvas.drawImage(
              preImage,
              Offset(
                (preTile.coord.x * preTile.size).toDouble(),
                (preTile.coord.y * preTile.size).toDouble(),
              ),
              tileImagePaint,
            );
          } else {
            _paintTilePixels(canvas, preTile);
          }
        }
        continue;
      }
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
      } else if (pixelFallbackBudget > 0) {
        // First-ever content at this coordinate and not decoded yet: draw
        // per pixel for this frame only — within the budget.
        pixelFallbackBudget -= 1;
        _paintTilePixels(canvas, tile);
      }
    }
    if (pendingDecodes != null) {
      _startPrioritizedDecodes(pendingDecodes, size);
    }

    final overlay = overlayModel;
    if (overlay != null) {
      // The live stroke renders through the EXACT pipeline the committed
      // tiles use — premultiplied bytes decoded to images, drawn with
      // nearest sampling — so live and committed pixels rasterize
      // identically at any zoom (one code path; rect-geometry replay
      // diverged from image sampling at fractional zoom). Overlay tiles
      // never overlap, so plain source-over per tile is exact. An ERASE
      // stroke draws destination-out instead: the accumulated stroke alpha
      // removes committed pixels exactly like the commit pass will.
      final overlayPaint = overlay.erase
          ? (Paint()
              ..filterQuality = FilterQuality.none
              ..isAntiAlias = false
              ..blendMode = BlendMode.dstOut)
          : tileImagePaint;
      final overlayTileSize = overlay.tileSize.toDouble();
      for (final entry in overlay.tileImages.entries) {
        canvas.drawImage(
          entry.value,
          Offset(entry.key.x * overlayTileSize, entry.key.y * overlayTileSize),
          overlayPaint,
        );
      }
      // R23: a fill tap's overlay is ONE pre-decoded stamp image at the
      // commit's exact placement (never coexists with stroke tiles).
      final stampImage = overlay.stampImage;
      if (stampImage != null) {
        canvas.drawImage(stampImage, overlay.stampOffset, overlayPaint);
      }
    }

    if (eraseOverlayLayer) {
      canvas.restore();
    }

    // No pasteboard dim (user decision, Flash-style): off-canvas artwork
    // shows at full brightness — the paper edge against the backdrop is
    // the stage boundary.

    canvas.restore();
  }

  /// Maximum decode STARTS per paint. Completions notify → repaint → the
  /// next chunk starts, so pending tiles always drain; the value trades
  /// per-frame UI-thread cost (copy + premultiply per start) against how
  /// many frames a full-canvas convergence takes.
  static const int decodeStartBudget = BitmapTileImageCache.decodeStartBudget;

  /// Starts up to [decodeStartBudget] of [pending]'s decodes — when over
  /// budget, tiles overlapping the visible canvas rect go first (nearest
  /// the view center), off-screen tiles strictly after.
  void _startPrioritizedDecodes(List<BitmapTile> pending, Size size) {
    var ordered = pending;
    if (pending.length > decodeStartBudget) {
      final resolvedViewport = viewport;
      final visibleRect = resolvedViewport == null
          ? (Offset.zero & size)
          : MatrixUtils.transformRect(
              viewportInverseTransformMatrix(resolvedViewport),
              Offset.zero & size,
            );
      final center = visibleRect.center;
      // Dominates any real distance² (canvas diagonals stay far below),
      // so off-screen tiles sort after every visible one.
      const offscreenBias = 1e18;
      double score(BitmapTile tile) {
        final tileSize = tile.size.toDouble();
        final rect = Rect.fromLTWH(
          tile.coord.x * tileSize,
          tile.coord.y * tileSize,
          tileSize,
          tileSize,
        );
        final distance = (rect.center - center).distanceSquared;
        return rect.overlaps(visibleRect) ? distance : distance + offscreenBias;
      }

      final scored = [
        for (final tile in pending) (score: score(tile), tile: tile),
      ];
      scored.sort((a, b) => a.score.compareTo(b.score));
      ordered = [for (final entry in scored) entry.tile];
    }
    final startCount = ordered.length < decodeStartBudget
        ? ordered.length
        : decodeStartBudget;
    for (var i = 0; i < startCount; i += 1) {
      tileImageCache.ensureDecoded(ordered[i], staleScope: staleScope);
    }
  }

  void _paintTilePixels(Canvas canvas, BitmapTile tile) {
    final pixelPaint = Paint()..style = PaintingStyle.fill;
    final pixels = tile.pixels;
    final tileOriginX = tile.coord.x * tile.size;
    final tileOriginY = tile.coord.y * tile.size;

    for (var localY = 0; localY < tile.size; localY += 1) {
      final globalY = tileOriginY + localY;
      if (globalY < surface.canvasSize.pasteboardTop ||
          globalY >= surface.canvasSize.pasteboardBottomExclusive) {
        continue;
      }

      for (var localX = 0; localX < tile.size; localX += 1) {
        final globalX = tileOriginX + localX;
        if (globalX < surface.canvasSize.pasteboardLeft ||
            globalX >= surface.canvasSize.pasteboardRightExclusive) {
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
