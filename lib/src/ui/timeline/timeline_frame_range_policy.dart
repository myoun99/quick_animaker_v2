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

double timelineCutEndBoundaryX({
  required int playbackFrameCount,
  required TimelineGridMetrics metrics,
}) {
  return playbackFrameCount * metrics.frameCellWidth;
}

/// Frames of runway kept ahead of the scrolled position on the endless
/// frame axis.
const int defaultEndlessRunwayFrames = 120;

/// Premiere-style endless frame axis, shared by the timeline, the X-sheet
/// and the storyboard: the rendered frame extent grows with how far the
/// user has scrolled, always keeping [runwayFrames] of empty frames ahead,
/// so the axis never runs out. Monotonic — the extent never shrinks while
/// the panel lives (virtualized grids only pay for what is on screen).
///
/// Call from the frame-axis scroll listener and add the result to the
/// policy's base frame count for RENDER extents only; interaction clamps
/// keep using the base count.
int endlessTrailingFrames({
  required int baseFrameCount,
  required int currentTrailingFrames,
  required double scrollOffset,
  required double viewportExtent,
  required double frameCellExtent,
  int runwayFrames = defaultEndlessRunwayFrames,
}) {
  if (frameCellExtent <= 0) {
    return currentTrailingFrames;
  }
  final targetFrames =
      ((scrollOffset + viewportExtent) / frameCellExtent).ceil() + runwayFrames;
  return math.max(currentTrailingFrames, targetFrames - baseFrameCount);
}
