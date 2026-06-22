import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('BrushCommitResult', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapTile tile(int x, int y) {
      return BitmapTile.blank(
        coord: TileCoord(x: x, y: y),
        size: 2,
      );
    }

    TileDeltaCommand commandForCoords(List<TileCoord> coords) {
      return TileDeltaCommand(
        deltas: coords.map(
          (coord) => TileDelta.created(tile(coord.x, coord.y)),
        ),
      );
    }

    CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
      return CacheInvalidationPlan.fromTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );
    }

    test('noOp creates null command and empty cache invalidation plan', () {
      final result = BrushCommitResult.noOp();

      expect(result.command, isNull);
      expect(result.cacheInvalidationPlan.isEmpty, isTrue);
    });

    test('noOp hasChanges is false', () {
      expect(BrushCommitResult.noOp().hasChanges, isFalse);
    });

    test('noOp isNoOp is true', () {
      expect(BrushCommitResult.noOp().isNoOp, isTrue);
    });

    test('noOp changedTileCount is 0', () {
      expect(BrushCommitResult.noOp().changedTileCount, 0);
    });

    test('noOp dirtyTiles is empty', () {
      expect(BrushCommitResult.noOp().dirtyTiles.isEmpty, isTrue);
    });

    test('changed stores command and cache invalidation plan', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      final plan = planForCommand(command);

      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: plan,
      );

      expect(result.command, command);
      expect(result.cacheInvalidationPlan, plan);
    });

    test('changed hasChanges is true', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      expect(
        BrushCommitResult.changed(
          command: command,
          cacheInvalidationPlan: planForCommand(command),
        ).hasChanges,
        isTrue,
      );
    });

    test('changed isNoOp is false', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      expect(
        BrushCommitResult.changed(
          command: command,
          cacheInvalidationPlan: planForCommand(command),
        ).isNoOp,
        isFalse,
      );
    });

    test('changedTileCount equals command.length', () {
      final command = commandForCoords([
        TileCoord(x: 0, y: 0),
        TileCoord(x: 1, y: 0),
      ]);
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );

      expect(result.changedTileCount, command.length);
    });

    test('dirtyTiles equals command.dirtyTiles', () {
      final command = commandForCoords([
        TileCoord(x: 0, y: 0),
        TileCoord(x: 1, y: 0),
      ]);
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );

      expect(result.dirtyTiles, command.dirtyTiles);
    });

    test(
      'constructor rejects null command with non-empty cache invalidation plan',
      () {
        final command = commandForCoords([TileCoord(x: 0, y: 0)]);

        expect(
          () => BrushCommitResult(
            command: null,
            cacheInvalidationPlan: planForCommand(command),
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'constructor rejects non-null command with empty cache invalidation plan',
      () {
        final command = commandForCoords([TileCoord(x: 0, y: 0)]);

        expect(
          () => BrushCommitResult(
            command: command,
            cacheInvalidationPlan: CacheInvalidationPlan.empty(),
          ),
          throwsArgumentError,
        );
      },
    );

    test('copyWith preserves existing values when omitted', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );

      expect(result.copyWith(), result);
    });

    test(
      'copyWith can produce noOp when command is explicitly null and plan is empty',
      () {
        final command = commandForCoords([TileCoord(x: 0, y: 0)]);
        final result =
            BrushCommitResult.changed(
              command: command,
              cacheInvalidationPlan: planForCommand(command),
            ).copyWith(
              command: null,
              cacheInvalidationPlan: CacheInvalidationPlan.empty(),
            );

        expect(result, BrushCommitResult.noOp());
      },
    );

    test(
      'copyWith can produce changed result when command and plan are provided',
      () {
        final command = commandForCoords([TileCoord(x: 1, y: 0)]);
        final plan = planForCommand(command);
        final result = BrushCommitResult.noOp().copyWith(
          command: command,
          cacheInvalidationPlan: plan,
        );

        expect(
          result,
          BrushCommitResult.changed(
            command: command,
            cacheInvalidationPlan: plan,
          ),
        );
      },
    );

    test('toJson/fromJson round trips noOp', () {
      final result = BrushCommitResult.noOp();

      expect(BrushCommitResult.fromJson(result.toJson()), result);
      expect(result.toJson()['command'], isNull);
    });

    test('toJson/fromJson round trips changed result', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );

      expect(BrushCommitResult.fromJson(result.toJson()), result);
    });

    test('equality compares command and cacheInvalidationPlan', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      final a = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );
      final b = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );
      final otherCommand = commandForCoords([TileCoord(x: 1, y: 0)]);
      final c = BrushCommitResult.changed(
        command: otherCommand,
        cacheInvalidationPlan: planForCommand(otherCommand),
      );

      expect(a, b);
      expect(a, isNot(c));
    });

    test('hashCode matches equality', () {
      final command = commandForCoords([TileCoord(x: 0, y: 0)]);
      final a = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );
      final b = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );

      expect(a.hashCode, b.hashCode);
    });

    test('toString contains useful class name', () {
      expect(
        BrushCommitResult.noOp().toString(),
        contains('BrushCommitResult'),
      );
    });
  });
}
