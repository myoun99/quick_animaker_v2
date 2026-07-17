import 'package:flutter/foundation.dart' show ValueListenable;
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
    this.framesPerSecond = 24,
    this.showSeconds = false,
    this.isFrameCached,
    this.windowBucket,
    this.viewportMainExtent = 0,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;
  final int framesPerSecond;
  final bool showSeconds;
  final bool Function(int frameIndex)? isFrameCached;

  /// PRO-TIMELINE scrolling (UI-R15→R16): the strip windows itself off
  /// the quantized bucket — pass the full bounds, repaint per crossing.
  final ValueListenable<int>? windowBucket;
  final double viewportMainExtent;

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
          framesPerSecond: framesPerSecond,
          showSeconds: showSeconds,
          isFrameCached: isFrameCached,
          windowBucket: windowBucket,
          viewportMainExtent: viewportMainExtent,
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
