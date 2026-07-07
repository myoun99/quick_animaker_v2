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

  group('endlessTrailingFrames', () {
    test('keeps a runway ahead of the scrolled position', () {
      // Scrolled edge at frame (960+480)/48 = 30; runway 120 → 150 target,
      // 48 base → 102 trailing frames.
      expect(
        endlessTrailingFrames(
          baseFrameCount: 48,
          currentTrailingFrames: 0,
          scrollOffset: 960,
          viewportExtent: 480,
          frameCellExtent: 48,
          runwayFrames: 120,
        ),
        102,
      );
    });

    test('never shrinks when scrolling back', () {
      expect(
        endlessTrailingFrames(
          baseFrameCount: 48,
          currentTrailingFrames: 200,
          scrollOffset: 0,
          viewportExtent: 480,
          frameCellExtent: 48,
        ),
        200,
      );
    });

    test('unscrolled short content adds nothing', () {
      expect(
        endlessTrailingFrames(
          baseFrameCount: 480,
          currentTrailingFrames: 0,
          scrollOffset: 0,
          viewportExtent: 480,
          frameCellExtent: 48,
          runwayFrames: 120,
        ),
        0,
      );
    });

    test('zero cell extent is a no-op', () {
      expect(
        endlessTrailingFrames(
          baseFrameCount: 48,
          currentTrailingFrames: 7,
          scrollOffset: 5000,
          viewportExtent: 480,
          frameCellExtent: 0,
        ),
        7,
      );
    });
  });
}
