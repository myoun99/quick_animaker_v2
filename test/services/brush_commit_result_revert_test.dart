import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_tile_cache_key.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';
import 'package:quick_animaker_v2/src/services/brush_commit_result_apply.dart';
import 'package:quick_animaker_v2/src/services/brush_commit_result_revert.dart';

void main() {
  group('revertBrushCommitResultOnBitmapSurface', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface({
      int width = 4,
      int height = 4,
      int tileSize = 2,
      Map<TileCoord, BitmapTile> tiles = const {},
    }) {
      return BitmapSurface(
        canvasSize: CanvasSize(width: width, height: height),
        tileSize: tileSize,
        tiles: tiles,
      );
    }

    BitmapTile tile({
      required int tileX,
      required int tileY,
      int size = 2,
      int firstByte = 0,
    }) {
      return BitmapTile(
        coord: TileCoord(x: tileX, y: tileY),
        size: size,
        pixels: Uint8List(size * size * BitmapTile.bytesPerPixel)
          ..[0] = firstByte,
      );
    }

    TileDeltaCommand commandForCreatedTiles(List<BitmapTile> tiles) {
      return TileDeltaCommand(deltas: tiles.map(TileDelta.created));
    }

    CacheInvalidationPlan planForCommand(TileDeltaCommand command) {
      return CacheInvalidationPlan.fromTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );
    }

    BrushCommitResult resultForCommand(TileDeltaCommand command) {
      return BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planForCommand(command),
      );
    }

    test('returns original surface for noOp result', () {
      final original = surface();

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: original,
        result: BrushCommitResult.noOp(),
      );

      expect(result, original);
    });

    test('returns same surface instance for noOp result', () {
      final original = surface();

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: original,
        result: BrushCommitResult.noOp(),
      );

      expect(identical(result, original), isTrue);
    });

    test('reverts creation delta by removing created tile', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final current = surface(tiles: {created.coord: created});

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: resultForCommand(commandForCreatedTiles([created])),
      );

      expect(result.tileAt(created.coord), isNull);
      expect(current.tileAt(created.coord), created);
    });

    test('reverts replacement delta to previous tile', () {
      final before = tile(tileX: 0, tileY: 0, firstByte: 1);
      final after = tile(tileX: 0, tileY: 0, firstByte: 2);
      final current = surface(tiles: {after.coord: after});
      final command = TileDeltaCommand(
        deltas: [TileDelta.replaced(before: before, after: after)],
      );

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: resultForCommand(command),
      );

      expect(result.tileAt(before.coord), before);
      expect(current.tileAt(after.coord), after);
    });

    test('reverts multi-tile command', () {
      final first = tile(tileX: 0, tileY: 0, firstByte: 1);
      final second = tile(tileX: 1, tileY: 0, firstByte: 2);
      final command = commandForCreatedTiles([first, second]);

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: surface(tiles: {first.coord: first, second.coord: second}),
        result: resultForCommand(command),
      );

      expect(result.tileAt(first.coord), isNull);
      expect(result.tileAt(second.coord), isNull);
    });

    test('result equals command.applyBefore(surface)', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final current = surface(tiles: {created.coord: created});
      final command = commandForCreatedTiles([created]);

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: resultForCommand(command),
      );

      expect(result, command.applyBefore(current));
    });

    test('forward apply then revert restores original surface', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final original = surface();
      final command = commandForCreatedTiles([created]);
      final result = resultForCommand(command);
      final current = applyBrushCommitResultToBitmapSurface(
        surface: original,
        result: result,
      );

      final reverted = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: result,
      );

      expect(reverted, original);
    });

    test('does not mutate current BitmapSurface', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final current = surface(tiles: {created.coord: created});
      final before = BitmapSurface.fromJson(current.toJson());

      revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: resultForCommand(commandForCreatedTiles([created])),
      );

      expect(current, before);
      expect(current.tileAt(created.coord), created);
    });

    test('does not mutate existing BitmapTile', () {
      final beforeTile = tile(tileX: 0, tileY: 0, firstByte: 1);
      final afterTile = tile(tileX: 0, tileY: 0, firstByte: 2);
      final originalTile = BitmapTile.fromJson(afterTile.toJson());
      final command = TileDeltaCommand(
        deltas: [TileDelta.replaced(before: beforeTile, after: afterTile)],
      );

      revertBrushCommitResultOnBitmapSurface(
        surface: surface(tiles: {afterTile.coord: afterTile}),
        result: resultForCommand(command),
      );

      expect(afterTile, originalTile);
    });

    test('does not mutate BrushCommitResult', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final result = resultForCommand(commandForCreatedTiles([created]));
      final before = BrushCommitResult.fromJson(result.toJson());

      revertBrushCommitResultOnBitmapSurface(
        surface: surface(tiles: {created.coord: created}),
        result: result,
      );

      expect(result, before);
    });

    test('does not mutate TileDeltaCommand', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final command = commandForCreatedTiles([created]);
      final before = TileDeltaCommand.fromJson(command.toJson());

      revertBrushCommitResultOnBitmapSurface(
        surface: surface(tiles: {created.coord: created}),
        result: resultForCommand(command),
      );

      expect(command, before);
    });

    test('does not inspect or depend on CacheInvalidationPlan contents', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final command = commandForCreatedTiles([created]);
      final planWithUnrelatedKey = CacheInvalidationPlan(
        layerTiles: [
          LayerTileCacheKey(
            layerId: const LayerId('unrelated-layer'),
            frameId: const FrameId('unrelated-frame'),
            tileCoord: TileCoord(x: 1, y: 1),
          ),
        ],
      );
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: planWithUnrelatedKey,
      );
      final current = surface(tiles: {created.coord: created});

      final updated = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: result,
      );

      expect(updated, command.applyBefore(current));
      expect(updated.tileAt(created.coord), isNull);
    });

    test('propagates applyBefore errors', () {
      final outOfBoundsTile = tile(tileX: 2, tileY: 0, firstByte: 1);
      final command = commandForCreatedTiles([outOfBoundsTile]);

      expect(
        () => revertBrushCommitResultOnBitmapSurface(
          surface: surface(width: 2, height: 2, tileSize: 2),
          result: resultForCommand(command),
        ),
        throwsArgumentError,
      );
    });

    test('does not execute cache invalidation', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final command = commandForCreatedTiles([created]);
      final plan = planForCommand(command);
      final result = BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: plan,
      );

      revertBrushCommitResultOnBitmapSurface(
        surface: surface(tiles: {created.coord: created}),
        result: result,
      );

      expect(result.cacheInvalidationPlan, plan);
    });

    test('does not add undo stack behavior', () {
      final created = tile(tileX: 0, tileY: 0, firstByte: 1);
      final current = surface(tiles: {created.coord: created});

      final result = revertBrushCommitResultOnBitmapSurface(
        surface: current,
        result: resultForCommand(commandForCreatedTiles([created])),
      );

      expect(result.tileAt(created.coord), isNull);
    });
  });
}
