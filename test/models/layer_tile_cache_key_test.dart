import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_tile_cache_key.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';

void main() {
  group('LayerTileCacheKey', () {
    final key = LayerTileCacheKey(
      layerId: const LayerId('layer-a'),
      frameId: const FrameId('frame-a'),
      tileCoord: TileCoord(x: 1, y: 2),
    );

    test('creates with layerId, frameId, tileCoord', () {
      expect(key.layerId, const LayerId('layer-a'));
      expect(key.frameId, const FrameId('frame-a'));
      expect(key.tileCoord, TileCoord(x: 1, y: 2));
    });

    test('copyWith updates layerId', () {
      expect(key.copyWith(layerId: const LayerId('layer-b')).layerId.value, 'layer-b');
    });

    test('copyWith updates frameId', () {
      expect(key.copyWith(frameId: const FrameId('frame-b')).frameId.value, 'frame-b');
    });

    test('copyWith updates tileCoord', () {
      expect(key.copyWith(tileCoord: TileCoord(x: 3, y: 4)).tileCoord, TileCoord(x: 3, y: 4));
    });

    test('equality includes all fields', () {
      expect(key, LayerTileCacheKey(layerId: const LayerId('layer-a'), frameId: const FrameId('frame-a'), tileCoord: TileCoord(x: 1, y: 2)));
      expect(key, isNot(key.copyWith(layerId: const LayerId('other'))));
      expect(key, isNot(key.copyWith(frameId: const FrameId('other'))));
      expect(key, isNot(key.copyWith(tileCoord: TileCoord(x: 9, y: 2))));
    });

    test('hashCode is value-based', () {
      expect(key.hashCode, LayerTileCacheKey(layerId: const LayerId('layer-a'), frameId: const FrameId('frame-a'), tileCoord: TileCoord(x: 1, y: 2)).hashCode);
    });

    test('toJson/fromJson round-trips', () {
      expect(LayerTileCacheKey.fromJson(key.toJson()), key);
    });

    test('toString includes useful identifying data', () {
      expect(key.toString(), contains('layer-a'));
      expect(key.toString(), contains('frame-a'));
      expect(key.toString(), contains('TileCoord'));
    });
  });
}
