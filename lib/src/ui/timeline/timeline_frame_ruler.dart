import 'package:flutter/material.dart';

import 'timeline_frame_header_row.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_ruler_cut_end_boundary.dart';

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
  final bool Function(int frameIndex)? isFrameCached;

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
          isFrameCached: isFrameCached,
        ),
        TimelineRulerCutEndBoundary(
          left: timelineCutEndBoundaryX(
            playbackFrameCount: playbackFrameCount,
            metrics: metrics,
          ),
        ),
      ],
    );
  }
}
