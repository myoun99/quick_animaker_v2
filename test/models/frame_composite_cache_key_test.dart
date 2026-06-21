import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_composite_cache_key.dart';

void main() {
  group('FrameCompositeCacheKey', () {
    final key = FrameCompositeCacheKey(
      cutId: const CutId('cut-a'),
      frameIndex: 3,
    );

    test('creates with cutId and frameIndex', () {
      expect(key.cutId, const CutId('cut-a'));
      expect(key.frameIndex, 3);
    });

    test('rejects negative frameIndex', () {
      expect(
        () =>
            FrameCompositeCacheKey(cutId: const CutId('cut-a'), frameIndex: -1),
        throwsArgumentError,
      );
    });

    test('copyWith updates cutId', () {
      expect(key.copyWith(cutId: const CutId('cut-b')).cutId.value, 'cut-b');
    });

    test('copyWith updates frameIndex', () {
      expect(key.copyWith(frameIndex: 4).frameIndex, 4);
    });

    test('equality includes all fields', () {
      expect(
        key,
        FrameCompositeCacheKey(cutId: const CutId('cut-a'), frameIndex: 3),
      );
      expect(key, isNot(key.copyWith(cutId: const CutId('other'))));
      expect(key, isNot(key.copyWith(frameIndex: 4)));
    });

    test('hashCode is value-based', () {
      expect(
        key.hashCode,
        FrameCompositeCacheKey(
          cutId: const CutId('cut-a'),
          frameIndex: 3,
        ).hashCode,
      );
    });

    test('toJson/fromJson round-trips', () {
      expect(FrameCompositeCacheKey.fromJson(key.toJson()), key);
    });

    test('toString includes useful identifying data', () {
      expect(key.toString(), contains('cut-a'));
      expect(key.toString(), contains('3'));
    });
  });
}
