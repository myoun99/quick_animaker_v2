import 'package:flutter/material.dart';

import '../../models/layer.dart';
import 'timeline_cell_style.dart';
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
    this.members = const [],
    this.memberHasContentAt,
  });

  final List<({int start, int endExclusive})> aggregateRuns;

  /// R28 #11: the subtree's members and the cel-content probe — the band
  /// greys a frame only when none of them has artwork there.
  final List<Layer> members;
  final bool Function(Layer layer, int frameIndex)? memberHasContentAt;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
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
              // R27 #22: the aggregate reads as a FRAME BLOCK, in the
              // frame block's paper — the old translucent accent wash
              // made the folder band look like a different object than
              // the blocks it summarises.
              blockColor: timelineDrawingStartColor,
              outlineColor: timelineDrawingStartBorderColor,
              members: members,
              memberHasContentAt: memberHasContentAt,
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
    required this.members,
    required this.memberHasContentAt,
  });

  final List<({int start, int endExclusive})> aggregateRuns;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double frameCellWidth;
  final Color blockColor;
  final Color outlineColor;
  final List<Layer> members;

  /// Null = no content probe (hosts without cel pixels) — the band then
  /// paints solid, as it did before R28 #11.
  final bool Function(Layer layer, int frameIndex)? memberHasContentAt;

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

      // R28 #11: the empty-cel grey reaches the folder band. A frame is
      // grey only when NO member has artwork there — the band summarises
      // the subtree, so one drawn member anywhere in it keeps the frame
      // white ("다른곳에서 해당위치에 그림그려진 하얀 블록 존재하면 하얗게").
      // Same wash the member rows use (R27 #13), painted over the block.
      final hasContent = memberHasContentAt;
      if (hasContent != null) {
        final tint = Paint()..color = timelineEmptyCelBlockColor;
        canvas.save();
        canvas.clipRRect(rect);
        for (var frame = visibleStart; frame < visibleEnd; frame += 1) {
          if (members.any((member) => hasContent(member, frame))) {
            continue;
          }
          canvas.drawRect(
            Rect.fromLTWH(
              (frame - frameStartIndex) * frameCellWidth,
              3,
              frameCellWidth,
              size.height - 6,
            ),
            tint,
          );
        }
        canvas.restore();
      }

      canvas.drawRRect(rect, outline);
    }
  }

  @override
  bool shouldRepaint(_AggregatePainter oldDelegate) {
    return oldDelegate.aggregateRuns != aggregateRuns ||
        oldDelegate.frameStartIndex != frameStartIndex ||
        oldDelegate.frameEndIndexExclusive != frameEndIndexExclusive ||
        oldDelegate.frameCellWidth != frameCellWidth ||
        oldDelegate.blockColor != blockColor ||
        // The content probe is a session tear-off (new identity per host
        // rebuild) and the member list churns with any edit — comparing
        // them keeps an empty↔drawn flip from showing a stale tint, the
        // R27 #13 failure mode one level up.
        !identical(oldDelegate.members, members) ||
        oldDelegate.memberHasContentAt != memberHasContentAt;
  }
}
