import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'timeline_grid_metrics.dart';

/// The playhead tint color, exported so tests can assert against it.
const Color timelinePlayheadColor = AppColors.accent;

class TimelinePlayhead extends StatelessWidget {
  const TimelinePlayhead({
    super.key = const ValueKey<String>('timeline-playhead'),
    required this.currentFrameIndex,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.metrics,
    required this.layerCount,
  });

  final int currentFrameIndex;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final int layerCount;

  bool get _isCurrentFrameBuilt {
    return currentFrameIndex >= frameStartIndex &&
        currentFrameIndex < frameEndIndexExclusive;
  }

  double get _left {
    return leadingFrameSpacerWidth +
        ((currentFrameIndex - frameStartIndex) * metrics.frameCellWidth);
  }

  double get _height {
    return metrics.layerRowHeight * (1 + (layerCount > 0 ? layerCount : 1));
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCurrentFrameBuilt) {
      return const SizedBox.shrink();
    }

    const playheadColor = timelinePlayheadColor;

    return IgnorePointer(
      child: SizedBox(
        height: _height,
        child: Stack(
          children: [
            Positioned(
              left: _left,
              top: 0,
              bottom: 0,
              child: Container(
                key: const ValueKey<String>('timeline-playhead-column'),
                width: metrics.frameCellWidth,
                color: playheadColor.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
