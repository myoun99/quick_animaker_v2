import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';

TransformPose _pose(double x, {double zoom = 1.0, double rotation = 0.0}) {
  return TransformPose(
    center: CanvasPoint(x: x, y: x * 2),
    zoom: zoom,
    rotationDegrees: rotation,
  );
}

void main() {
  group('TransformTrack', () {
    test('rejects negative keyframe indexes', () {
      expect(
        () => TransformTrack(keyframes: {-1: _pose(0)}),
        throwsArgumentError,
      );
    });

    test('withKeyframe and withoutKeyframe return updated copies', () {
      final track = TransformTrack.empty();
      expect(track.isEmpty, isTrue);

      final withKey = track.withKeyframe(3, _pose(10));
      expect(track.isEmpty, isTrue, reason: 'source track is immutable');
      expect(withKey.isNotEmpty, isTrue);
      expect(withKey.keyframeAt(3), _pose(10));

      final removed = withKey.withoutKeyframe(3);
      expect(removed.isEmpty, isTrue);
      expect(withKey.keyframeAt(3), _pose(10));
    });

    test('resolveAt returns orElse for an empty track', () {
      final track = TransformTrack.empty();

      expect(
        track.resolveAt(frameIndex: 5, orElse: () => _pose(99)),
        _pose(99),
      );
    });

    test('resolveAt: exact keyframes win', () {
      final track = TransformTrack(keyframes: {2: _pose(10), 6: _pose(50)});

      expect(track.resolveAt(frameIndex: 2, orElse: () => _pose(0)), _pose(10));
    });

    test('resolveAt holds before the first and after the last keyframe', () {
      final track = TransformTrack(keyframes: {2: _pose(10), 6: _pose(50)});

      expect(track.resolveAt(frameIndex: 0, orElse: () => _pose(0)), _pose(10));
      expect(track.resolveAt(frameIndex: 9, orElse: () => _pose(0)), _pose(50));
    });

    test('resolveAt lerps component-wise between keyframes', () {
      final track = TransformTrack(
        keyframes: {
          0: _pose(0, zoom: 1.0, rotation: 0.0),
          4: _pose(8, zoom: 3.0, rotation: 360.0),
        },
      );

      final mid = track.resolveAt(frameIndex: 2, orElse: () => _pose(0));

      expect(mid.center.x, 4.0);
      expect(mid.center.y, 8.0);
      expect(mid.zoom, 2.0);
      // Rotation lerps as-is (no wrap): 0 → 360 passes through 180.
      expect(mid.rotationDegrees, 180.0);
    });

    test('JSON round-trip preserves keyframes', () {
      final track = TransformTrack(
        keyframes: {0: _pose(1), 7: _pose(2, zoom: 2.5, rotation: -30)},
      );

      expect(TransformTrack.fromJson(track.toJson()), track);
    });

    test('fromJson rejects duplicate keyframe indexes', () {
      final pose = _pose(1).toJson();
      expect(
        () => TransformTrack.fromJson({
          'keyframes': [
            {'index': 3, 'pose': pose},
            {'index': 3, 'pose': pose},
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
