import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/core/timeline/timeline_defaults.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_range_policy.dart';

void main() {
  group('TimelineFrameRange', () {
    test('defines default cut and safety frame counts', () {
      expect(defaultCutDurationFrames, 24);
      expect(defaultTimelineSafetyFrameCount, 24);
    });

    test('computes visible range from playback plus safety frames', () {
      final range = TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: 24,
        safetyFrameCount: 24,
      );

      expect(range.playbackFrameCount, 24);
      expect(range.safetyFrameCount, 24);
      expect(range.visibleFrameCount, 48);
      expect(range.playbackEndFrameIndexExclusive, 24);
      expect(range.visibleEndFrameIndexExclusive, 48);
      expect(range.isOutsidePlaybackRange(23), isFalse);
      expect(range.isOutsidePlaybackRange(24), isTrue);
      expect(range.isOutsidePlaybackRange(45), isTrue);
    });

    test('minimum visible cells can exceed playback plus safety frames', () {
      final range = TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: 1,
        safetyFrameCount: 0,
        minimumVisibleFrameCells: 24,
      );

      expect(range.visibleFrameCount, 24);
    });
  });
}
