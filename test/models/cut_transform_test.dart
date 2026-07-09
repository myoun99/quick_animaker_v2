import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/property_track.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_cut_fade_policy.dart';

Cut _cut({int duration = 10, TransformTrack? transformTrack}) => Cut(
  id: const CutId('cut'),
  name: 'CUT 1',
  layers: const [],
  duration: duration,
  canvasSize: const CanvasSize(width: 640, height: 360),
  transformTrack: transformTrack,
);

void main() {
  group('Cut.transformTrack', () {
    test('serializes only when keyed and round-trips', () {
      final bare = _cut();
      expect(bare.toJson().containsKey('transform'), isFalse);
      final restoredBare = Cut.fromJson(bare.toJson());
      expect(restoredBare.transformTrack.isEmpty, isTrue);

      final faded = _cut(
        transformTrack: TransformTrack.empty().copyWith(
          opacity: PropertyTrack<double>.empty()
              .withKey(0, 0.0)
              .withKey(4, 1.0),
        ),
      );
      // Track-only comparison: fromJson backfills the S1·S2/CAM fixture
      // layers onto the empty-layers fixture, so whole-cut equality would
      // compare different layer lists.
      final restored = Cut.fromJson(faded.toJson());
      expect(restored.transformTrack, faded.transformTrack);
    });

    test('fadeOpacityAt resolves the opacity lane, defaulting to 1', () {
      expect(_cut().fadeOpacityAt(0), 1.0);
      expect(_cut().fadeOpacityAt(9), 1.0);

      final faded = _cut(
        transformTrack: TransformTrack.empty().copyWith(
          opacity: PropertyTrack<double>.empty()
              .withKey(0, 0.0)
              .withKey(4, 1.0)
              .withKey(7, 1.0)
              .withKey(9, 0.0),
        ),
      );
      expect(faded.fadeOpacityAt(0), 0.0);
      expect(faded.fadeOpacityAt(2), closeTo(0.5, 1e-9));
      expect(faded.fadeOpacityAt(4), 1.0);
      expect(faded.fadeOpacityAt(6), 1.0);
      expect(faded.fadeOpacityAt(8), closeTo(0.5, 1e-9));
      expect(faded.fadeOpacityAt(9), 0.0);
      // Past-the-end frames hold the last key.
      expect(faded.fadeOpacityAt(20), 0.0);
    });
  });

  group('cut fade policy', () {
    test('cutTransformWithFade writes the canonical shape both ways', () {
      final faded = _cut().copyWith(
        transformTrack: cutTransformWithFade(
          _cut(),
          fadeInFrames: 4,
          fadeOutFrames: 3,
        ),
      );

      expect(cutFadeLengths(faded), (fadeInFrames: 4, fadeOutFrames: 3));
      expect(faded.fadeOpacityAt(0), 0.0);
      expect(faded.fadeOpacityAt(4), 1.0);
      expect(faded.fadeOpacityAt(6), 1.0);
      expect(faded.fadeOpacityAt(9), 0.0);
    });

    test('zero lengths clear the lane; other lanes survive', () {
      final withScale = _cut(
        transformTrack: TransformTrack.empty().copyWith(
          scale: PropertyTrack<double>.empty().withKey(0, 1.2),
        ),
      );
      final faded = withScale.copyWith(
        transformTrack: cutTransformWithFade(
          withScale,
          fadeInFrames: 2,
          fadeOutFrames: 0,
        ),
      );
      expect(faded.transformTrack.scale.isNotEmpty, isTrue);

      final cleared = faded.copyWith(
        transformTrack: cutTransformWithFade(
          faded,
          fadeInFrames: 0,
          fadeOutFrames: 0,
        ),
      );
      expect(cleared.transformTrack.opacity.isEmpty, isTrue);
      expect(cleared.transformTrack.scale.isNotEmpty, isTrue);
    });

    test('overlapping ramps clamp instead of clobbering each other', () {
      final faded = _cut().copyWith(
        transformTrack: cutTransformWithFade(
          _cut(),
          fadeInFrames: 7,
          fadeOutFrames: 7,
        ),
      );
      final lengths = cutFadeLengths(faded);
      expect(lengths.fadeInFrames, 7);
      expect(lengths.fadeOutFrames, 2);
      expect(faded.fadeOpacityAt(0), 0.0);
      expect(faded.fadeOpacityAt(7), 1.0);
      expect(faded.fadeOpacityAt(9), 0.0);
    });

    test('hand-keyed non-canonical shapes stand the handles down', () {
      final custom = _cut(
        transformTrack: TransformTrack.empty().copyWith(
          opacity: PropertyTrack<double>.empty().withKey(5, 0.5),
        ),
      );
      expect(cutFadeLengths(custom), (fadeInFrames: 0, fadeOutFrames: 0));
    });
  });
}
