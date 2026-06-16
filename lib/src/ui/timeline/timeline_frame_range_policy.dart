import 'dart:math' as math;

import '../../core/timeline/timeline_defaults.dart';
import 'timeline_grid_metrics.dart';

class TimelineFrameRange {
  const TimelineFrameRange({
    required this.playbackFrameCount,
    required this.safetyFrameCount,
    required this.visibleFrameCount,
  });

  factory TimelineFrameRange.fromPlaybackDuration({
    required int playbackFrameCount,
    int safetyFrameCount = defaultTimelineSafetyFrameCount,
    int minimumVisibleFrameCells =
        TimelineGridMetrics.defaultMinimumVisibleFrameCells,
  }) {
    final safePlaybackFrameCount = math.max(1, playbackFrameCount);
    final safeSafetyFrameCount = math.max(0, safetyFrameCount);
    return TimelineFrameRange(
      playbackFrameCount: safePlaybackFrameCount,
      safetyFrameCount: safeSafetyFrameCount,
      visibleFrameCount: math.max(
        safePlaybackFrameCount + safeSafetyFrameCount,
        math.max(0, minimumVisibleFrameCells),
      ),
    );
  }

  final int playbackFrameCount;
  final int safetyFrameCount;
  final int visibleFrameCount;

  int get playbackEndFrameIndexExclusive => playbackFrameCount;
  int get visibleEndFrameIndexExclusive => visibleFrameCount;

  bool isOutsidePlaybackRange(int frameIndex) =>
      frameIndex >= playbackEndFrameIndexExclusive;
}
