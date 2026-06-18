import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_coordinate_policy.dart';

void main() {
  group('frameIndexFromLocalX', () {
    test('local x converts to frame index without scroll', () {
      expect(
        frameIndexFromLocalX(
          localX: 0,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        0,
      );
      expect(
        frameIndexFromLocalX(
          localX: 47.9,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        0,
      );
      expect(
        frameIndexFromLocalX(
          localX: 48,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        1,
      );
    });

    test('local x converts to frame index with horizontal scroll', () {
      expect(
        frameIndexFromLocalX(
          localX: 0,
          horizontalScrollOffset: 96,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        2,
      );
    });

    test('frame index clamps below zero', () {
      expect(
        frameIndexFromLocalX(
          localX: -100,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        0,
      );
    });

    test('frame index clamps above visible count', () {
      expect(
        frameIndexFromLocalX(
          localX: 10000,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 10,
        ),
        9,
      );
    });

    test('empty visible frame count returns null', () {
      expect(
        frameIndexFromLocalX(
          localX: 0,
          horizontalScrollOffset: 0,
          frameCellWidth: 48,
          visibleFrameCount: 0,
        ),
        isNull,
      );
    });

    test('invalid cell width returns null', () {
      expect(
        frameIndexFromLocalX(
          localX: 0,
          horizontalScrollOffset: 0,
          frameCellWidth: 0,
          visibleFrameCount: 10,
        ),
        isNull,
      );
    });
  });
}
