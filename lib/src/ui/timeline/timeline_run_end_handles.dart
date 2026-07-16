import 'package:flutter/gestures.dart'
    show DragStartBehavior, PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/timeline_repeat.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// Session-level hooks for the run-edge handles (UI-R8, TVP style):
/// [+] adds NEW one-frame drawings by dragging, [↻] creates/resizes a
/// REPEAT region. Both are one-undo drags previewing through the session's
/// drag channel.
class TimelineRunEditCallbacks {
  const TimelineRunEditCallbacks({
    required this.onAddBegin,
    required this.onAddUpdate,
    required this.onAddEnd,
    required this.onAddCancel,
    required this.onRepeatBegin,
    required this.onRepeatUpdate,
    required this.onRepeatEnd,
    required this.onRepeatCancel,
  });

  final bool Function(
    LayerId layerId,
    int blockStartIndex, {
    required bool atEnd,
  })
  onAddBegin;
  final void Function(int count) onAddUpdate;
  final VoidCallback onAddEnd;
  final VoidCallback onAddCancel;

  /// [regionId] non-null resizes that region; null creates a new one from
  /// the selection/run at [blockStartIndex].
  final bool Function(LayerId layerId, int blockStartIndex, String? regionId)
  onRepeatBegin;
  final void Function(int frameCount) onRepeatUpdate;
  final VoidCallback onRepeatEnd;
  final VoidCallback onRepeatCancel;
}

/// Main-axis extent of one run-edge mini handle.
const double timelineRunHandleExtent = 14;

enum _RunHandleKind { addEnd, addStart, repeatNew, repeatResize }

/// The [+]/[↻] mini handles hugging each glued run's edges (UI-R8):
///
/// - run END with free space after: [+] (top half — drag right = new
///   frames) and [↻] (bottom half — drag right = repeat the run/selection);
/// - run START with free space before: [+] only (drag left = prepend);
/// - a run already carrying a repeat region: [↻] at the GHOST tail's end
///   resizes the region (drag left to 0 removes it).
///
/// Ghost runs themselves get no handles (their timing is derived).
List<Widget> timelineRowRunEndHandles({
  required Layer layer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required TimelineRunEditCallbacks callbacks,
  required Axis axis,
  String keyPrefix = 'timeline',
}) {
  final handles = <Widget>[];
  final seenRunStarts = <int>{};

  double edgeX(int frameIndex) => frameVisibleX(
    frameIndex: frameIndex,
    frameStartIndex: frameStartIndex,
    frameCellWidth: frameCellExtent,
    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
  );

  bool freeAt(int index) {
    if (index < 0) {
      return false;
    }
    final entry = layer.timeline[index];
    if (entry != null) {
      return false;
    }
    final coveringKey = layer.timeline.lastKeyBefore(index);
    if (coveringKey == null) {
      return true;
    }
    final covering = layer.timeline[coveringKey]!;
    return !(covering.isDrawing && index < coveringKey + covering.length!);
  }

  /// The repeat region whose ghosts sit glued after [runEndExclusive].
  ({String regionId, int ghostEndExclusive})? repeatTailAfter(
    int runEndExclusive,
  ) {
    final entry = layer.timeline[runEndExclusive];
    if (entry == null || !entry.isDrawing || !entry.ghost) {
      return null;
    }
    final regionId = entry.repeatRegionId;
    if (regionId == null) {
      return null;
    }
    var end = runEndExclusive;
    for (final key in layer.timeline.keys) {
      if (key < runEndExclusive) {
        continue;
      }
      final ghost = layer.timeline[key]!;
      if (ghost.isDrawing && ghost.ghost && ghost.repeatRegionId == regionId) {
        end = key + ghost.length!;
      }
    }
    return (regionId: regionId, ghostEndExclusive: end);
  }

  for (final key in layer.timeline.keys) {
    final entry = layer.timeline[key]!;
    if (!entry.isDrawing || entry.ghost) {
      continue;
    }
    final run = gluedRunAt(layer, key);
    if (run == null || seenRunStarts.contains(run.startIndex)) {
      continue;
    }
    seenRunStarts.add(run.startIndex);
    if (run.endIndexExclusive < frameStartIndex ||
        run.startIndex > frameEndIndexExclusive) {
      continue;
    }

    final tail = repeatTailAfter(run.endIndexExclusive);
    if (tail != null) {
      // The region's resize handle at the ghost tail's end.
      handles.add(
        _RunEndHandle(
          key: ValueKey<String>(
            '$keyPrefix-repeat-resize-${layer.id}-${tail.regionId}',
          ),
          kind: _RunHandleKind.repeatResize,
          layerId: layer.id,
          blockStartIndex: run.startIndex,
          regionId: tail.regionId,
          existingFrames: tail.ghostEndExclusive - run.endIndexExclusive,
          edgeOffset: edgeX(tail.ghostEndExclusive),
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          half: _HandleHalf.full,
          callbacks: callbacks,
          axis: axis,
        ),
      );
    } else if (freeAt(run.endIndexExclusive)) {
      handles.add(
        _RunEndHandle(
          key: ValueKey<String>(
            '$keyPrefix-run-add-end-${layer.id}-${run.startIndex}',
          ),
          kind: _RunHandleKind.addEnd,
          layerId: layer.id,
          blockStartIndex: run.startIndex,
          edgeOffset: edgeX(run.endIndexExclusive),
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          half: _HandleHalf.leading,
          callbacks: callbacks,
          axis: axis,
        ),
      );
      handles.add(
        _RunEndHandle(
          key: ValueKey<String>(
            '$keyPrefix-run-repeat-${layer.id}-${run.startIndex}',
          ),
          kind: _RunHandleKind.repeatNew,
          layerId: layer.id,
          blockStartIndex: run.startIndex,
          edgeOffset: edgeX(run.endIndexExclusive),
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          half: _HandleHalf.trailing,
          callbacks: callbacks,
          axis: axis,
        ),
      );
    }

    if (run.startIndex > 0 && freeAt(run.startIndex - 1)) {
      handles.add(
        _RunEndHandle(
          key: ValueKey<String>(
            '$keyPrefix-run-add-start-${layer.id}-${run.startIndex}',
          ),
          kind: _RunHandleKind.addStart,
          layerId: layer.id,
          blockStartIndex: run.startIndex,
          edgeOffset: edgeX(run.startIndex) - timelineRunHandleExtent,
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          half: _HandleHalf.full,
          callbacks: callbacks,
          axis: axis,
        ),
      );
    }
  }
  return handles;
}

