import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';

void main() {
  group('TimelineExposure', () {
    test('drawing exposure requires a positive length', () {
      expect(
        () => TimelineExposure.drawing(const FrameId('frame-a'), length: 0),
        throwsAssertionError,
      );
    });

    test('mark exposure has no frameId or length', () {
      const exposure = TimelineExposure.mark();

      expect(exposure.type, TimelineExposureType.mark);
      expect(exposure.frameId, isNull);
      expect(exposure.length, isNull);
      expect(exposure.isMark, isTrue);
    });

    test('round-trips drawing JSON', () {
      final exposure = TimelineExposure.drawing(
        const FrameId('frame-a'),
        length: 3,
      );

      expect(TimelineExposure.fromJson(exposure.toJson()), exposure);
    });

    test('round-trips mark JSON', () {
      const exposure = TimelineExposure.mark();

      expect(TimelineExposure.fromJson(exposure.toJson()), exposure);
    });

    test('drawing JSON without a length is rejected (legacy entries are '
        'migrated at the Layer level)', () {
      expect(
        () => TimelineExposure.fromJson({
          'type': 'drawing',
          'frameId': {'value': 'frame-a'},
        }),
        throwsFormatException,
      );
    });

    test('copyWith relinks and resizes drawings but never mutates marks', () {
      final drawing = TimelineExposure.drawing(
        const FrameId('frame-a'),
        length: 2,
      );

      expect(
        drawing.copyWith(frameId: const FrameId('frame-b')),
        TimelineExposure.drawing(const FrameId('frame-b'), length: 2),
      );
      expect(
        drawing.copyWith(length: 5),
        TimelineExposure.drawing(const FrameId('frame-a'), length: 5),
      );
      expect(
        const TimelineExposure.mark().copyWith(length: 5),
        const TimelineExposure.mark(),
      );
    });

    test('implements equality and hashCode', () {
      final a = TimelineExposure.drawing(const FrameId('frame-a'), length: 1);
      final b = TimelineExposure.drawing(const FrameId('frame-a'), length: 1);
      final c = TimelineExposure.drawing(const FrameId('frame-b'), length: 1);
      final d = TimelineExposure.drawing(const FrameId('frame-a'), length: 2);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(d));
    });
  });
}
