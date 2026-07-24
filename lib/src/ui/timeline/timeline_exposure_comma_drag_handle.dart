import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../input/app_input_settings.dart' show AppInput;

import '../../models/layer_id.dart';
import '../../models/timeline_coverage.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_comma_drag_policy.dart';

/// The drag hooks a grip needs once its identity is already bound by the
/// caller (R28 #3). The timeline binds layer + block, the storyboard binds
/// the cut — below this line the two are the same grip.
class BlockEdgeGripHooks {
  const BlockEdgeGripHooks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the drag may start (e.g. the block still exists).
  final bool Function() onBegin;

  /// Reports the cumulative whole-frame delta since drag start.
  final ValueChanged<int> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// The ONE block-edge grip (R28 #3): an inset bar just inside a block's
/// start or end edge, with the whole hover/drag state machine.
///
/// Both surfaces mount THIS — the timeline through [TimelineBlockEdgeGrip]
/// and the storyboard through its cut-trim binder. The storyboard used to
/// carry a private copy that had drifted (no hover state at all), which is
/// exactly the split the user called out; a change to the grip's feel now
/// lands in both places by construction.
///
/// Dragging reports the CUMULATIVE whole-frame delta since drag start; the
/// session recomputes the preview from its drag-start snapshot, so the grip
/// needs no per-step accounting.
class BlockEdgeGrip extends StatefulWidget {
  const BlockEdgeGrip({
    super.key,
    required this.positionedKey,
    required this.edge,
    required this.blockStartOffset,
    required this.blockEndOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.hitExtent,
    required this.hooks,
    this.axis = Axis.horizontal,
    this.supportedDevices,
  });

  /// Key for the emitted [Positioned] — the Stack child identity. It stays
  /// on the Positioned (not on this widget) so existing finders and the
  /// mid-drag remount rules are untouched.
  final Key positionedKey;

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

  /// Main-axis extent of the pointer-target strip.
  final double hitExtent;

  final BlockEdgeGripHooks hooks;

  /// The frame axis direction; geometry and gesture transpose with it.
  final Axis axis;

  /// Null = every device operates the grip (the storyboard track, which
  /// has no competing touch scroll).
  final Set<PointerDeviceKind>? supportedDevices;

  @override
  State<BlockEdgeGrip> createState() => _BlockEdgeGripState();
}

/// One comma-drag grip on a TIMELINE block: binds the layer/block identity
/// onto the shared [BlockEdgeGrip]. Every block shows both grips
/// (TVPaint-style comma adjustment), in both orientations via [axis].
class TimelineBlockEdgeGrip extends StatelessWidget {
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

  /// R28 #3: the bar's cross-axis length as a fraction of the row — a
  /// CONSTANT. Hover and drag change the bar's color, never its size.
  static const double _barLengthFactor = 0.55;

  @override
  Widget build(BuildContext context) {
    return BlockEdgeGrip(
      positionedKey: ValueKey<String>(
        'timeline-block-edge-grip-${edge.name}-$layerId-$blockOrdinal',
      ),
      edge: edge,
      blockStartOffset: blockStartOffset,
      blockEndOffset: blockEndOffset,
      frameCellExtent: frameCellExtent,
      crossAxisExtent: crossAxisExtent,
      hitExtent: effectiveHitExtent,
      axis: axis,
      // Drag-only grip: touch follows the timeline input policy (UI-R22F —
      // when touch scrolls the timeline, a finger pan starting on a grip
      // must scroll too, not comma-drag).
      supportedDevices: AppInput.timelineEditPanDevices,
      hooks: BlockEdgeGripHooks(
        onBegin: () => callbacks.onBegin(layerId, blockStartIndex, edge),
        onUpdate: callbacks.onUpdate,
        onEnd: callbacks.onEnd,
        onCancel: callbacks.onCancel,
      ),
    );
  }
}

class _BlockEdgeGripState extends State<BlockEdgeGrip> {
  double _accumulatedDelta = 0;
  int _lastReportedFrames = 0;
  bool _dragging = false;

  /// R27 #11: pointer resting on the grip — lights the bar.
  bool _hovered = false;

  void _startDrag() {
    final accepted = widget.hooks.onBegin();
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
    widget.hooks.onUpdate(frames);
  }

  void _endDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.hooks.onEnd();
  }

  void _cancelDrag() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.hooks.onCancel();
  }

  @override
  void dispose() {
    // A grip can unmount mid-drag when its block scrolls out; the session
    // keeps the preview and the pointer-up never arrives here, so end the
    // drag as committed rather than leaking an open session.
    if (_dragging) {
      widget.hooks.onEnd();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final isStartEdge = widget.edge == TimelineBlockEdge.start;
    final hitStart = isStartEdge
        ? widget.blockStartOffset
        : widget.blockEndOffset - widget.hitExtent;
    // R28 #3: the grip's GEOMETRY is constant — only its color reacts.
    // R27 #11 had a hover fatten the bar (longer and thicker), and the
    // size change read as the block itself resizing under the pointer.
    // State is carried by ink alone now: quiet at rest, full on hover,
    // accent while dragging. (Both surfaces mount this one widget, so
    // the timeline and the storyboard get the same feedback.)
    final barLength =
        widget.crossAxisExtent * TimelineBlockEdgeGrip._barLengthFactor;
    final barColor = _dragging
        ? timelineSelectedFrameBorderColor
        : _hovered
        ? timelineDrawingInkColor.withValues(alpha: 0.95)
        : timelineDrawingInkColor.withValues(alpha: 0.38);
    const barThickness = TimelineBlockEdgeGrip._barThickness;
    const barInset = TimelineBlockEdgeGrip._barInset;

    final bar = Container(
      width: horizontal ? barThickness : barLength,
      height: horizontal ? barLength : barThickness,
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    final grip = MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: widget.supportedDevices,
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
              left: horizontal && isStartEdge ? barInset : 0,
              right: horizontal && !isStartEdge ? barInset : 0,
              top: !horizontal && isStartEdge ? barInset : 0,
              bottom: !horizontal && !isStartEdge ? barInset : 0,
            ),
            child: bar,
          ),
        ),
      ),
    );

    if (horizontal) {
      return Positioned(
        key: widget.positionedKey,
        left: hitStart,
        top: 0,
        width: widget.hitExtent,
        height: widget.crossAxisExtent,
        child: grip,
      );
    }
    return Positioned(
      key: widget.positionedKey,
      top: hitStart,
      left: 0,
      height: widget.hitExtent,
      width: widget.crossAxisExtent,
      child: grip,
    );
  }
}
