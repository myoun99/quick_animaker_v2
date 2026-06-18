/// Resolves pure horizontal offset clamp math for timeline rendering.
///
/// This policy preserves ruler, body, selected exposure outline, and hit-test
/// alignment after viewport resize by producing the effective horizontal offset
/// that layout and hit testing should share.
///
/// It has no `ScrollController` side effects. Widget-side correction scheduling
/// must remain in `LayerTimelineGrid`.

library;

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
