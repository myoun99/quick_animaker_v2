import 'dart:math' as math;

/// Inclusive/exclusive range of timeline item indexes that should be considered
/// visible by a viewport calculation.
class TimelineVisibleRange {
  const TimelineVisibleRange({
    required this.startIndex,
    required this.endIndexExclusive,
  });

  /// First visible index, inclusive.
  final int startIndex;

  /// End of the visible range, exclusive.
  final int endIndexExclusive;

  /// Number of indexes represented by this range.
  int get count => endIndexExclusive - startIndex;

  /// Whether this range contains no indexes.
  bool get isEmpty => count <= 0;

  /// Whether [index] is inside this inclusive/exclusive range.
  bool contains(int index) => index >= startIndex && index < endIndexExclusive;

  @override
  bool operator ==(Object other) {
    return other is TimelineVisibleRange &&
        other.startIndex == startIndex &&
        other.endIndexExclusive == endIndexExclusive;
  }

  @override
  int get hashCode => Object.hash(startIndex, endIndexExclusive);

  @override
  String toString() {
    return 'TimelineVisibleRange(startIndex: $startIndex, '
        'endIndexExclusive: $endIndexExclusive)';
  }
}

/// Visible timeline ranges for both timeline axes.
class TimelineVisibleRanges {
  const TimelineVisibleRanges({
    required this.frames,
    required this.layers,
  });

  /// Visible frame index range calculated from the horizontal viewport.
  final TimelineVisibleRange frames;

  /// Visible layer index range calculated from the vertical viewport.
  final TimelineVisibleRange layers;

  @override
  bool operator ==(Object other) {
    return other is TimelineVisibleRanges &&
        other.frames == frames &&
        other.layers == layers;
  }

  @override
  int get hashCode => Object.hash(frames, layers);

  @override
  String toString() {
    return 'TimelineVisibleRanges(frames: $frames, layers: $layers)';
  }
}

/// Calculates the visible inclusive/exclusive item index range for one axis.
///
/// The returned range is always clamped to `0..itemCount`. Negative scroll
/// offsets are treated as zero, and negative viewport extents are treated as an
/// empty viewport at the scroll position. [itemExtent] must be greater than
/// zero because zero-sized or negative-sized items cannot produce a meaningful
/// range.
TimelineVisibleRange calculateVisibleIndexRange({
  required double scrollOffset,
  required double viewportExtent,
  required double itemExtent,
  required int itemCount,
  int overscanBefore = 2,
  int overscanAfter = 2,
}) {
  if (itemExtent <= 0) {
    throw ArgumentError.value(
      itemExtent,
      'itemExtent',
      'must be greater than zero',
    );
  }

  if (itemCount <= 0) {
    return const TimelineVisibleRange(startIndex: 0, endIndexExclusive: 0);
  }

  final safeScrollOffset = math.max(0.0, scrollOffset);
  final safeViewportExtent = math.max(0.0, viewportExtent);
  final safeOverscanBefore = math.max(0, overscanBefore);
  final safeOverscanAfter = math.max(0, overscanAfter);

  final rawStartIndex =
      (safeScrollOffset / itemExtent).floor() - safeOverscanBefore;
  final rawEndIndexExclusive =
      ((safeScrollOffset + safeViewportExtent) / itemExtent).ceil() +
          safeOverscanAfter;

  final startIndex = math.min(math.max(rawStartIndex, 0), itemCount);
  final endIndexExclusive = math.min(
    math.max(rawEndIndexExclusive, startIndex),
    itemCount,
  );

  return TimelineVisibleRange(
    startIndex: startIndex,
    endIndexExclusive: endIndexExclusive,
  );
}

/// Calculates visible frame and layer ranges for the two timeline axes.
TimelineVisibleRanges calculateTimelineVisibleRanges({
  required double horizontalScrollOffset,
  required double verticalScrollOffset,
  required double viewportWidth,
  required double viewportHeight,
  required double frameCellWidth,
  required double layerRowHeight,
  required int frameCount,
  required int layerCount,
  int frameOverscanBefore = 2,
  int frameOverscanAfter = 2,
  int layerOverscanBefore = 2,
  int layerOverscanAfter = 2,
}) {
  return TimelineVisibleRanges(
    frames: calculateVisibleIndexRange(
      scrollOffset: horizontalScrollOffset,
      viewportExtent: viewportWidth,
      itemExtent: frameCellWidth,
      itemCount: frameCount,
      overscanBefore: frameOverscanBefore,
      overscanAfter: frameOverscanAfter,
    ),
    layers: calculateVisibleIndexRange(
      scrollOffset: verticalScrollOffset,
      viewportExtent: viewportHeight,
      itemExtent: layerRowHeight,
      itemCount: layerCount,
      overscanBefore: layerOverscanBefore,
      overscanAfter: layerOverscanAfter,
    ),
  );
}
