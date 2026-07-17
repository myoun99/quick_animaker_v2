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

/// Conte-sheet time notation for a frame COUNT: whole seconds plus leftover
/// frames — 54 frames at 24fps reads `2+06` (秒+コマ).
String timelineSecondsLabel(int frames, int fps) {
  final safeFps = math.max(1, fps);
  final seconds = frames ~/ safeFps;
  final leftover = frames % safeFps;
  return '$seconds+${leftover.toString().padLeft(2, '0')}';
}

/// The endless frame axis' contract (UI-R12 #16, unifying the timeline,
/// the X-sheet and the storyboard): cells exist exactly because they are
/// (or were) VISIBLE — the rendered extent covers the scrolled view end
/// with zero runway ahead. Scroll gestures and the scrollbar are bounded
/// by the built cells (physics/rail clamps at the extent); only a RULER
/// edge-drag overshoots the extent, and this function then materializes
/// the frames the overshot view needs ("if it must show, make the cell").
///
/// UI-R9 #11: the extent SHRINKS back too — past-content cells vanish
/// once scrolled out of view, so the scrollbar thumb recovers. Growth
/// applies immediately; shrink applies lazily ([allowShrink], the caller
/// passes true only when the axis is NOT actively scrolling) and only
/// when the release is at least one viewport-worth of frames
/// (thumb-rescale hysteresis).
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
  bool allowShrink = false,
}) {
  if (frameCellExtent <= 0) {
    return currentTrailingFrames;
  }
  final targetFrames = math.max(
    0,
    ((scrollOffset + viewportExtent) / frameCellExtent).ceil() - baseFrameCount,
  );
  if (targetFrames >= currentTrailingFrames) {
    return targetFrames;
  }
  if (!allowShrink) {
    return currentTrailingFrames;
  }
  // The formula keeps [scrollOffset + viewportExtent] covered, so the
  // shrunken extent never cuts frames out from under the viewport.
  final hysteresisFrames = math.max(
    1,
    (viewportExtent / frameCellExtent).ceil(),
  );
  return currentTrailingFrames - targetFrames >= hysteresisFrames
      ? targetFrames
      : currentTrailingFrames;
}

/// Frame cells a viewport needs to be FULLY papered (UI-R12 #16: cells in
/// the visible region never stop mid-view). Render extents take
/// max(base + trailing, this) so a wide viewport at rest still reads as
/// one continuous sheet; the scroll range stays clamped elsewhere.
int endlessViewportFillFrames({
  required double viewportExtent,
  required double frameCellExtent,
}) {
  if (frameCellExtent <= 0 || viewportExtent <= 0) {
    return 0;
  }
  return (viewportExtent / frameCellExtent).ceil();
}
