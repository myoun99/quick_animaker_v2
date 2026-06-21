import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_pixel_blend_operation.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_operation_delta.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';

void main() {
  final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
  final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
  final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);

  BitmapTile blankTile({int tileX = 0, int tileY = 0, int size = 2}) {
    return BitmapTile.blank(
      coord: TileCoord(x: tileX, y: tileY),
      size: size,
    );
  }

  BrushPixelBlendOperation op({
    required int x,
    required int y,
    required RgbaColor before,
    required RgbaColor after,
  }) {
    return BrushPixelBlendOperation(x: x, y: y, before: before, after: after);
  }

  BitmapSurface surfaceWith(BitmapTile tile) {
    return BitmapSurface(
      canvasSize: CanvasSize(width: tile.size * 3, height: tile.size * 3),
      tileSize: tile.size,
      tiles: {tile.coord: tile},
    );
  }

  group('tileDeltaCommandForBitmapTileOperations', () {
    test('returns null when operations is empty', () {
      final tile = blankTile();

      final result = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: const [],
      );

      expect(result, isNull);
    });

    test('returns null when no operation affects tile', () {
      final tile = blankTile(size: 2);

      final result = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 2, y: 0, before: transparent, after: red)],
      );

      expect(result, isNull);
    });

    test('returns TileDeltaCommand when an operation changes tile', () {
      final tile = blankTile();

      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 1, y: 0, before: transparent, after: red)],
      );

      expect(command, isNotNull);
      expect(command!.length, 1);
      final delta = command.deltas.single;
      expect(delta.isReplacement, isTrue);
      expect(delta.coord, tile.coord);
      expect(delta.before, tile);
      expect(delta.after, isNot(tile));
      expect(command.dirtyTiles.contains(tile.coord), isTrue);
      expect(command.dirtyTiles.length, 1);
      expect(command.deltaFor(tile.coord), delta);
      expect(readRgbaColorFromBitmapTile(tile: delta.after!, x: 1, y: 0), red);
    });

    test('applyAfter produces updated tile on a matching surface', () {
      final tile = blankTile();
      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 1, y: 0, before: transparent, after: red)],
      )!;

      final result = command.applyAfter(surfaceWith(tile));

      expect(result.tileAt(tile.coord), command.deltas.single.after);
    });

    test('applyBefore restores original tile on a matching surface', () {
      final tile = blankTile();
      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 1, y: 0, before: transparent, after: red)],
      )!;

      final result = command.applyBefore(
        surfaceWith(command.deltas.single.after!),
      );

      expect(result.tileAt(tile.coord), tile);
    });

    test('propagates StateError from before mismatch', () {
      final tile = blankTile();

      expect(
        () => tileDeltaCommandForBitmapTileOperations(
          tile: tile,
          operations: [op(x: 0, y: 0, before: red, after: blue)],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('does not mutate original tile', () {
      final tile = blankTile();
      final originalPixels = tile.pixels;

      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 1, y: 0, before: transparent, after: red)],
      )!;

      expect(tile.pixels, originalPixels);
      expect(readRgbaColorFromBitmapTile(tile: tile, x: 1, y: 0), transparent);
      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 1,
          y: 0,
        ),
        red,
      );
    });

    test('preserves updated tile coord', () {
      final tile = blankTile(tileX: 3, tileY: 4, size: 2);

      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 6, y: 8, before: transparent, after: red)],
      )!;

      expect(command.deltas.single.after!.coord, tile.coord);
    });

    test('preserves updated tile size', () {
      final tile = blankTile(tileX: 3, tileY: 4, size: 2);

      final command = tileDeltaCommandForBitmapTileOperations(
        tile: tile,
        operations: [op(x: 6, y: 8, before: transparent, after: red)],
      )!;

      expect(command.deltas.single.after!.size, tile.size);
    });
  });
}
