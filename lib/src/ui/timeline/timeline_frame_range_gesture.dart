import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../input/app_input_settings.dart' show AppInput;

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/timeline_frame_range.dart';
import 'property_lane_model.dart';
import 'timeline_block_move_handle.dart' show resolveBlockMoveTargetLayer;
import 'timeline_exposure_comma_drag_policy.dart';

/// Session-level hooks for the frame-range MOVE drag (UI-R8) — the grid
/// resolves the pointer's row into [onUpdate]'s target layer before
/// forwarding, exactly like the block-move callbacks it succeeds.
class TimelineRangeMoveCallbacks {
  const TimelineRangeMoveCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Starts moving the CURRENT selection; false = nothing to move.
  final bool Function() onBegin;
  final void Function({required int frameDelta, LayerId? targetLayerId})
  onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// Host-level hooks for the whole range feature (UI-R8), threaded from the
/// tab host into both grids as ONE bundle: the session's selection state,
/// the select-drag hook, the tap-clear and the move-drag session.
class TimelineFrameRangeHooks {
  const TimelineFrameRangeHooks({
    required this.selection,
    required this.onSelectUpdate,
    required this.onClear,
    required this.move,
  });

  final ValueListenable<TimelineFrameRangeSelection?> selection;

  /// [headLayerId] is the row under the pointer (UI-R17 #8 — the grid
  /// resolves cross-row drags like it does for moves); null/anchor keeps
  /// the single-layer selection.
  final void Function(
    LayerId layerId,
    int anchorIndex,
    int headIndex, {
    LayerId? headLayerId,
  })
  onSelectUpdate;
  final VoidCallback onClear;
  final TimelineRangeMoveCallbacks move;
}

/// Grid-side adapter (Axis-shared): resolves the gesture layer's row
/// deltas against the current display rows and forwards to the session
/// move hooks — the block-move resolver's successor.
class TimelineRangeMoveRowResolver {
  TimelineRangeMoveRowResolver();

  List<TimelineDisplayRow> rows = const [];
  TimelineRangeMoveCallbacks? session;
  LayerId? _sourceLayerId;

  bool begin(LayerId layerId) {
    final callbacks = session;
    if (callbacks == null) {
      return false;
    }
    final accepted = callbacks.onBegin();
    _sourceLayerId = accepted ? layerId : null;
    return accepted;
  }

  void update(int frameDelta, int rowDelta) {
    final callbacks = session;
    final sourceLayerId = _sourceLayerId;
    if (callbacks == null || sourceLayerId == null) {
      return;
    }
    callbacks.onUpdate(
      frameDelta: frameDelta,
      targetLayerId: resolveBlockMoveTargetLayer(
        rows: rows,
        sourceLayerId: sourceLayerId,
        rowDelta: rowDelta,
      ),
    );
  }

  void end() {
    _sourceLayerId = null;
    session?.onEnd();
  }

  void cancel() {
    _sourceLayerId = null;
    session?.onCancel();
  }
}

/// The grid-level bundle every cells row mounts (UI-R8): ONE gesture layer
/// whose pan decides its mode at press — inside the current selection =
/// MOVE the range, anywhere else = (re)SELECT a range. Taps fall through
/// to the cells (playhead select) and clear the selection.
class TimelineRangeGestureCallbacks {
  const TimelineRangeGestureCallbacks({
    required this.selection,
    required this.onSelectUpdate,
    required this.onTapClear,
    required this.onMoveBegin,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onMoveCancel,
  });

  /// The session's live selection (read at press to pick the mode; the
  /// layer never rebuilds for selection changes).
  final ValueListenable<TimelineFrameRangeSelection?> selection;

  /// A select-drag step: anchor = where the drag started, head = the
  /// pointer's frame now (the session snaps to whole blocks). The row
  /// delta (Excel-style cross-row select, UI-R17 #8) rides along — the
  /// grid maps it onto the head layer.
  final void Function(
    LayerId layerId,
    int anchorIndex,
    int headIndex,
    int headRowDelta,
  )
  onSelectUpdate;

  /// A plain tap on the cells (no drag): clears the selection — the cell's
  /// own pointer-down keeps doing the playhead select.
  final void Function(LayerId layerId) onTapClear;

  /// Move mode (handle-level): pure grid geometry — frame steps along the
  /// main axis, ROW steps across it (the grid maps rows onto layers).
  final bool Function(LayerId layerId) onMoveBegin;
  final void Function(int frameDelta, int rowDelta) onMoveUpdate;
  final VoidCallback onMoveEnd;
  final VoidCallback onMoveCancel;
}

enum _RangeDragMode { none, select, move }

/// The row-wide gesture layer for range selection + range move (UI-R8).
/// Replaces the block-body move handle: dragging frames now SELECTS, and
/// dragging the selected span moves it (TVP style). Translucent + pen/
/// mouse only, so taps keep falling through to the cells and a finger
/// still scrolls the grid (the block-move handle's arena contract).
class TimelineFrameRangeGestureLayer extends StatefulWidget {
  const TimelineFrameRangeGestureLayer({
    super.key,
    required this.layer,
    required this.frameStartIndex,
    required this.leadingFrameSpacerWidth,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
    this.axis = Axis.horizontal,
  });

