import 'package:flutter/material.dart';

import '../input/app_input_settings.dart' show AppInput;

import '../../models/layer_id.dart';
import '../../models/timeline_coverage.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_comma_drag_policy.dart';

/// One comma-drag grip: an inset vertical bar just inside a drawing
/// block's start or end edge. Every block shows both grips (TVPaint-style
/// comma adjustment), in both orientations via [axis].
///
/// Dragging reports the CUMULATIVE whole-frame delta since drag start
/// through [callbacks]; the session recomputes the preview from its
/// drag-start snapshot, so the grip needs no per-step accounting.
class TimelineBlockEdgeGrip extends StatefulWidget {
  const TimelineBlockEdgeGrip({
    super.key,
    required this.layerId,
    required this.blockStartIndex,
    required this.blockOrdinal,
    required this.edge,
    required this.blockStartOffset,
    required this.blockEndOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
    this.axis = Axis.horizontal,
  });

  final LayerId layerId;

  /// The block's start frame index at build time (its identity for the
  /// drag; the session snapshots the layer on begin).
  final int blockStartIndex;

  /// The block's position among the layer's blocks. Keys derive from THIS,
  /// not the start index: a start-edge drag moves the start index every
  /// step, and a key change there would rebuild the gesture subtree and
  /// kill the active drag.
  final int blockOrdinal;
  final TimelineBlockEdge edge;

  /// Main-axis pixel offsets of the block's edges within the row/column
  /// content (leading spacer included).
  final double blockStartOffset;
  final double blockEndOffset;

  /// Main-axis extent of one frame cell (cell width in the horizontal
  /// timeline, frame row height in the X-sheet).
  final double frameCellExtent;

  /// Cross-axis extent of the row (row height / column width).
  final double crossAxisExtent;

  final TimelineCommaDragCallbacks callbacks;

  /// The frame axis direction; geometry and gesture transpose with it.
  final Axis axis;

  /// Pointer-target strip anchored inside the block edge — capped at a
  /// THIRD of the cell extent so a one-frame block at the slim 24px zoom
  /// keeps a tappable cell body between its two grips (fixed 12px strips
  /// covered the whole cell and swallowed cell selection).
  static const double hitExtent = 12;

  double get effectiveHitExtent =>
      hitExtent < frameCellExtent / 3 ? hitExtent : frameCellExtent / 3;

  static const double _barThickness = 3.5;
  static const double _barInset = 2.5;

  @override
  State<TimelineBlockEdgeGrip> createState() => _TimelineBlockEdgeGripState();
}

class _TimelineBlockEdgeGripState extends State<TimelineBlockEdgeGrip> {
  double _accumulatedDelta = 0;
  int _lastReportedFrames = 0;
  bool _dragging = false;

  void _startDrag() {
    final accepted = widget.callbacks.onBegin(
      widget.layerId,
      widget.blockStartIndex,
      widget.edge,
    );
    if (!accepted) {
      return;
    }
    setState(() {
      _dragging = true;
      _accumulatedDelta = 0;
      _lastReportedFrames = 0;
    });
  }

  void _updateDrag(double delta) {
    if (!_dragging) {
      return;
    }
    _accumulatedDelta += delta;
    final frames = commaDragFrameDelta(
      accumulatedDelta: _accumulatedDelta,
      frameCellExtent: widget.frameCellExtent,
    );
    if (frames == _lastReportedFrames) {
      return;
    }
    _lastReportedFrames = frames;
    widget.callbacks.onUpdate(frames);
  }

  void _endDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onEnd();
  }

  void _cancelDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onCancel();
  }

  @override
  void dispose() {
    // A grip can unmount mid-drag when its block scrolls out; the session
    // keeps the preview and the pointer-up never arrives here, so end the
    // drag as committed rather than leaking an open session.
    if (_dragging) {
      widget.callbacks.onEnd();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final isStartEdge = widget.edge == TimelineBlockEdge.start;
    final hitStart = isStartEdge
        ? widget.blockStartOffset
        : widget.blockEndOffset - widget.effectiveHitExtent;
    final barLength = widget.crossAxisExtent * 0.55;
    final barColor = _dragging
        ? timelineSelectedFrameBorderColor
        : timelineDrawingInkColor.withValues(alpha: 0.38);

    final bar = Container(
      width: horizontal ? TimelineBlockEdgeGrip._barThickness : barLength,
      height: horizontal ? barLength : TimelineBlockEdgeGrip._barThickness,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    final grip = MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Drag-only grip: touch follows the timeline input policy
        // (UI-R22F — when touch scrolls the timeline, a finger pan
        // starting on a grip must scroll too, not comma-drag).
        supportedDevices: AppInput.timelineEditPanDevices,
        onHorizontalDragStart: horizontal ? (_) => _startDrag() : null,
        onHorizontalDragUpdate: horizontal
            ? (details) => _updateDrag(details.delta.dx)
            : null,
        onHorizontalDragEnd: horizontal ? (_) => _endDrag() : null,
        onHorizontalDragCancel: horizontal ? _cancelDrag : null,
        onVerticalDragStart: horizontal ? null : (_) => _startDrag(),
        onVerticalDragUpdate: horizontal
            ? null
            : (details) => _updateDrag(details.delta.dy),
        onVerticalDragEnd: horizontal ? null : (_) => _endDrag(),
        onVerticalDragCancel: horizontal ? null : _cancelDrag,
        child: Align(
          // The bar sits inset just inside the block edge.
          alignment: horizontal
              ? (isStartEdge ? Alignment.centerLeft : Alignment.centerRight)
              : (isStartEdge ? Alignment.topCenter : Alignment.bottomCenter),
          child: Padding(
            padding: EdgeInsets.only(
              left: horizontal && isStartEdge
                  ? TimelineBlockEdgeGrip._barInset
                  : 0,
              right: horizontal && !isStartEdge
                  ? TimelineBlockEdgeGrip._barInset
                  : 0,
              top: !horizontal && isStartEdge
                  ? TimelineBlockEdgeGrip._barInset
                  : 0,
              bottom: !horizontal && !isStartEdge
                  ? TimelineBlockEdgeGrip._barInset
                  : 0,
            ),
            child: bar,
          ),
        ),
      ),
    );

    final key = ValueKey<String>(
      'timeline-block-edge-grip-${widget.edge.name}-'
      '${widget.layerId}-${widget.blockOrdinal}',
    );
    if (horizontal) {
      return Positioned(
        key: key,
        left: hitStart,
        top: 0,
        width: widget.effectiveHitExtent,
        height: widget.crossAxisExtent,
        child: grip,
      );
    }
    return Positioned(
      key: key,
      top: hitStart,
      left: 0,
      height: widget.effectiveHitExtent,
      width: widget.crossAxisExtent,
      child: grip,
    );
  }
}
