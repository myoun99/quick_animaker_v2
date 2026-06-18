import 'package:flutter/material.dart';

import 'timeline_frame_header_row.dart';
import 'timeline_frame_range_policy.dart';
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
    return Stack(
      children: [
        TimelineFrameHeaderRow(
          frameStartIndex: frameStartIndex,
          frameEndIndexExclusive: frameEndIndexExclusive,
          currentFrameIndex: currentFrameIndex,
          playbackFrameCount: playbackFrameCount,
          leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          trailingFrameSpacerWidth: trailingFrameSpacerWidth,
          metrics: metrics,
          onSelectFrame: onSelectFrame,
        ),
        Positioned(
          key: const ValueKey<String>('timeline-cut-end-boundary-ruler'),
          left: timelineCutEndBoundaryX(
            playbackFrameCount: playbackFrameCount,
            metrics: metrics,
          ),
          top: 0,
          bottom: 0,
          width: 2,
          child: const IgnorePointer(
            child: DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
