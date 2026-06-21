import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';

void main() {
  group('TileDelta', () {
    final coord = TileCoord(x: 1, y: 2);

    BitmapTile tile({TileCoord? coord, int size = 2, int firstByte = 0}) {
      return BitmapTile(
        coord: coord ?? TileCoord(x: 1, y: 2),
        size: size,
        pixels: Uint8List(size * size * BitmapTile.bytesPerPixel)
          ..[0] = firstByte,
      );
    }

    test('created factory creates creation delta', () {
      final after = tile();
      final delta = TileDelta.created(after);
      expect(delta.coord, after.coord);
      expect(delta.before, isNull);
      expect(delta.after, after);
      expect(delta.isCreation, isTrue);
    });

    test('removed factory creates removal delta', () {
      final before = tile();
      final delta = TileDelta.removed(before);
      expect(delta.coord, before.coord);
      expect(delta.before, before);
      expect(delta.after, isNull);
      expect(delta.isRemoval, isTrue);
    });

    test('replaced factory creates replacement delta', () {
      final before = tile();
      final after = tile(firstByte: 1);
      final delta = TileDelta.replaced(before: before, after: after);
      expect(delta.coord, before.coord);
      expect(delta.before, before);
      expect(delta.after, after);
      expect(delta.isReplacement, isTrue);
    });

    test('constructor rejects before and after both null', () {
      expect(
        () => TileDelta(coord: coord, before: null, after: null),
        throwsArgumentError,
      );
    });

    test('constructor rejects before coord mismatch', () {
      expect(
        () => TileDelta(
          coord: coord,
          before: tile(coord: TileCoord(x: 0, y: 0)),
          after: null,
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects after coord mismatch', () {
      expect(
        () => TileDelta(
          coord: coord,
          before: null,
          after: tile(coord: TileCoord(x: 0, y: 0)),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects before/after size mismatch', () {
      expect(
        () => TileDelta.replaced(
          before: tile(),
          after: tile(size: 3, firstByte: 1),
        ),
        throwsArgumentError,
      );
    });

    test('constructor rejects no-op before == after', () {
      final before = tile();
      expect(
        () => TileDelta.replaced(before: before, after: before),
        throwsArgumentError,
      );
    });

    test('isCreation is true only for creation', () {
      expect(TileDelta.created(tile()).isCreation, isTrue);
      expect(TileDelta.removed(tile()).isCreation, isFalse);
      expect(
        TileDelta.replaced(
          before: tile(),
          after: tile(firstByte: 1),
        ).isCreation,
        isFalse,
      );
    });

    test('isRemoval is true only for removal', () {
      expect(TileDelta.removed(tile()).isRemoval, isTrue);
      expect(TileDelta.created(tile()).isRemoval, isFalse);
      expect(
        TileDelta.replaced(before: tile(), after: tile(firstByte: 1)).isRemoval,
        isFalse,
      );
    });

    test('isReplacement is true only for replacement', () {
      expect(
        TileDelta.replaced(
          before: tile(),
          after: tile(firstByte: 1),
        ).isReplacement,
        isTrue,
      );
      expect(TileDelta.created(tile()).isReplacement, isFalse);
      expect(TileDelta.removed(tile()).isReplacement, isFalse);
    });

    test(
      'tileSize uses after size for creation',
      () => expect(TileDelta.created(tile(size: 3)).tileSize, 3),
    );
    test(
      'tileSize uses before size for removal',
      () => expect(TileDelta.removed(tile(size: 3)).tileSize, 3),
    );
    test(
      'tileSize uses before/after size for replacement',
      () => expect(
        TileDelta.replaced(
          before: tile(size: 3),
          after: tile(size: 3, firstByte: 1),
        ).tileSize,
        3,
      ),
    );

    test('copyWith updates coord/before/after and revalidates', () {
      final original = TileDelta.created(tile());
      final nextCoord = TileCoord(x: 2, y: 2);
      final nextTile = tile(coord: nextCoord, firstByte: 1);
      final copied = original.copyWith(
        coord: nextCoord,
        before: null,
        after: nextTile,
      );
      expect(copied.coord, nextCoord);
      expect(copied.before, isNull);
      expect(copied.after, nextTile);
      expect(() => original.copyWith(coord: nextCoord), throwsArgumentError);
    });

    test('equality includes coord, before, and after', () {
      expect(TileDelta.created(tile()), TileDelta.created(tile()));
      expect(
        TileDelta.created(tile()),
        isNot(TileDelta.created(tile(firstByte: 1))),
      );
    });

    test('hashCode is value-based', () {
      expect(
        TileDelta.created(tile()).hashCode,
        TileDelta.created(tile()).hashCode,
      );
    });

    test('toJson/fromJson round-trips creation', () {
      final delta = TileDelta.created(tile());
      expect(TileDelta.fromJson(delta.toJson()), delta);
    });

    test('toJson/fromJson round-trips removal', () {
      final delta = TileDelta.removed(tile());
      expect(TileDelta.fromJson(delta.toJson()), delta);
    });

    test('toJson/fromJson round-trips replacement', () {
      final delta = TileDelta.replaced(
        before: tile(),
        after: tile(firstByte: 1),
      );
      expect(TileDelta.fromJson(delta.toJson()), delta);
    });
  });
}
