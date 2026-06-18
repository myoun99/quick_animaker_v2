import 'dart:math' as math;

class TimelineHorizontalOffsetResolution {
  const TimelineHorizontalOffsetResolution({
    required this.requestedOffset,
    required this.effectiveOffset,
    required this.maxOffset,
  });

  final double requestedOffset;
  final double effectiveOffset;
  final double maxOffset;

  bool get needsCorrection => requestedOffset != effectiveOffset;
}

TimelineHorizontalOffsetResolution resolveTimelineHorizontalOffset({
  required double requestedOffset,
  required double totalContentWidth,
  required double viewportWidth,
}) {
  final normalizedTotalContentWidth = math.max(0.0, totalContentWidth);
  final normalizedViewportWidth = math.max(0.0, viewportWidth);

  final maxOffset = math.max(
    0.0,
    normalizedTotalContentWidth - normalizedViewportWidth,
  );

  final effectiveOffset = requestedOffset.clamp(0.0, maxOffset).toDouble();

  return TimelineHorizontalOffsetResolution(
    requestedOffset: requestedOffset,
    effectiveOffset: effectiveOffset,
    maxOffset: maxOffset,
  );
}
