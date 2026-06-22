import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_commit_builder.dart';
import 'package:quick_animaker_v2/src/services/brush_commit_cache_invalidation.dart';

void main() {
  group('brushCommitResultForBrushDabSequenceOnBitmapSurface', () {
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

    BitmapTile blankTile({
      required int tileX,
      required int tileY,
      int size = 2,
    }) {
      return BitmapTile.blank(
        coord: TileCoord(x: tileX, y: tileY),
        size: size,
      );
    }

    BrushDab onePixelDab({
      required double globalX,
      required double globalY,
      int color = 0xFFFF0000,
      double opacity = 1,
      double flow = 1,
      int sequence = 0,
    }) {
      return BrushDab(
        center: CanvasPoint(x: globalX + 0.5, y: globalY + 0.5),
        color: color,
        size: 1,
        opacity: opacity,
        flow: flow,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: sequence,
      );
    }

    BrushDab squareDab({
      required double centerX,
      required double centerY,
      int color = 0xFFFF0000,
      int sequence = 0,
    }) {
      return BrushDab(
        center: CanvasPoint(x: centerX, y: centerY),
        color: color,
        size: 2,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.square,
        pressure: 1,
        sequence: sequence,
      );
    }

    BrushCommitResult resultFor({
      required BitmapSurface surface,
      required BrushDabSequence sequence,
      LayerId? overrideLayerId,
      FrameId? overrideFrameId,
    }) {
      return brushCommitResultForBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: sequence,
        layerId: overrideLayerId ?? layerId,
        frameId: overrideFrameId ?? frameId,
      );
    }

    test('returns BrushCommitResult.noOp for empty BrushDabSequence', () {
      final result = resultFor(surface: surface(), sequence: BrushDabSequence());

      expect(result, BrushCommitResult.noOp());
      expect(result.command, isNull);
      expect(result.cacheInvalidationPlan, CacheInvalidationPlan.empty());
      expect(result.cacheInvalidationPlan.isEmpty, isTrue);
      expect(result.hasChanges, isFalse);
      expect(result.isNoOp, isTrue);
      expect(result.changedTileCount, 0);
      expect(result.dirtyTiles.isEmpty, isTrue);
    });

    test('returns BrushCommitResult.noOp for non-effective dab', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([
          onePixelDab(globalX: 0, globalY: 0, opacity: 0),
        ]),
      );

      expect(result, BrushCommitResult.noOp());
      expect(result.command, isNull);
      expect(result.cacheInvalidationPlan.isEmpty, isTrue);
      expect(result.hasChanges, isFalse);
      expect(result.isNoOp, isTrue);
      expect(result.changedTileCount, 0);
      expect(result.dirtyTiles.isEmpty, isTrue);
    });

    test('returns BrushCommitResult.noOp when dab affects only pixels outside surface', () {
      final result = resultFor(
        surface: surface(width: 2, height: 2, tileSize: 2),
        sequence: BrushDabSequence([onePixelDab(globalX: 3, globalY: 0)]),
      );

      expect(result, BrushCommitResult.noOp());
      expect(result.command, isNull);
      expect(result.cacheInvalidationPlan.isEmpty, isTrue);
      expect(result.hasChanges, isFalse);
      expect(result.isNoOp, isTrue);
      expect(result.changedTileCount, 0);
      expect(result.dirtyTiles.isEmpty, isTrue);
    });

    test('returns changed BrushCommitResult for dab on missing tile', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.hasChanges, isTrue);
      expect(result.isNoOp, isFalse);
      expect(result.command, isNotNull);
      expect(result.command!.deltas.single.isCreation, isTrue);
    });

    test('returns changed BrushCommitResult for dab on existing tile', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final result = resultFor(
        surface: surface(tiles: {existing.coord: existing}),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.hasChanges, isTrue);
      expect(result.isNoOp, isFalse);
      expect(result.command, isNotNull);
      expect(result.command!.deltas.single.isReplacement, isTrue);
    });

    test('changed result contains TileDeltaCommand', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.command, isNotNull);
      expect(result.command!.length, 1);
    });

    test('changed result contains non-empty CacheInvalidationPlan', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.cacheInvalidationPlan.isNotEmpty, isTrue);
      expect(result.cacheInvalidationPlan.layerTiles, isNotEmpty);
    });

    test('changed result dirtyTiles equals command.dirtyTiles', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.dirtyTiles, result.command!.dirtyTiles);
    });

    test('changed result changedTileCount equals command.length', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(result.changedTileCount, result.command!.length);
    });

    test('cache invalidation plan uses provided LayerId', () {
      const customLayerId = LayerId('custom-layer');
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
        overrideLayerId: customLayerId,
      );

      expect(
        result.cacheInvalidationPlan.layerTiles.every(
          (key) => key.layerId == customLayerId,
        ),
        isTrue,
      );
    });

    test('cache invalidation plan uses provided FrameId', () {
      const customFrameId = FrameId('custom-frame');
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
        overrideFrameId: customFrameId,
      );

      expect(
        result.cacheInvalidationPlan.layerTiles.every(
          (key) => key.frameId == customFrameId,
        ),
        isTrue,
      );
    });

    test('cache invalidation plan uses command dirty tile coords', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([squareDab(centerX: 2, centerY: 1)]),
      );

      expect(
        result.cacheInvalidationPlan.layerTiles
            .map((key) => key.tileCoord)
            .toSet(),
        result.command!.dirtyTiles.coords,
      );
    });

    test('multi-tile dab returns result with multiple changed tiles', () {
      final result = resultFor(
        surface: surface(),
        sequence: BrushDabSequence([squareDab(centerX: 2, centerY: 1)]),
      );

      expect(result.changedTileCount, 2);
      expect(result.command!.length, 2);
      expect(result.cacheInvalidationPlan.layerTiles.length, 2);
      expect(result.command!.deltas.map((delta) => delta.coord), [
        TileCoord(x: 0, y: 0),
        TileCoord(x: 1, y: 0),
      ]);
    });

    test('result matches manual composition for changed command', () {
      final testSurface = surface();
      final sequence = BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]);
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: testSurface,
        sequence: sequence,
      );
      final plan = cacheInvalidationPlanForTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );
      final expected = command == null
          ? BrushCommitResult.noOp()
          : BrushCommitResult.changed(
              command: command,
              cacheInvalidationPlan: plan,
            );

      final actual = resultFor(surface: testSurface, sequence: sequence);

      expect(actual, expected);
    });

    test('result matches manual composition for no-op command', () {
      final testSurface = surface();
      final sequence = BrushDabSequence();
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: testSurface,
        sequence: sequence,
      );
      final plan = cacheInvalidationPlanForTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );
      final expected = command == null
          ? BrushCommitResult.noOp()
          : BrushCommitResult.changed(
              command: command,
              cacheInvalidationPlan: plan,
            );

      final actual = resultFor(surface: testSurface, sequence: sequence);

      expect(actual, expected);
    });

    test('does not mutate BitmapSurface', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final testSurface = surface(tiles: {existing.coord: existing});
      final before = BitmapSurface.fromJson(testSurface.toJson());

      resultFor(
        surface: testSurface,
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(testSurface, before);
      expect(testSurface.tileAt(existing.coord), existing);
    });

    test('does not mutate existing BitmapTile', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final before = BitmapTile.fromJson(existing.toJson());

      resultFor(
        surface: surface(tiles: {existing.coord: existing}),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      );

      expect(existing, before);
    });

    test('does not mutate BrushDabSequence', () {
      final dab = onePixelDab(globalX: 0, globalY: 0);
      final sequence = BrushDabSequence([dab]);
      final before = BrushDabSequence.fromJson(sequence.toJson());

      resultFor(surface: surface(), sequence: sequence);

      expect(sequence, before);
      expect(sequence.dabs.single, dab);
    });

    test('does not mutate BrushDab', () {
      final dab = onePixelDab(globalX: 0, globalY: 0);
      final before = BrushDab.fromJson(dab.toJson());

      resultFor(
        surface: surface(),
        sequence: BrushDabSequence([dab]),
      );

      expect(dab, before);
    });
  });
}
