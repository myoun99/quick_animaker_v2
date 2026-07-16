import 'package:flutter/material.dart';

import 'timeline_cell_style.dart';
import 'timeline_grid_metrics.dart';

/// The frame ruler's header strip (UI-R10 #27, CSP/OpenToonz style): TWO
/// text lines — SECONDS on top (a plain second index at each second
/// boundary, nothing else), frame numbers below. The seconds display
/// toggle changes the BOTTOM line only: seconds mode repeats 1..fps per
/// second, frame mode counts absolute frame numbers.
class TimelineFrameHeaderRow extends StatelessWidget {
  const TimelineFrameHeaderRow({
    super.key,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.onSelectFrame,
    this.framesPerSecond = 24,
    this.showSeconds = false,
    this.isFrameCached,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

  /// The project fps — the seconds line ticks on its boundaries.
  final int framesPerSecond;

  /// Seconds display mode: the bottom line repeats 1..fps per second
  /// instead of counting absolute frames.
  final bool showSeconds;

  /// Whether a frame's playback composite is warmed — drawn as the AE-style
  /// green cached-range strip along the header's bottom edge.
  final bool Function(int frameIndex)? isFrameCached;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final labelEveryFrames = metrics.frameLabelEveryFrames;
    final row = Row(
      key: const ValueKey<String>('timeline-frame-header-row'),
      children: [
        SizedBox(
          key: const ValueKey<String>('timeline-frame-header-leading-spacer'),
          width: leadingFrameSpacerWidth,
          height: metrics.layerRowHeight,
        ),
        for (
          var frameIndex = frameStartIndex;
          frameIndex < frameEndIndexExclusive;
          frameIndex += 1
        )
          _FrameHeader(
            frameIndex: frameIndex,
            selected: frameIndex == currentFrameIndex,
            outsidePlaybackRange: frameIndex >= playbackFrameCount,
            cached:
                frameIndex < playbackFrameCount &&
                (isFrameCached?.call(frameIndex) ?? false),
            // Wide cells label themselves; narrow-cell labels overflow the
            // cell, so they move to the overlay below.
            showLabel: labelEveryFrames == 1,
            framesPerSecond: framesPerSecond,
            showSeconds: showSeconds,
            metrics: metrics,
          ),
        SizedBox(
          key: const ValueKey<String>('timeline-frame-header-trailing-spacer'),
          width: trailingFrameSpacerWidth,
          height: metrics.layerRowHeight,
        ),
      ],
    );
    // The SECONDS line labels overlay the top halves of the second-start
    // cells (they span multiple narrow cells when zoomed out).
    final secondsLabels = <Widget>[
      for (
        var frameIndex =
            (frameStartIndex + framesPerSecond - 1) ~/
            framesPerSecond *
            framesPerSecond;
        frameIndex < frameEndIndexExclusive;
        frameIndex += framesPerSecond
      )
        Positioned(
          left:
              leadingFrameSpacerWidth +
              (frameIndex - frameStartIndex) * metrics.frameCellWidth +
              2,
          top: 1,
          child: IgnorePointer(
            child: Text(
              // The 1-based second starting on this boundary (the sheet's
              // 秒 numbering: second 1 = frames 1..fps).
              '${frameIndex ~/ framesPerSecond + 1}',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
    ];

    if (labelEveryFrames == 1) {
      return Stack(children: [row, ...secondsLabels]);
    }

    var firstLabeledFrame =
        ((frameStartIndex + labelEveryFrames - 1) ~/ labelEveryFrames) *
        labelEveryFrames;
    return Stack(
      children: [
        row,
        ...secondsLabels,
        for (
          var frameIndex = firstLabeledFrame;
          frameIndex < frameEndIndexExclusive;
          frameIndex += labelEveryFrames
        )
          Positioned(
            left:
                leadingFrameSpacerWidth +
                (frameIndex - frameStartIndex) * metrics.frameCellWidth +
                2,
            bottom: 1,
            child: IgnorePointer(
              child: Text(
                _frameNumberLabel(
                  frameIndex,
                  framesPerSecond: framesPerSecond,
                  showSeconds: showSeconds,
                ),
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The bottom line's number for a frame: absolute in frame mode, the
/// 1..fps cycle in seconds mode (UI-R10 #27 — plain numbers, no quote
/// notation).
String _frameNumberLabel(
  int frameIndex, {
  required int framesPerSecond,
  required bool showSeconds,
}) {
  if (!showSeconds) {
    return '${frameIndex + 1}';
  }
  return '${frameIndex % framesPerSecond + 1}';
}

class _FrameHeader extends StatelessWidget {
  const _FrameHeader({
    required this.frameIndex,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.cached,
    required this.showLabel,
    required this.framesPerSecond,
    required this.showSeconds,
    required this.metrics,
  });

  final int frameIndex;
  final bool selected;
  final bool outsidePlaybackRange;
  final bool cached;
  final bool showLabel;
  final int framesPerSecond;
  final bool showSeconds;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Zoomed-out cells label every Nth frame and drop the per-cell border
    // noise (labeled cells keep a left tick; the baseline always draws).
    final labeled = frameIndex % metrics.frameLabelEveryFrames == 0;
    final narrow = metrics.frameCellWidth < 16;
    final borderColor = outsidePlaybackRange
        ? colorScheme.outlineVariant.withValues(alpha: 0.55)
        : colorScheme.outlineVariant;

    // NO per-cell InkWell (UI-R10 #25): the ruler's viewport-level scrub
    // Listener already selects on raw pointer-down — the per-frame ink
    // machinery was pure zoom-rebuild cost (hundreds of InkResponse
    // states per step at narrow cells).
    return Container(
      key: ValueKey<String>('timeline-frame-header-$frameIndex'),
      width: metrics.frameCellWidth,
      height: metrics.layerRowHeight,
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
                colorScheme.surface,
              )
            : outsidePlaybackRange
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
            : colorScheme.surface,
        border: narrow
            ? Border(
                bottom: BorderSide(color: borderColor),
                left: labeled
                    ? BorderSide(color: borderColor)
                    : BorderSide.none,
              )
            : Border.all(color: borderColor),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (showLabel)
            Positioned(
              bottom: 1,
              child: Text(
                _frameNumberLabel(
                  frameIndex,
                  framesPerSecond: framesPerSecond,
                  showSeconds: showSeconds,
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: outsidePlaybackRange
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                      : colorScheme.onSurface,
                ),
              ),
            ),
          if (cached)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                key: ValueKey<String>('timeline-frame-cached-$frameIndex'),
                height: 3,
                color: const Color(0xFF54B435),
              ),
            ),
        ],
      ),
    );
  }
}
