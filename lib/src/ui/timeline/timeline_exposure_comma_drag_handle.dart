import 'package:flutter/material.dart';

import '../../models/layer_id.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// The comma-drag grip at the trailing edge of the active layer's selected
/// exposure block: dragging it along the frame axis lengthens/shortens the
/// exposure one frame at a time.
///
/// Positioned inside the row/column Stack like
/// `TimelineSelectedExposureOutline`; the [axis] parameter transposes the
/// same geometry and gesture for the X-sheet, per the shared Axis policy.
class TimelineExposureCommaDragHandle extends StatefulWidget {
  const TimelineExposureCommaDragHandle({
    super.key,
    required this.layerId,
    required this.displayRange,
    required this.frameStartIndex,
    required this.leadingFrameSpacerWidth,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.onTryIncreaseExposure,
    required this.onTryDecreaseExposure,
    this.axis = Axis.horizontal,
  });

  final LayerId layerId;
  final SelectedExposureDisplayRange displayRange;
  final int frameStartIndex;

  /// Leading virtualization spacer extent along the frame axis.
  final double leadingFrameSpacerWidth;

  /// Main-axis extent of one frame cell (cell width in the horizontal
  /// timeline, frame row height in the X-sheet).
  final double frameCellExtent;

  /// Cross-axis extent of the block's run (row height in the horizontal
  /// timeline, column width in the X-sheet).
  final double crossAxisExtent;

  final TimelineExposureCommaStepAttempt onTryIncreaseExposure;
  final TimelineExposureCommaStepAttempt onTryDecreaseExposure;

  /// The frame axis direction; the offset math is shared and transposed.
  final Axis axis;

  /// Pointer-target extent straddling the block's end edge.
  static const double hitExtent = 14;

  static const double _gripThickness = 4;

  @override
  State<TimelineExposureCommaDragHandle> createState() =>
      _TimelineExposureCommaDragHandleState();
}

class _TimelineExposureCommaDragHandleState
    extends State<TimelineExposureCommaDragHandle> {
  TimelineExposureCommaDragSession? _dragSession;

  void _startDrag() {
    _dragSession = TimelineExposureCommaDragSession(
      frameCellExtent: widget.frameCellExtent,
    );
  }

  void _updateDrag(double delta) {
    _dragSession?.update(
      delta: delta,
      tryIncrease: widget.onTryIncreaseExposure,
      tryDecrease: widget.onTryDecreaseExposure,
    );
  }

  void _endDrag() {
    _dragSession = null;
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final endEdgeOffset = frameVisibleX(
      frameIndex: widget.displayRange.resolvedRange.endFrameIndexExclusive,
      frameStartIndex: widget.frameStartIndex,
      frameCellWidth: widget.frameCellExtent,
      leadingFrameSpacerWidth: widget.leadingFrameSpacerWidth,
    );
    final gripLength = widget.crossAxisExtent * 0.55;

    final handle = MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: horizontal ? (_) => _startDrag() : null,
        onHorizontalDragUpdate: horizontal
            ? (details) => _updateDrag(details.delta.dx)
            : null,
        onHorizontalDragEnd: horizontal ? (_) => _endDrag() : null,
        onHorizontalDragCancel: horizontal ? _endDrag : null,
        onVerticalDragStart: horizontal ? null : (_) => _startDrag(),
        onVerticalDragUpdate: horizontal
            ? null
            : (details) => _updateDrag(details.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => _endDrag(),
        onVerticalDragCancel: horizontal ? null : _endDrag,
        child: Center(
          child: Container(
            width: horizontal
                ? TimelineExposureCommaDragHandle._gripThickness
                : gripLength,
            height: horizontal
                ? gripLength
                : TimelineExposureCommaDragHandle._gripThickness,
            decoration: BoxDecoration(
              color: timelineSelectedFrameBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );

    if (horizontal) {
      return Positioned(
        key: ValueKey<String>(
          'timeline-exposure-comma-drag-handle-${widget.layerId}',
        ),
        left: endEdgeOffset - TimelineExposureCommaDragHandle.hitExtent / 2,
        top: 0,
        width: TimelineExposureCommaDragHandle.hitExtent,
        height: widget.crossAxisExtent,
        child: handle,
      );
    }
    return Positioned(
      key: ValueKey<String>(
        'timeline-exposure-comma-drag-handle-${widget.layerId}',
      ),
      top: endEdgeOffset - TimelineExposureCommaDragHandle.hitExtent / 2,
      left: 0,
      height: TimelineExposureCommaDragHandle.hitExtent,
      width: widget.crossAxisExtent,
      child: handle,
    );
  }
}
