import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('TileDeltaCommand', () {
    BitmapTile tile(int x, int y, {int size = 2, int firstByte = 0}) {
      return BitmapTile(
        coord: TileCoord(x: x, y: y),
        size: size,
        pixels: Uint8List(size * size * BitmapTile.bytesPerPixel)
          ..[0] = firstByte,
      );
    }

    BitmapSurface surface({Map<TileCoord, BitmapTile> tiles = const {}}) {
      return BitmapSurface(
        canvasSize: const CanvasSize(width: 6, height: 6),
        tileSize: 2,
        tiles: tiles,
      );
    }

    test('constructor stores deltas', () {
      final delta = TileDelta.created(tile(0, 0));
      expect(TileDeltaCommand(deltas: [delta]).deltas, [delta]);
    });

    test('constructor rejects empty deltas', () {
      expect(() => TileDeltaCommand(deltas: const []), throwsArgumentError);
    });

    test('constructor rejects duplicate coords', () {
      expect(
        () => TileDeltaCommand(
          deltas: [
            TileDelta.created(tile(0, 0)),
            TileDelta.removed(tile(0, 0)),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('deltas getter is unmodifiable', () {
      final command = TileDeltaCommand(deltas: [TileDelta.created(tile(0, 0))]);
      expect(
        () => command.deltas.add(TileDelta.created(tile(1, 0))),
        throwsUnsupportedError,
      );
    });

    test('deltas getter returns deterministic row-major order', () {
      final a = TileDelta.created(tile(2, 1));
      final b = TileDelta.created(tile(1, 0));
      final c = TileDelta.created(tile(0, 1));
      expect(TileDeltaCommand(deltas: [a, b, c]).deltas, [b, c, a]);
    });

    test('dirtyTiles returns DirtyTileSet of delta coords', () {
      final command = TileDeltaCommand(
        deltas: [TileDelta.created(tile(0, 0)), TileDelta.created(tile(1, 0))],
      );
      expect(command.dirtyTiles.contains(TileCoord(x: 0, y: 0)), isTrue);
      expect(command.dirtyTiles.contains(TileCoord(x: 1, y: 0)), isTrue);
      expect(command.dirtyTiles.length, 2);
    });

    test('length returns delta count', () {
      expect(
        TileDeltaCommand(deltas: [TileDelta.created(tile(0, 0))]).length,
        1,
      );
    });

    test('containsCoord returns true for existing coord', () {
      expect(
        TileDeltaCommand(
          deltas: [TileDelta.created(tile(0, 0))],
        ).containsCoord(TileCoord(x: 0, y: 0)),
        isTrue,
      );
    });

    test('containsCoord returns false for missing coord', () {
      expect(
        TileDeltaCommand(
          deltas: [TileDelta.created(tile(0, 0))],
        ).containsCoord(TileCoord(x: 1, y: 0)),
        isFalse,
      );
    });

    test('deltaFor returns delta for coord', () {
      final delta = TileDelta.created(tile(0, 0));
      expect(
        TileDeltaCommand(deltas: [delta]).deltaFor(TileCoord(x: 0, y: 0)),
        delta,
      );
    });

    test('deltaFor returns null for missing coord', () {
      expect(
        TileDeltaCommand(
          deltas: [TileDelta.created(tile(0, 0))],
        ).deltaFor(TileCoord(x: 1, y: 0)),
        isNull,
      );
    });

    test('equality ignores insertion order', () {
      final a = TileDelta.created(tile(0, 0));
      final b = TileDelta.created(tile(1, 0));
      expect(
        TileDeltaCommand(deltas: [a, b]),
        TileDeltaCommand(deltas: [b, a]),
      );
    });

    test('hashCode ignores insertion order', () {
      final a = TileDelta.created(tile(0, 0));
      final b = TileDelta.created(tile(1, 0));
      expect(
        TileDeltaCommand(deltas: [a, b]).hashCode,
        TileDeltaCommand(deltas: [b, a]).hashCode,
      );
    });

    test('toJson/fromJson round-trips', () {
      final command = TileDeltaCommand(deltas: [TileDelta.created(tile(0, 0))]);
      expect(TileDeltaCommand.fromJson(command.toJson()), command);
    });

    test('toJson emits deterministic delta order', () {
      final command = TileDeltaCommand(
        deltas: [
          TileDelta.created(tile(2, 1)),
          TileDelta.created(tile(1, 0)),
          TileDelta.created(tile(0, 1)),
        ],
      );
      final coords = (command.toJson()['deltas'] as List)
          .map((json) => (json as Map<String, dynamic>)['coord'])
          .toList();
      expect(coords, [
        {'x': 1, 'y': 0},
        {'x': 0, 'y': 1},
        {'x': 2, 'y': 1},
      ]);
    });

    test(
      'validateAgainstSurface accepts in-bounds matching tileSize deltas',
      () {
        expect(
          () => TileDeltaCommand(
            deltas: [TileDelta.created(tile(2, 2))],
          ).validateAgainstSurface(surface()),
          returnsNormally,
        );
      },
    );

    test('validateAgainstSurface rejects coord outside surface', () {
      expect(
        () => TileDeltaCommand(
          deltas: [TileDelta.created(tile(3, 0))],
        ).validateAgainstSurface(surface()),
        throwsArgumentError,
      );
    });

    test('validateAgainstSurface rejects tile size mismatch', () {
      expect(
        () => TileDeltaCommand(
          deltas: [TileDelta.created(tile(0, 0, size: 3))],
        ).validateAgainstSurface(surface()),
        throwsArgumentError,
      );
    });

    test('applyAfter creates missing tile', () {
      final after = tile(0, 0, firstByte: 1);
      expect(
        TileDeltaCommand(
          deltas: [TileDelta.created(after)],
        ).applyAfter(surface()).tileAt(after.coord),
        after,
      );
    });

    test('applyBefore removes created tile', () {
      final after = tile(0, 0, firstByte: 1);
      final result = TileDeltaCommand(
        deltas: [TileDelta.created(after)],
      ).applyBefore(surface().putTile(after));
      expect(result.tileAt(after.coord), isNull);
    });

    test('applyAfter removes deleted tile', () {
      final before = tile(0, 0, firstByte: 1);
      final result = TileDeltaCommand(
        deltas: [TileDelta.removed(before)],
      ).applyAfter(surface().putTile(before));
      expect(result.tileAt(before.coord), isNull);
    });

    test('applyBefore restores deleted tile', () {
      final before = tile(0, 0, firstByte: 1);
      final result = TileDeltaCommand(
        deltas: [TileDelta.removed(before)],
      ).applyBefore(surface());
      expect(result.tileAt(before.coord), before);
    });

    test('applyAfter replaces modified tile', () {
      final before = tile(0, 0);
      final after = tile(0, 0, firstByte: 1);
      final result = TileDeltaCommand(
        deltas: [TileDelta.replaced(before: before, after: after)],
      ).applyAfter(surface().putTile(before));
      expect(result.tileAt(after.coord), after);
    });

    test('applyBefore restores original modified tile', () {
      final before = tile(0, 0);
      final after = tile(0, 0, firstByte: 1);
      final result = TileDeltaCommand(
        deltas: [TileDelta.replaced(before: before, after: after)],
      ).applyBefore(surface().putTile(after));
      expect(result.tileAt(before.coord), before);
    });

    test('applyBefore/applyAfter do not mutate original surface', () {
      final after = tile(0, 0, firstByte: 1);
      final original = surface();
      final command = TileDeltaCommand(deltas: [TileDelta.created(after)]);
      final applied = command.applyAfter(original);
      expect(original.tileAt(after.coord), isNull);
      expect(applied.tileAt(after.coord), after);
      expect(identical(original, applied), isFalse);
    });
  });
}
