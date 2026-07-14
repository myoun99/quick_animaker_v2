import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/models/dirty_region.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';
import 'package:quick_animaker_v2/src/services/brush_live_stroke_rasterizer.dart'
    show ActiveStrokePixelSource;
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_surface_painter.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_tile_image_cache.dart';

void main() {
  group('BitmapSurfacePainter', () {
    test('repaints when surface or transparent background setting changes', () {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
      );
      final same = BitmapSurfacePainter(surface: surface);

      expect(
        BitmapSurfacePainter(surface: surface).shouldRepaint(same),
        isFalse,
      );
      expect(
        BitmapSurfacePainter(
          surface: surface,
          showTransparentBackground: false,
        ).shouldRepaint(same),
        isTrue,
      );
      expect(
        BitmapSurfacePainter(
          surface: surface.copyWith(tileSize: 1),
        ).shouldRepaint(same),
        isTrue,
      );
    });

    test('does not depend on active stroke path or overlay state', () {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
      );
      final painter = BitmapSurfacePainter(surface: surface);

      expect(
        painter.shouldRepaint(BitmapSurfacePainter(surface: surface)),
        isFalse,
      );
    });

    test('draws RGBA tile pixels at global tile coordinates', () async {
      final firstTile = _tile(
        coord: TileCoord(x: 0, y: 0),
        size: 2,
        colors: {
          const _Point(1, 0): RgbaColor(r: 255, g: 0, b: 0, a: 255),
          const _Point(0, 1): RgbaColor(r: 0, g: 255, b: 0, a: 255),
        },
      );
      final secondTile = _tile(
        coord: TileCoord(x: 1, y: 0),
        size: 2,
        colors: {const _Point(0, 1): RgbaColor(r: 0, g: 0, b: 255, a: 255)},
      );
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 4, height: 2),
        tileSize: 2,
        tiles: {firstTile.coord: firstTile, secondTile.coord: secondTile},
      );

      final pixels = await _paintPixels(
        BitmapSurfacePainter(
          surface: surface,
          showTransparentBackground: false,
        ),
        width: 4,
        height: 2,
      );

      expect(_rgbaAt(pixels, width: 4, x: 1, y: 0), [255, 0, 0, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 0, y: 1), [0, 255, 0, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 2, y: 1), [0, 0, 255, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 0, y: 0), [0, 0, 0, 0]);
    });

    // Committed strokes are now materialized into the surface on commit and
    // painted from tile pixels; the painter no longer draws source-dab
    // stamps, so the old committedSourceDabStrokes square test was removed.

    // The live overlay now paints exact rasterized region sprites; its
    // rendering guarantees are covered by active_stroke_overlay_parity_test.

    test('draws deterministic neutral background when enabled', () async {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 1, height: 1),
      );

      final pixels = await _paintPixels(
        BitmapSurfacePainter(surface: surface),
        width: 1,
        height: 1,
      );

      expect(_rgbaAt(pixels, width: 1, x: 0, y: 0), [237, 237, 237, 255]);
    });
  });

  group('settle hold', () {
    final coord = TileCoord(x: 0, y: 0);
    final green = RgbaColor(r: 0, g: 255, b: 0, a: 255);
    final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
    final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);

    // The committed tile already contains the stroke (red); the pinned
    // pre-stroke tile does not (green). Painting the committed tile during
    // settling is what double-blended it with the overlay.
    BitmapSurface surface() {
      final newTile = _tile(
        coord: coord,
        size: 2,
        colors: {const _Point(0, 0): red},
      );
      final sideTile = _tile(
        coord: TileCoord(x: 1, y: 0),
        size: 2,
        colors: {const _Point(0, 1): blue},
      );
      return BitmapSurface(
        canvasSize: CanvasSize(width: 4, height: 2),
        tileSize: 2,
        tiles: {newTile.coord: newTile, sideTile.coord: sideTile},
      );
    }

    Future<Uint8List> paint(ActiveStrokeOverlayModel overlay) {
      return _paintPixels(
        BitmapSurfacePainter(
          surface: surface(),
          overlayModel: overlay,
          showTransparentBackground: false,
          tileImageCache: BitmapTileImageCache(),
        ),
        width: 4,
        height: 2,
      );
    }

    test('a pinned coordinate draws its PRE-stroke tile, not the committed '
        'one; unpinned coordinates are untouched', () async {
      final overlay = ActiveStrokeOverlayModel();
      addTearDown(overlay.dispose);
      overlay.holdPreStrokeTiles({
        coord: _tile(
          coord: coord,
          size: 2,
          colors: {const _Point(0, 0): green},
        ),
      });

      final pixels = await paint(overlay);

      expect(_rgbaAt(pixels, width: 4, x: 0, y: 0), [0, 255, 0, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 2, y: 1), [0, 0, 255, 255]);
    });

    test('a coordinate that was empty pre-stroke draws nothing while '
        'pinned', () async {
      final overlay = ActiveStrokeOverlayModel();
      addTearDown(overlay.dispose);
      overlay.holdPreStrokeTiles({coord: null});

      final pixels = await paint(overlay);

      expect(_rgbaAt(pixels, width: 4, x: 0, y: 0), [0, 0, 0, 0]);
    });

    test('reset releases the pin and the committed tile shows', () async {
      final overlay = ActiveStrokeOverlayModel();
      addTearDown(overlay.dispose);
      overlay.holdPreStrokeTiles({coord: null});
      overlay.reset();

      final pixels = await paint(overlay);

      expect(_rgbaAt(pixels, width: 4, x: 0, y: 0), [255, 0, 0, 255]);
    });
  });

  group('decode-start chunking (R18 B-1)', () {
    // 10×8 tile grid (80 tiles) — well over the per-paint start budget.
    BitmapSurface grid() {
      final tiles = <TileCoord, BitmapTile>{};
      for (var y = 0; y < 8; y += 1) {
        for (var x = 0; x < 10; x += 1) {
          final coord = TileCoord(x: x, y: y);
          tiles[coord] = BitmapTile.blank(coord: coord, size: 2);
        }
      }
      return BitmapSurface(
        canvasSize: CanvasSize(width: 20, height: 16),
        tileSize: 2,
        tiles: tiles,
      );
    }

    int pendingCount(BitmapTileImageCache cache, BitmapSurface surface) {
      var count = 0;
      for (final tile in surface.tiles.values) {
        if (cache.needsDecodeStart(tile)) {
          count += 1;
        }
      }
      return count;
    }

    void paintOnce(CustomPainter painter, Size size) {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), size);
      recorder.endRecording().dispose();
    }

    test('one paint starts at most decodeStartBudget decodes; repeated '
        'paints drain the rest', () {
      final cache = BitmapTileImageCache();
      final surface = grid();
      final painter = BitmapSurfacePainter(
        surface: surface,
        showTransparentBackground: false,
        tileImageCache: cache,
      );
      const budget = BitmapSurfacePainter.decodeStartBudget;

      expect(pendingCount(cache, surface), 80);
      paintOnce(painter, const Size(20, 16));
      expect(pendingCount(cache, surface), 80 - budget);
      paintOnce(painter, const Size(20, 16));
      expect(pendingCount(cache, surface), 80 - 2 * budget);
      paintOnce(painter, const Size(20, 16));
      expect(pendingCount(cache, surface), 0);
    });

    test('visible tiles start strictly before off-screen tiles', () {
      final cache = BitmapTileImageCache();
      final surface = grid();
      final painter = BitmapSurfacePainter(
        surface: surface,
        showTransparentBackground: false,
        tileImageCache: cache,
      );

      // Viewport-less paint sized to the left fifth of the canvas:
      // tiles at x∈{0,1} are visible (16), the other 64 are off-screen —
      // fewer visible tiles than the budget, so ALL of them must be in
      // the first chunk.
      paintOnce(painter, const Size(4, 16));

      for (final tile in surface.tiles.values) {
        if (tile.coord.x < 2) {
          expect(
            cache.needsDecodeStart(tile),
            isFalse,
            reason:
                'visible tile ${tile.coord} must start in the first '
                'chunk',
          );
        }
      }
      expect(
        pendingCount(cache, surface),
        80 - BitmapSurfacePainter.decodeStartBudget,
      );
    });

    test('a zoomed viewport prioritizes the tiles it actually shows', () {
      final cache = BitmapTileImageCache();
      final surface = grid();
      final painter = BitmapSurfacePainter(
        surface: surface,
        viewport: CanvasViewport(zoom: 4.0),
        showTransparentBackground: false,
        tileImageCache: cache,
      );

      // At zoom 4 a 4×8 widget shows canvas rect (0,0)-(1,2): only tile
      // (0,0) overlaps it — it must be in the first chunk.
      paintOnce(painter, const Size(4, 8));

      expect(
        cache.needsDecodeStart(surface.tiles[TileCoord(x: 0, y: 0)]!),
        isFalse,
        reason: 'the one visible tile must start in the first chunk',
      );
      expect(
        pendingCount(cache, surface),
        80 - BitmapSurfacePainter.decodeStartBudget,
      );
    });
  });

  group('live erase isolation (R14-⑤)', () {
    test('an erase overlay removes committed pixels but NEVER punches '
        'through content below the painter in the same buffer', () async {
      // Committed red pixel at (0,0).
      final tile = _tile(
        coord: TileCoord(x: 0, y: 0),
        size: 2,
        colors: {const _Point(0, 0): RgbaColor(r: 255, g: 0, b: 0, a: 255)},
      );
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
        tileSize: 2,
        tiles: {tile.coord: tile},
      );

      // A live ERASE stroke covering (0,0) at full alpha.
      final overlay = ActiveStrokeOverlayModel();
      addTearDown(overlay.dispose);
      overlay.erase = true;
      overlay.updateRegion(
        source: _AlphaAtOriginSource(),
        region: DirtyRegion(
          left: 0,
          top: 0,
          rightExclusive: 1,
          bottomExclusive: 1,
        ),
      );
      await overlay.waitForPendingDecodes();

      // The production layout: paper/panel pixels live BELOW the painter
      // in the same compositing buffer (the painter paints no background of
      // its own). Without the erase saveLayer isolation, dstOut punched
      // through the white too and the live stroke showed as the (dark)
      // panel background — the user's black-line eraser.
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 2, 2),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      BitmapSurfacePainter(
        surface: surface,
        overlayModel: overlay,
        showTransparentBackground: false,
        tileImageCache: BitmapTileImageCache(),
      ).paint(canvas, const Size(2, 2));
      final image = await recorder.endRecording().toImage(2, 2);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final pixels = byteData!.buffer.asUint8List();

      expect(
        _rgbaAt(pixels, width: 2, x: 0, y: 0),
        [255, 255, 255, 255],
        reason: 'the committed red erases; the white below survives',
      );
      expect(
        _rgbaAt(pixels, width: 2, x: 1, y: 1),
        [255, 255, 255, 255],
        reason: 'pixels the stroke never touched are unchanged',
      );
    });
  });
}

