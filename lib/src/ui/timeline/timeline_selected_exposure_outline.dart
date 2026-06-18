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
  });

  final LayerId layerId;
  final SelectedExposureDisplayRange displayRange;
  final int frameStartIndex;
  final double leadingFrameSpacerWidth;
  final double frameCellWidth;
  final double rowHeight;
  final Color borderColor;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    if (!displayRange.hasVisibleIntersection) {
      return const SizedBox.shrink();
    }

    return Positioned(
      key: ValueKey<String>('timeline-selected-exposure-range-outline-$layerId'),
      left: frameVisibleX(
        frameIndex: displayRange.visibleStartFrameIndex,
        frameStartIndex: frameStartIndex,
        frameCellWidth: frameCellWidth,
        leadingFrameSpacerWidth: leadingFrameSpacerWidth,
      ),
      top: 0,
      width: frameRangeVisibleWidth(
        startFrameIndex: displayRange.visibleStartFrameIndex,
        endFrameIndexExclusive: displayRange.visibleEndFrameIndexExclusive,
        frameCellWidth: frameCellWidth,
      ),
      height: rowHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: borderRadius,
          ),
        ),
      ),
    );
  }
}
