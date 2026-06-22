import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';
import 'package:quick_animaker_v2/src/services/brush_commit_cache_invalidation.dart';

void main() {
  group('cacheInvalidationPlanForTileDeltaCommand', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapTile tile(int x, int y) {
      return BitmapTile.blank(
        coord: TileCoord(x: x, y: y),
        size: 2,
      );
    }

    test('returns empty plan when command is null', () {
      final plan = cacheInvalidationPlanForTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: null,
      );

      expect(plan, CacheInvalidationPlan.empty());
      expect(plan.isEmpty, isTrue);
      expect(plan.layerTiles, isEmpty);
      expect(plan.frameComposites, isEmpty);
      expect(plan.playbackPreviews, isEmpty);
    });

    test('uses CacheInvalidationPlan.fromTileDeltaCommand for command', () {
      final command = TileDeltaCommand(
        deltas: [TileDelta.created(tile(1, 0)), TileDelta.created(tile(0, 1))],
      );

      final plan = cacheInvalidationPlanForTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );

      expect(
        plan,
        CacheInvalidationPlan.fromTileDeltaCommand(
          layerId: layerId,
          frameId: frameId,
          command: command,
        ),
      );
    });

    test('non-null command creates layer tile invalidations only', () {
      final command = TileDeltaCommand(
        deltas: [TileDelta.created(tile(1, 0)), TileDelta.created(tile(0, 1))],
      );

      final plan = cacheInvalidationPlanForTileDeltaCommand(
        layerId: layerId,
        frameId: frameId,
        command: command,
      );

      expect(plan.layerTiles.length, 2);
      expect(plan.frameComposites, isEmpty);
      expect(plan.playbackPreviews, isEmpty);
      expect(plan.layerTiles.map((key) => key.tileCoord).toSet(), {
        TileCoord(x: 1, y: 0),
        TileCoord(x: 0, y: 1),
      });
      expect(plan.layerTiles.every((key) => key.layerId == layerId), isTrue);
      expect(plan.layerTiles.every((key) => key.frameId == frameId), isTrue);
    });
  });
}
