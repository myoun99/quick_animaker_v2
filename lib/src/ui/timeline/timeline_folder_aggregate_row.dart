import 'package:flutter/material.dart';

import 'timeline_grid_metrics.dart';

/// The folder HEADER's frame band (L5, the TVP-latest display): the
/// subtree members' exposure union drawn as solid blocks. Pure display —
/// nameless, no comma handles, no drags; taps fall through to nothing.
class TimelineFolderAggregateRow extends StatelessWidget {
  const TimelineFolderAggregateRow({
    super.key,
    required this.aggregateRuns,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
  });

  final List<({int start, int endExclusive})> aggregateRuns;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final windowFrameCount = frameEndIndexExclusive - frameStartIndex;
    return Row(
      children: [
        if (leadingFrameSpacerWidth > 0)
          SizedBox(width: leadingFrameSpacerWidth),
        RepaintBoundary(
          child: CustomPaint(
            size: Size(
              windowFrameCount * metrics.frameCellWidth,
              metrics.layerRowHeight,
            ),
            painter: _AggregatePainter(
              aggregateRuns: aggregateRuns,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              frameCellWidth: metrics.frameCellWidth,
              blockColor: colorScheme.secondaryContainer.withValues(
                alpha: 0.75,
              ),
              outlineColor: colorScheme.outlineVariant,
            ),
          ),
        ),
        if (trailingFrameSpacerWidth > 0)
          SizedBox(width: trailingFrameSpacerWidth),
      ],
    );
  }
}

class _AggregatePainter extends CustomPainter {
  const _AggregatePainter({
    required this.aggregateRuns,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.frameCellWidth,
    required this.blockColor,
    required this.outlineColor,
  });

  final List<({int start, int endExclusive})> aggregateRuns;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double frameCellWidth;
  final Color blockColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = blockColor;
    final outline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke;
    for (final run in aggregateRuns) {
      final visibleStart = run.start < frameStartIndex
          ? frameStartIndex
          : run.start;
      final visibleEnd = run.endExclusive > frameEndIndexExclusive
          ? frameEndIndexExclusive
          : run.endExclusive;
      if (visibleEnd <= visibleStart) {
        continue;
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          (visibleStart - frameStartIndex) * frameCellWidth,
          3,
          (visibleEnd - visibleStart) * frameCellWidth,
          size.height - 6,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, outline);
    }
  }

  @override
  bool shouldRepaint(_AggregatePainter oldDelegate) {
    return oldDelegate.aggregateRuns != aggregateRuns ||
        oldDelegate.frameStartIndex != frameStartIndex ||
        oldDelegate.frameEndIndexExclusive != frameEndIndexExclusive ||
        oldDelegate.frameCellWidth != frameCellWidth ||
        oldDelegate.blockColor != blockColor;
  }
}
