import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('BrushEditHistoryEntry', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapTile tile(int x, int y) {
      return BitmapTile.blank(
        coord: TileCoord(x: x, y: y),
        size: 2,
      );
    }

    BrushCommitResult resultForCoords(List<TileCoord> coords) {
      final command = TileDeltaCommand(
        deltas: coords.map(
          (coord) => TileDelta.created(tile(coord.x, coord.y)),
        ),
      );
      return BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: CacheInvalidationPlan.fromTileDeltaCommand(
          layerId: layerId,
          frameId: frameId,
          command: command,
        ),
      );
    }

    BrushEditHistoryEntry entryFor(BrushCommitResult result) {
      return BrushEditHistoryEntry(
        layerId: layerId,
        frameId: frameId,
        commitResult: result,
      );
    }

    test('stores layerId, frameId, and commitResult', () {
      final result = resultForCoords([TileCoord(x: 0, y: 0)]);
      final entry = entryFor(result);

      expect(entry.layerId, layerId);
      expect(entry.frameId, frameId);
      expect(entry.commitResult, result);
    });

    test('rejects no-op commitResult', () {
      expect(
        () => BrushEditHistoryEntry(
          layerId: layerId,
          frameId: frameId,
          commitResult: BrushCommitResult.noOp(),
        ),
        throwsArgumentError,
      );
    });

    test('command getter returns commitResult.command', () {
      final result = resultForCoords([TileCoord(x: 0, y: 0)]);
      expect(entryFor(result).command, result.command);
    });

    test(
      'cacheInvalidationPlan getter returns commitResult.cacheInvalidationPlan',
      () {
        final result = resultForCoords([TileCoord(x: 0, y: 0)]);
        expect(
          entryFor(result).cacheInvalidationPlan,
          result.cacheInvalidationPlan,
        );
      },
    );

    test('dirtyTiles getter returns command.dirtyTiles', () {
      final entry = entryFor(resultForCoords([TileCoord(x: 0, y: 0)]));
      expect(entry.dirtyTiles, entry.command.dirtyTiles);
    });

    test('changedTileCount getter returns command.length', () {
      final entry = entryFor(
        resultForCoords([TileCoord(x: 0, y: 0), TileCoord(x: 1, y: 0)]),
      );
      expect(entry.changedTileCount, entry.command.length);
    });

    test('copyWith preserves omitted values', () {
      final entry = entryFor(resultForCoords([TileCoord(x: 0, y: 0)]));
      expect(entry.copyWith(), entry);
    });

    test('copyWith updates layerId', () {
      final entry = entryFor(resultForCoords([TileCoord(x: 0, y: 0)]));
      expect(
        entry.copyWith(layerId: LayerId('layer-b')).layerId,
        LayerId('layer-b'),
      );
    });

    test('copyWith updates frameId', () {
      final entry = entryFor(resultForCoords([TileCoord(x: 0, y: 0)]));
      expect(
        entry.copyWith(frameId: FrameId('frame-b')).frameId,
        FrameId('frame-b'),
      );
    });

    test('copyWith updates commitResult', () {
      final entry = entryFor(resultForCoords([TileCoord(x: 0, y: 0)]));
      final other = resultForCoords([TileCoord(x: 1, y: 0)]);
      expect(entry.copyWith(commitResult: other).commitResult, other);
    });

    test('equality compares layerId, frameId, and commitResult', () {
      final result = resultForCoords([TileCoord(x: 0, y: 0)]);
      expect(entryFor(result), entryFor(result));
      expect(
        entryFor(result),
        isNot(entryFor(resultForCoords([TileCoord(x: 1, y: 0)]))),
      );
    });

    test('hashCode matches equality', () {
      final result = resultForCoords([TileCoord(x: 0, y: 0)]);
      expect(entryFor(result).hashCode, entryFor(result).hashCode);
    });

    test('toString contains useful class name', () {
      expect(
        entryFor(resultForCoords([TileCoord(x: 0, y: 0)])).toString(),
        contains('BrushEditHistoryEntry'),
      );
    });

    test('does not contain beforeSurface or afterSurface fields', () {
      final text = entryFor(
        resultForCoords([TileCoord(x: 0, y: 0)]),
      ).toString();
      expect(text, isNot(contains('beforeSurface')));
      expect(text, isNot(contains('afterSurface')));
    });
  });
}
