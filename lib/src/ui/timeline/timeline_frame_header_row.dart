import 'package:flutter/material.dart';

import 'timeline_cell_style.dart';
import 'timeline_grid_metrics.dart';

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

  /// Whether a frame's playback composite is warmed — drawn as the AE-style
  /// green cached-range strip along the header's bottom edge.
  final bool Function(int frameIndex)? isFrameCached;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            metrics: metrics,
            onSelectFrame: onSelectFrame,
          ),
        SizedBox(
          key: const ValueKey<String>('timeline-frame-header-trailing-spacer'),
          width: trailingFrameSpacerWidth,
          height: metrics.layerRowHeight,
        ),
      ],
    );
  }
}

class _FrameHeader extends StatelessWidget {
  const _FrameHeader({
    required this.frameIndex,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.cached,
    required this.metrics,
    required this.onSelectFrame,
  });

  final int frameIndex;
  final bool selected;
  final bool outsidePlaybackRange;
  final bool cached;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey<String>('timeline-frame-header-$frameIndex'),
      onTap: () => onSelectFrame(frameIndex),
      child: Container(
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
          border: Border.all(
            color: outsidePlaybackRange
                ? colorScheme.outlineVariant.withValues(alpha: 0.55)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${frameIndex + 1}',
              style: TextStyle(
                color: outsidePlaybackRange
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                    : colorScheme.onSurface,
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
      ),
    );
  }
}
