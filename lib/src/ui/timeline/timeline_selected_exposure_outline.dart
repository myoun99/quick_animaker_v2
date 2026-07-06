import 'package:flutter/material.dart';

import '../../models/layer_id.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

class TimelineSelectedExposureOutline extends StatelessWidget {
  const TimelineSelectedExposureOutline({
    super.key,
    required this.layerId,
    required this.displayRange,
    required this.frameStartIndex,
    required this.leadingFrameSpacerWidth,
    required this.frameCellWidth,
    required this.rowHeight,
    required this.borderColor,
    required this.borderRadius,
    this.axis = Axis.horizontal,
  });

  final LayerId layerId;
  final SelectedExposureDisplayRange displayRange;
  final int frameStartIndex;
  final double leadingFrameSpacerWidth;
  final double frameCellWidth;

  /// Cross-axis extent of the outlined run (row height in the horizontal
  /// timeline, column width in the X-sheet).
  final double rowHeight;
  final Color borderColor;
  final BorderRadius borderRadius;

  /// The frame axis direction; the offset math is shared and transposed.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    if (!displayRange.hasVisibleIntersection) {
      return const SizedBox.shrink();
    }

    final mainAxisOffset = frameVisibleX(
      frameIndex: displayRange.visibleStartFrameIndex,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellWidth,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final mainAxisExtent = frameRangeVisibleWidth(
      startFrameIndex: displayRange.visibleStartFrameIndex,
      endFrameIndexExclusive: displayRange.visibleEndFrameIndexExclusive,
      frameCellWidth: frameCellWidth,
    );
    final outline = IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: borderRadius,
        ),
      ),
    );

    if (axis == Axis.vertical) {
      return Positioned(
        key: ValueKey<String>(
          'timeline-selected-exposure-range-outline-$layerId',
        ),
        top: mainAxisOffset,
        left: 0,
        height: mainAxisExtent,
        width: rowHeight,
        child: outline,
      );
    }
    return Positioned(
      key: ValueKey<String>(
        'timeline-selected-exposure-range-outline-$layerId',
      ),
      left: mainAxisOffset,
      top: 0,
      width: mainAxisExtent,
      height: rowHeight,
      child: outline,
    );
  }
}