/// Full-alpha stroke coverage at canvas (0,0) only — a minimal live ERASE
/// stroke feed.
class _AlphaAtOriginSource implements ActiveStrokePixelSource {
  @override
  int get canvasWidth => 2;

  @override
  int get canvasHeight => 2;

  @override
  void copyRow(int x, int y, int count, Uint8List target, int targetOffset) {
    for (var i = 0; i < count; i += 1) {
      final offset = targetOffset + i * 4;
      final covered = (x + i) == 0 && y == 0;
      target[offset] = 0;
      target[offset + 1] = 0;
      target[offset + 2] = 0;
      target[offset + 3] = covered ? 255 : 0;
    }
  }
}

BitmapTile _tile({
  required TileCoord coord,
  required int size,
  required Map<_Point, RgbaColor> colors,
}) {
  var tile = BitmapTile.blank(coord: coord, size: size);
  for (final entry in colors.entries) {
    tile = writeRgbaColorToBitmapTile(
      tile: tile,
      x: entry.key.x,
      y: entry.key.y,
      color: entry.value,
    );
  }
  return tile;
}

Future<Uint8List> _paintPixels(
  CustomPainter painter, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

List<int> _rgbaAt(
  Uint8List pixels, {
  required int width,
  required int x,
  required int y,
}) {
  final offset = (y * width + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

class _Point {
  const _Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
