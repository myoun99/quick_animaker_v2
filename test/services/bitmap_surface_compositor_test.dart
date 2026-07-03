import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/dirty_tile_set.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_compositor.dart';
import 'package:quick_animaker_v2/src/services/rgba_blend.dart';

void main() {
  group('BitmapSurfaceCompositor', () {
    final canvasSize = CanvasSize(width: 2, height: 2);
    const tileSize = 2;
    final coord = TileCoord(x: 0, y: 0);

    test(
      'keeps straight-alpha color when compositing over transparent base',
      () {
        final compositor = BitmapSurfaceCompositor();
        final base = BitmapSurface(canvasSize: canvasSize, tileSize: tileSize);
        final overlay =
            BitmapSurface(canvasSize: canvasSize, tileSize: tileSize).putTile(
              _tileWithPixel(
                coord: coord,
                tileSize: tileSize,
                x: 0,
                y: 0,
                color: RgbaColor(r: 255, g: 0, b: 0, a: 128),
              ),
            );

        final result = compositor.composite(
          baseSurface: base,
          overlaySurface: overlay,
        );

        final pixel = _readPixel(result.tileAt(coord)!, x: 0, y: 0);
        expect(pixel, RgbaColor(r: 255, g: 0, b: 0, a: 128));
      },
    );

    test('matches rgbaSourceOver for semi-transparent overlay', () {
      final compositor = BitmapSurfaceCompositor();
      final baseColor = RgbaColor(r: 0, g: 0, b: 255, a: 128);
      final overlayColor = RgbaColor(r: 255, g: 0, b: 0, a: 128);
      final expected = rgbaSourceOver(
        source: overlayColor,
        destination: baseColor,
        opacity: 1.0,
        flow: 1.0,
      );

      final base = BitmapSurface(canvasSize: canvasSize, tileSize: tileSize)
          .putTile(
            _tileWithPixel(
              coord: coord,
              tileSize: tileSize,
              x: 0,
              y: 0,
              color: baseColor,
            ),
          );
      final overlay = BitmapSurface(canvasSize: canvasSize, tileSize: tileSize)
          .putTile(
            _tileWithPixel(
              coord: coord,
              tileSize: tileSize,
              x: 0,
              y: 0,
              color: overlayColor,
            ),
          );

      final result = compositor.composite(
        baseSurface: base,
        overlaySurface: overlay,
      );

      final pixel = _readPixel(result.tileAt(coord)!, x: 0, y: 0);
      expect(pixel, expected);
    });

    test('composites only requested dirty tiles', () {
      final compositor = BitmapSurfaceCompositor();
      final cleanCoord = TileCoord(x: 0, y: 0);
      final dirtyCoord = TileCoord(x: 1, y: 0);

      final base = BitmapSurface(
        canvasSize: CanvasSize(width: 4, height: 2),
        tileSize: tileSize,
      );
      final overlay =
          BitmapSurface(
                canvasSize: CanvasSize(width: 4, height: 2),
                tileSize: tileSize,
              )
              .putTile(
                _tileWithPixel(
                  coord: cleanCoord,
                  tileSize: tileSize,
                  x: 0,
                  y: 0,
                  color: RgbaColor(r: 255, g: 0, b: 0, a: 255),
                ),
              )
              .putTile(
                _tileWithPixel(
                  coord: dirtyCoord,
                  tileSize: tileSize,
                  x: 0,
                  y: 0,
                  color: RgbaColor(r: 0, g: 255, b: 0, a: 255),
                ),
              );

      final result = compositor.compositeTiles(
        baseSurface: base,
        overlaySurface: overlay,
        dirtyTiles: DirtyTileSet({dirtyCoord}),
      );

      expect(result.tileAt(cleanCoord), isNull);
      expect(
        _readPixel(result.tileAt(dirtyCoord)!, x: 0, y: 0),
        RgbaColor(r: 0, g: 255, b: 0, a: 255),
      );
    });
  });
}

BitmapTile _tileWithPixel({
  required TileCoord coord,
  required int tileSize,
  required int x,
  required int y,
  required RgbaColor color,
}) {
  final pixels = Uint8List(tileSize * tileSize * BitmapTile.bytesPerPixel);
  final offset = (y * tileSize + x) * BitmapTile.bytesPerPixel;
  pixels[offset] = color.r;
  pixels[offset + 1] = color.g;
  pixels[offset + 2] = color.b;
  pixels[offset + 3] = color.a;
  return BitmapTile(coord: coord, size: tileSize, pixels: pixels);
}

RgbaColor _readPixel(BitmapTile tile, {required int x, required int y}) {
  final pixels = tile.pixels;
  final offset = (y * tile.size + x) * BitmapTile.bytesPerPixel;
  return RgbaColor(
    r: pixels[offset],
    g: pixels[offset + 1],
    b: pixels[offset + 2],
    a: pixels[offset + 3],
  );
}
