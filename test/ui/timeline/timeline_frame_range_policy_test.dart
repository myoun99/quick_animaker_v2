import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/core/timeline/timeline_defaults.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_range_policy.dart';

void main() {
  group('TimelineFrameRange', () {
    test('defines default cut and safety frame counts (the safety tail is '
        'RETIRED to zero — UI-R10 #23, the endless axis owns the past-cut '
        'frames)', () {
      expect(defaultCutDurationFrames, 24);
      expect(defaultTimelineSafetyFrameCount, 0);
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

    test('never shrinks MID-GESTURE (allowShrink false)', () {
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

    test('shrinks back once scrolling settles (UI-R9 #11): scrolled home, '
        'the runway releases to the base target', () {
      expect(
        endlessTrailingFrames(
          baseFrameCount: 48,
          currentTrailingFrames: 200,
          scrollOffset: 0,
          viewportExtent: 480,
          frameCellExtent: 48,
          runwayFrames: 120,
          allowShrink: true,
        ),
        // Target: ceil(480/48) + 120 − 48 = 82.
        82,
      );
    });

    test('shrink hysteresis: a release smaller than one viewport of frames '
        'keeps the current extent (no thumb jitter)', () {
      expect(
        endlessTrailingFrames(
          baseFrameCount: 48,
          currentTrailingFrames: 88,
          scrollOffset: 0,
          viewportExtent: 480,
          frameCellExtent: 48,
          runwayFrames: 120,
          allowShrink: true,
        ),
        // Target 82; release 6 < 10 (one viewport) → hold.
        88,
      );
    });

    test('the shrunken extent always covers the current viewport edge', () {
      final trailing = endlessTrailingFrames(
        baseFrameCount: 48,
        currentTrailingFrames: 500,
        scrollOffset: 4800,
        viewportExtent: 480,
        frameCellExtent: 48,
        runwayFrames: 120,
        allowShrink: true,
      );
      // Edge frame = (4800+480)/48 = 110; extent 48+trailing must cover it.
      expect(48 + trailing, greaterThanOrEqualTo(110));
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
