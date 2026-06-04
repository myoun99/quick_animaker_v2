import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';

void main() {
  group('TimelineExposure', () {
    test('drawing exposure requires frameId', () {
      expect(
        () =>
            TimelineExposure(type: TimelineExposureType.drawing, frameId: null),
        throwsAssertionError,
      );
    });

    test('blank exposure has no frameId', () {
      const exposure = TimelineExposure.blank();

      expect(exposure.type, TimelineExposureType.blank);
      expect(exposure.frameId, isNull);
    });

    test('round-trips drawing JSON', () {
      final exposure = TimelineExposure.drawing(const FrameId('frame-a'));

      expect(TimelineExposure.fromJson(exposure.toJson()), exposure);
    });

    test('round-trips blank JSON', () {
      const exposure = TimelineExposure.blank();

      expect(TimelineExposure.fromJson(exposure.toJson()), exposure);
    });

    test('implements equality and hashCode', () {
      final a = TimelineExposure.drawing(const FrameId('frame-a'));
      final b = TimelineExposure.drawing(const FrameId('frame-a'));
      final c = TimelineExposure.drawing(const FrameId('frame-b'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