  final Layer layer;
  final int frameStartIndex;
  final double leadingFrameSpacerWidth;
  final double frameCellExtent;

  /// Row height (horizontal) / column width (X-sheet) — also the cross-
  /// axis row step for move drags.
  final double crossAxisExtent;

  final TimelineRangeGestureCallbacks callbacks;
  final Axis axis;

  @override
  State<TimelineFrameRangeGestureLayer> createState() =>
      _TimelineFrameRangeGestureLayerState();
}

class _TimelineFrameRangeGestureLayerState
    extends State<TimelineFrameRangeGestureLayer> {
  _RangeDragMode _mode = _RangeDragMode.none;
  int _anchorIndex = 0;
  double _mainDelta = 0;
  double _crossDelta = 0;
  int _lastFrames = 0;
  int _lastRows = 0;

  int _frameAt(Offset localPosition) {
    final main = widget.axis == Axis.horizontal
        ? localPosition.dx
        : localPosition.dy;
    final cell =
        ((main - widget.leadingFrameSpacerWidth) / widget.frameCellExtent)
            .floor();
    final frame = widget.frameStartIndex + cell;
    return frame < 0 ? 0 : frame;
  }

  void _startDrag(Offset localPosition) {
    final frame = _frameAt(localPosition);
    final selection = widget.callbacks.selection.value;
    final insideSelection =
        selection != null &&
        selection.coversLayer(widget.layer.id) &&
        selection.contains(frame);
    if (insideSelection && widget.callbacks.onMoveBegin(widget.layer.id)) {
      setState(() {
        _mode = _RangeDragMode.move;
        _mainDelta = 0;
        _crossDelta = 0;
        _lastFrames = 0;
        _lastRows = 0;
      });
      return;
    }
    _mode = _RangeDragMode.select;
    _anchorIndex = frame;
    widget.callbacks.onSelectUpdate(widget.layer.id, frame, frame, 0);
  }

  /// The display-row delta of the pointer relative to THIS row (Excel
  /// cross-row select): the cross-axis local position may run past the
  /// row's own bounds during the pan.
  int _rowDeltaAt(Offset localPosition) {
    final cross = widget.axis == Axis.horizontal
        ? localPosition.dy
        : localPosition.dx;
    if (widget.crossAxisExtent <= 0) {
      return 0;
    }
    return (cross / widget.crossAxisExtent).floor();
  }

  void _updateDrag(DragUpdateDetails details) {
    switch (_mode) {
      case _RangeDragMode.none:
        return;
      case _RangeDragMode.select:
        widget.callbacks.onSelectUpdate(
          widget.layer.id,
          _anchorIndex,
          _frameAt(details.localPosition),
          _rowDeltaAt(details.localPosition),
        );
      case _RangeDragMode.move:
        final horizontal = widget.axis == Axis.horizontal;
        _mainDelta += horizontal ? details.delta.dx : details.delta.dy;
        _crossDelta += horizontal ? details.delta.dy : details.delta.dx;
        final frames = commaDragFrameDelta(
          accumulatedDelta: _mainDelta,
          frameCellExtent: widget.frameCellExtent,
        );
        final rows = commaDragFrameDelta(
          accumulatedDelta: _crossDelta,
          frameCellExtent: widget.crossAxisExtent,
        );
        if (frames == _lastFrames && rows == _lastRows) {
          return;
        }
        _lastFrames = frames;
        _lastRows = rows;
        widget.callbacks.onMoveUpdate(frames, rows);
    }
  }

  void _endDrag() {
    final mode = _mode;
    _mode = _RangeDragMode.none;
    if (mode == _RangeDragMode.move) {
      setState(() {});
      widget.callbacks.onMoveEnd();
    }
  }

  void _cancelDrag() {
    final mode = _mode;
    _mode = _RangeDragMode.none;
    if (mode == _RangeDragMode.move) {
      setState(() {});
      widget.callbacks.onMoveCancel();
    }
  }

  @override
  void dispose() {
    // A mid-drag unmount (row scrolled out of the window) commits the move
    // AFTER the frame rather than leaking an open session (R12-③ rule).
    if (_mode == _RangeDragMode.move) {
      final callbacks = widget.callbacks;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => callbacks.onMoveEnd(),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: ValueKey<String>('timeline-range-gesture-${widget.layer.id}'),
      // Two detectors: the TAP (any device — a finger tap clears the
      // selection too) and the PAN. Touch joined the pan set (UI-R17
      // #6/#8): stylus pens report as TOUCH on some Windows/tablet
      // drivers, which left range selection pen-dead there — cell-area
      // panning stays available on the rulers/scrollbars.
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapUp: (_) => widget.callbacks.onTapClear(widget.layer.id),
        child: GestureDetector(
          // Translucent: the cells' pointer-down select keeps firing;
          // only the pan recognizer competes in the arena. Touch joins
          // per the input policy (UI-R22 #6): editing unless the timeline
          // scroll owns touch.
          behavior: HitTestBehavior.translucent,
          supportedDevices: AppInput.timelineEditPanDevices,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: (details) => _startDrag(details.localPosition),
          onPanUpdate: _updateDrag,
          onPanEnd: (_) => _endDrag(),
          onPanCancel: _cancelDrag,
        ),
      ),
    );
  }
}