enum _HandleHalf { full, leading, trailing }

class _RunEndHandle extends StatefulWidget {
  const _RunEndHandle({
    super.key,
    required this.kind,
    required this.layerId,
    required this.blockStartIndex,
    this.regionId,
    this.existingFrames = 0,
    required this.edgeOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.half,
    required this.callbacks,
    required this.axis,
  });

  final _RunHandleKind kind;
  final LayerId layerId;
  final int blockStartIndex;
  final String? regionId;
  final int existingFrames;

  /// Main-axis offset where the handle's leading edge sits.
  final double edgeOffset;
  final double frameCellExtent;
  final double crossAxisExtent;
  final _HandleHalf half;
  final TimelineRunEditCallbacks callbacks;
  final Axis axis;

  @override
  State<_RunEndHandle> createState() => _RunEndHandleState();
}

class _RunEndHandleState extends State<_RunEndHandle> {
  double _accumulated = 0;
  bool _dragging = false;

  bool get _isAdd =>
      widget.kind == _RunHandleKind.addEnd ||
      widget.kind == _RunHandleKind.addStart;

  void _start() {
    final accepted = _isAdd
        ? widget.callbacks.onAddBegin(
            widget.layerId,
            widget.blockStartIndex,
            atEnd: widget.kind == _RunHandleKind.addEnd,
          )
        : widget.callbacks.onRepeatBegin(
            widget.layerId,
            widget.blockStartIndex,
            widget.regionId,
          );
    if (!accepted) {
      return;
    }
    setState(() {
      _dragging = true;
      _accumulated = 0;
    });
  }

  void _update(Offset delta) {
    if (!_dragging) {
      return;
    }
    _accumulated += widget.axis == Axis.horizontal ? delta.dx : delta.dy;
    final frames = commaDragFrameDelta(
      accumulatedDelta: _accumulated,
      frameCellExtent: widget.frameCellExtent,
    );
    switch (widget.kind) {
      case _RunHandleKind.addEnd:
        widget.callbacks.onAddUpdate(frames < 0 ? 0 : frames);
      case _RunHandleKind.addStart:
        widget.callbacks.onAddUpdate(frames > 0 ? 0 : -frames);
      case _RunHandleKind.repeatNew:
        widget.callbacks.onRepeatUpdate(frames < 0 ? 0 : frames);
      case _RunHandleKind.repeatResize:
        final next = widget.existingFrames + frames;
        widget.callbacks.onRepeatUpdate(next < 0 ? 0 : next);
    }
  }

  void _end() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    _isAdd ? widget.callbacks.onAddEnd() : widget.callbacks.onRepeatEnd();
  }

  void _cancel() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    _isAdd ? widget.callbacks.onAddCancel() : widget.callbacks.onRepeatCancel();
  }

  @override
  void dispose() {
    if (_dragging) {
      final callbacks = widget.callbacks;
      final isAdd = _isAdd;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => isAdd ? callbacks.onAddEnd() : callbacks.onRepeatEnd(),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = widget.axis == Axis.horizontal;
    final crossHalf = widget.crossAxisExtent / 2;
    final (crossStart, crossExtent) = switch (widget.half) {
      _HandleHalf.full => (0.0, widget.crossAxisExtent),
      _HandleHalf.leading => (0.0, crossHalf),
      _HandleHalf.trailing => (crossHalf, crossHalf),
    };

    final icon = switch (widget.kind) {
      _RunHandleKind.addEnd || _RunHandleKind.addStart => Icons.add,
      _RunHandleKind.repeatNew || _RunHandleKind.repeatResize => Icons.repeat,
    };
    final chip = MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      opaque: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        supportedDevices: const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => _start(),
        onPanUpdate: (details) => _update(details.delta),
        onPanEnd: (_) => _end(),
        onPanCancel: _cancel,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: _dragging
                ? colorScheme.primary.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          child: Icon(
            icon,
            size: 9,
            color: _dragging
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (horizontal) {
      return Positioned(
        left: widget.edgeOffset,
        top: crossStart,
        width: timelineRunHandleExtent,
        height: crossExtent,
        child: chip,
      );
    }
    return Positioned(
      top: widget.edgeOffset,
      left: crossStart,
      height: timelineRunHandleExtent,
      width: crossExtent,
      child: chip,
    );
  }
}
