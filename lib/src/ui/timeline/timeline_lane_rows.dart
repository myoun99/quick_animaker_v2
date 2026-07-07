import 'package:flutter/material.dart';

import '../../models/layer.dart';
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';

/// The label-rail row of one property lane: an indented AE-style property
/// name under its layer row.
class TimelineLaneControlsRow extends StatelessWidget {
  const TimelineLaneControlsRow({
    super.key,
    required this.layer,
    required this.lane,
    required this.metrics,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('timeline-lane-label-${layer.id}-${lane.laneId}'),
      width: metrics.layerControlsWidth,
      height: metrics.layerRowHeight,
      padding: const EdgeInsets.only(left: 40, right: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(
            Icons.stop,
            size: 8,
            color: colorScheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              lane.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The frame-axis row of one property lane: a quiet band with key diamonds
/// at keyed frames (AE-style: linear keys are diamonds, HOLD keys squares).
/// Diamonds are real widgets so tests can find them and the editing slice
/// can hang gestures off them.
class TimelineLaneFrameRow extends StatelessWidget {
  const TimelineLaneFrameRow({
    super.key,
    required this.layer,
    required this.lane,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cellWidth = metrics.frameCellWidth;
    final rowHeight = metrics.layerRowHeight;
    final visibleWidth = (frameEndIndexExclusive - frameStartIndex) * cellWidth;
    final diamondSize = (rowHeight * 0.32).clamp(6.0, 11.0).toDouble();

    return Row(
      key: ValueKey<String>('timeline-lane-row-${layer.id}-${lane.laneId}'),
      children: [
        SizedBox(width: leadingFrameSpacerWidth, height: rowHeight),
        SizedBox(
          width: visibleWidth,
          height: rowHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final frame in lane.keyedFrames)
                  if (frame >= frameStartIndex &&
                      frame < frameEndIndexExclusive)
                    Positioned(
                      left:
                          (frame - frameStartIndex) * cellWidth +
                          cellWidth / 2 -
                          diamondSize / 2,
                      top: rowHeight / 2 - diamondSize / 2,
                      width: diamondSize,
                      height: diamondSize,
                      child: _LaneKeyDiamond(
                        key: ValueKey<String>(
                          'timeline-lane-key-${layer.id}-${lane.laneId}-$frame',
                        ),
                        hold: lane.holdOutFrames.contains(frame),
                        size: diamondSize,
                      ),
                    ),
              ],
            ),
          ),
        ),
        SizedBox(width: trailingFrameSpacerWidth, height: rowHeight),
      ],
    );
  }
}

class _LaneKeyDiamond extends StatelessWidget {
  const _LaneKeyDiamond({super.key, required this.hold, required this.size});

  final bool hold;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        border: Border.all(color: colorScheme.surface, width: 1),
      ),
    );
    // AE convention: linear keys read as diamonds, hold keys as squares.
    if (hold) {
      return shape;
    }
    return Transform.rotate(angle: 0.785398, child: shape);
  }
}
