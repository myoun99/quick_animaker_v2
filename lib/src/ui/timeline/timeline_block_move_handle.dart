import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../input/app_input_settings.dart' show AppInput;
import '../input/eager_pan_gesture_recognizer.dart';

import '../../models/layer_id.dart';
import '../../models/timeline_coverage.dart';
import 'property_lane_model.dart';
import 'timeline_exposure_comma_drag_handle.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// Session-level hooks for a whole-block move drag (R10-④b), threaded from
/// the tab host into the grids. The grid resolves the pointer's row into
/// [onUpdate]'s target layer before forwarding.
class TimelineBlockMoveCallbacks {
  const TimelineBlockMoveCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the drag may start (the block exists and its row
  /// supports whole-block moves).
  final bool Function(LayerId layerId, int blockStartIndex) onBegin;

  /// Reports the cumulative frame delta and the layer row currently under
  /// the pointer (null falls back to the source layer).
  final void Function({required int frameDelta, LayerId? targetLayerId})
  onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// Handle-level hooks: the handle speaks pure grid geometry — frame steps
/// along the main axis, ROW steps across it. The grid maps row steps onto
/// display rows (lanes belong to their layer) and forwards to the
/// session-level [TimelineBlockMoveCallbacks].
class TimelineBlockMoveHandleCallbacks {
  const TimelineBlockMoveHandleCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  final bool Function(LayerId layerId, int blockStartIndex) onBegin;
  final void Function(int frameDelta, int rowDelta) onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

/// Grid-side adapter shared by both orientations (Axis policy): remembers
/// the in-flight drag's source layer and resolves the handle's row deltas
/// against the CURRENT display rows/columns — the grids refresh [rows] and
/// [session] every build (rows never change mid-drag; the repository is
/// untouched until release).
class TimelineBlockMoveRowResolver {
  TimelineBlockMoveRowResolver();

  List<TimelineDisplayRow> rows = const [];
  TimelineBlockMoveCallbacks? session;
  LayerId? _sourceLayerId;

  late final TimelineBlockMoveHandleCallbacks handleCallbacks =
      TimelineBlockMoveHandleCallbacks(
        onBegin: (layerId, blockStartIndex) {
          final callbacks = session;
          if (callbacks == null) {
            return false;
          }
          final accepted = callbacks.onBegin(layerId, blockStartIndex);
          _sourceLayerId = accepted ? layerId : null;
          return accepted;
        },
        onUpdate: (frameDelta, rowDelta) {
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
        },
        onEnd: () {
          _sourceLayerId = null;
          session?.onEnd();
        },
        onCancel: () {
          _sourceLayerId = null;
          session?.onCancel();
        },
      );
}

/// The layer whose row sits [rowDelta] display rows away from
/// [sourceLayerId]'s cells row — the block-move drop target. Lane rows
/// resolve to their owning layer; out-of-range deltas clamp to the ends.
LayerId? resolveBlockMoveTargetLayer({
  required List<TimelineDisplayRow> rows,
  required LayerId sourceLayerId,
  required int rowDelta,
}) {
  if (rows.isEmpty) {
    return null;
  }
  var sourceIndex = -1;
  for (var index = 0; index < rows.length; index += 1) {
    if (!rows[index].isLane && rows[index].layer.id == sourceLayerId) {
      sourceIndex = index;
      break;
    }
  }
  if (sourceIndex < 0) {
    return null;
  }
  final targetIndex = (sourceIndex + rowDelta).clamp(0, rows.length - 1);
  return rows[targetIndex].layer.id;
}

/// A drawing block's BODY grab strip: the area between the two edge grips.
/// Dragging moves the block whole — main-axis distance in frame steps,
/// cross-axis distance in row steps (both cumulative since drag start; the
/// session recomputes the preview per step, no local accounting).
///
/// Taps fall through to the frame cells below (translucent, no tap
/// handler); only pans engage. Blocks too narrow to leave a body between
/// the grips get no handle (the builder skips them).
class TimelineBlockMoveHandle extends StatefulWidget {
  const TimelineBlockMoveHandle({
    super.key,
    required this.layerId,
    required this.blockStartIndex,
    required this.blockOrdinal,
    required this.blockStartOffset,
    required this.blockEndOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
    this.axis = Axis.horizontal,
  });

  final LayerId layerId;

  /// The block's start frame at build time (its identity for the drag).
  final int blockStartIndex;

  /// Keys derive from the ordinal, mirroring the edge grips: a mid-drag
  /// preview moves the start index every step and a key change would kill
  /// the active gesture.
  final int blockOrdinal;

  final double blockStartOffset;
  final double blockEndOffset;
  final double frameCellExtent;

  /// Row height (horizontal timeline) / column width (X-sheet) — the hit
  /// strip's cross extent AND the cross-axis row step.
  final double crossAxisExtent;

  final TimelineBlockMoveHandleCallbacks callbacks;
  final Axis axis;

  @override
  State<TimelineBlockMoveHandle> createState() =>
      _TimelineBlockMoveHandleState();
}

class _TimelineBlockMoveHandleState extends State<TimelineBlockMoveHandle> {
  double _mainDelta = 0;
  double _crossDelta = 0;
  int _lastFrames = 0;
  int _lastRows = 0;
  bool _dragging = false;

  void _startDrag() {
    final accepted = widget.callbacks.onBegin(
      widget.layerId,
      widget.blockStartIndex,
    );
    if (!accepted) {
      return;
    }
    setState(() {
      _dragging = true;
      _mainDelta = 0;
      _crossDelta = 0;
      _lastFrames = 0;
      _lastRows = 0;
    });
  }

  void _updateDrag(Offset delta) {
    if (!_dragging) {
      return;
    }
    final horizontal = widget.axis == Axis.horizontal;
    _mainDelta += horizontal ? delta.dx : delta.dy;
    _crossDelta += horizontal ? delta.dy : delta.dx;
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
    widget.callbacks.onUpdate(frames, rows);
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
    // The handle can unmount mid-drag (row scrolled out of the layer
    // window); commit rather than leak an open drag session — but AFTER
    // the frame. Unmounts happen during build, and the commit's session
    // notify must never mark widgets dirty mid-build (R12-③: the lost
    // rebuilds left stale selection outlines and canvas stacks behind).
    if (_dragging) {
      final callbacks = widget.callbacks;
      WidgetsBinding.instance.addPostFrameCallback((_) => callbacks.onEnd());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final bodyStart = widget.blockStartOffset + TimelineBlockEdgeGrip.hitExtent;
    final bodyExtent =
        widget.blockEndOffset -
        widget.blockStartOffset -
        2 * TimelineBlockEdgeGrip.hitExtent;

    final strip = MouseRegion(
      cursor: _dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.move,
      // NOT opaque: an opaque region would end the stack's hit test here
      // and starve the frame cells below of their tap-select pointer downs.
      opaque: false,
      child: RawGestureDetector(
        // Translucent: taps have no handler here and fall through to the
        // cells; only the pan recognizer competes in the arena.
        behavior: HitTestBehavior.translucent,
        // Touch joined the set (UI-R17 #6, superseding R12-⑤): stylus
        // pens report as TOUCH on some Windows/tablet drivers, which made
        // block grabs pen-dead there — grid panning stays on the
        // rulers/scrollbars. Touch follows the input policy (UI-R22 #6);
        // EAGER slop (UI-R22F #2) so slow small drags grab the block
        // instead of losing the arena to the scroll.
        gestures: <Type, GestureRecognizerFactory>{
          EagerPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                () => EagerPanGestureRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer.supportedDevices = AppInput.timelineEditPanDevices;
                  // PEN-11: RawGestureDetector does NOT inject the device
                  // gesture settings (only GestureDetector does). Without
                  // them this pan waits for kTouchSlop 18 while the
                  // viewport accepts at the DEVICE hit slop (~8 on
                  // Android) — slow pen drags lost the arena on tablets.
                  recognizer.gestureSettings =
                      MediaQuery.maybeGestureSettingsOf(context);
                  // Pixel-exact deltas from the pointer-down point (the
                  // camera overlay rule) — no slop swallowed out of the
                  // frame/row math.
                  recognizer.dragStartBehavior = DragStartBehavior.down;
                  recognizer.onStart = (_) => _startDrag();
                  recognizer.onUpdate = (details) => _updateDrag(details.delta);
                  recognizer.onEnd = (_) => _endDrag();
                  recognizer.onCancel = _cancelDrag;
                },
              ),
        },
      ),
    );

    final key = ValueKey<String>(
      'timeline-block-move-handle-${widget.layerId}-${widget.blockOrdinal}',
    );
    if (horizontal) {
      return Positioned(
        key: key,
        left: bodyStart,
        top: 0,
        width: bodyExtent,
        height: widget.crossAxisExtent,
        child: strip,
      );
    }
    return Positioned(
      key: key,
      top: bodyStart,
      left: 0,
      height: bodyExtent,
      width: widget.crossAxisExtent,
      child: strip,
    );
  }
}

/// The move handles for every drawing block wide enough to show a body
/// between its edge grips — mounted UNDER the grips in the row stack so
/// the edges keep comma-drag priority (shared by both orientations).
List<Widget> timelineRowBlockMoveHandles({
  required LayerId layerId,
  required List<TimelineDrawingBlock> blocks,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required TimelineBlockMoveHandleCallbacks callbacks,
  required Axis axis,
}) {
  final handles = <Widget>[];
  for (var ordinal = 0; ordinal < blocks.length; ordinal += 1) {
    final block = blocks[ordinal];
    if (block.endIndexExclusive <= frameStartIndex ||
        block.startIndex >= frameEndIndexExclusive) {
      continue;
    }
    final blockStartOffset = frameVisibleX(
      frameIndex: block.startIndex,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    final blockEndOffset = frameVisibleX(
      frameIndex: block.endIndexExclusive,
      frameStartIndex: frameStartIndex,
      frameCellWidth: frameCellExtent,
      leadingFrameSpacerWidth: leadingFrameSpacerWidth,
    );
    if (blockEndOffset - blockStartOffset <=
        2 * TimelineBlockEdgeGrip.hitExtent) {
      continue;
    }
    handles.add(
      TimelineBlockMoveHandle(
        layerId: layerId,
        blockStartIndex: block.startIndex,
        blockOrdinal: ordinal,
        blockStartOffset: blockStartOffset,
        blockEndOffset: blockEndOffset,
        frameCellExtent: frameCellExtent,
        crossAxisExtent: crossAxisExtent,
        callbacks: callbacks,
        axis: axis,
      ),
    );
  }
  return handles;
}
