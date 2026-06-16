import 'package:flutter/material.dart';

import 'timeline_grid_metrics.dart';

class TimelineFrameRuler extends StatelessWidget {
  const TimelineFrameRuler({
    super.key = const ValueKey<String>('timeline-frame-ruler'),
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    required this.onSelectFrame,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

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
    required this.metrics,
    required this.onSelectFrame,
  });

  final int frameIndex;
  final bool selected;
  final bool outsidePlaybackRange;
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  Colors.red.withValues(alpha: 0.12),
                  colorScheme.surface,
                )
              : outsidePlaybackRange
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
              : colorScheme.surface,
          border: Border.all(
            color: selected
                ? Colors.red
                : outsidePlaybackRange
                ? colorScheme.outlineVariant.withValues(alpha: 0.55)
                : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          '${frameIndex + 1}',
          style: TextStyle(
            color: outsidePlaybackRange
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
