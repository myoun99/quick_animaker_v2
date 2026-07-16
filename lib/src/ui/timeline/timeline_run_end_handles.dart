import 'package:flutter/gestures.dart'
    show DragStartBehavior, PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/timeline_repeat.dart';
import '../widgets/panel_flyout.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';

/// Session-level hooks for the run-edge affordances (UI-R9 #10, TVP
/// style): [+] adds NEW one-frame drawings by dragging (one-undo drag
/// previewing through the session's drag channel); the edge property TAG
/// sets the edge's None/Hold/Repeat mode through a flyout (immediate
/// one-undo commit).
class TimelineRunEditCallbacks {
  const TimelineRunEditCallbacks({
    required this.onAddBegin,
    required this.onAddUpdate,
    required this.onAddEnd,
    required this.onAddCancel,
    required this.onEdgeModeSelected,
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

  /// The tag flyout picked a mode for the run edge; null clears it (None).
  final void Function(
    LayerId layerId,
    int blockStartIndex,
    TimelineRunEdgeSide side,
    TimelineRunEdgeMode? mode,
  )
  onEdgeModeSelected;
}

/// Main-axis extent of one run-edge affordance ([+] chip or property tag).
const double timelineRunHandleExtent = 14;

/// The run-edge clusters hugging each glued run (UI-R9 #10):
///
/// - run END: `[블록][+][태그]` — the [+] chip (full cross extent, accent)
///   drags new frames onto the run; the property tag (▸H/▸R; hover-only
///   when None) opens the None/Hold/Repeat flyout. A Hold/Repeat edge puts
///   the cluster after its ghost tail.
/// - run START: the mirror, `[태그][+][블록]`.
///
/// Ghost runs themselves get no clusters (their timing is derived).
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

  /// One past the last ghost of the contiguous chain [behavior] owns,
  /// scanning from [from]; [from] itself when it owns none there.
  int ghostChainEnd(TimelineRunBehavior behavior, int from) {
    var end = from;
    var key = layer.timeline.containsKey(from)
        ? from
        : layer.timeline.firstKeyAfter(from);
    while (key != null && key == end) {
      final entry = layer.timeline[key]!;
      if (!entry.ghost || entry.ghostOwnerId != behavior.ghostOwnerId) {
        break;
      }
      end = key + entry.length!;
      key = layer.timeline.firstKeyAfter(key);
    }
    return end;
  }

  /// First frame of the contiguous chain [behavior] owns ENDING at [until];
  /// [until] itself when it owns none there.
  int ghostChainStart(TimelineRunBehavior behavior, int until) {
    var start = until;
    var key = layer.timeline.lastKeyBefore(until);
    while (key != null) {
      final entry = layer.timeline[key]!;
      if (!entry.ghost ||
          entry.ghostOwnerId != behavior.ghostOwnerId ||
          key + entry.length! != start) {
        break;
      }
      start = key;
      key = layer.timeline.lastKeyBefore(key);
    }
    return start;
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

    // END side: [블록][고스트 테일][+][태그].
    final endBehavior = runEdgeBehaviorAt(
      layer,
      run.startIndex,
      TimelineRunEdgeSide.end,
    );
    final endEdge = endBehavior == null
        ? run.endIndexExclusive
        : ghostChainEnd(endBehavior, run.endIndexExclusive);
    handles.add(
      _RunEdgeCluster(
        // Keys carry the run's ANCHOR identity, never an index: an
        // add-start preview shifts every index left, and an index-keyed
        // handle would remount mid-gesture (killing the pan and
        // committing one frame) — R12-③.
        key: ValueKey<String>(
          '$keyPrefix-run-edge-end-${layer.id}-${run.anchorFrameId.value}',
        ),
        keyPrefix: keyPrefix,
        side: TimelineRunEdgeSide.end,
        layerId: layer.id,
        blockStartIndex: run.startIndex,
        anchorValue: run.anchorFrameId.value,
        mode: endBehavior?.mode,
        showAdd: freeAt(endEdge),
        edgeOffset: edgeX(endEdge),
        frameCellExtent: frameCellExtent,
        crossAxisExtent: crossAxisExtent,
        callbacks: callbacks,
        axis: axis,
      ),
    );

    // START side mirror: [태그][+][고스트 리드인][블록].
    final startBehavior = runEdgeBehaviorAt(
      layer,
      run.startIndex,
      TimelineRunEdgeSide.start,
    );
    final startEdge = startBehavior == null
        ? run.startIndex
        : ghostChainStart(startBehavior, run.startIndex);
    if (startEdge > 0 || startBehavior != null) {
      handles.add(
        _RunEdgeCluster(
          key: ValueKey<String>(
            '$keyPrefix-run-edge-start-${layer.id}-${run.anchorFrameId.value}',
          ),
          keyPrefix: keyPrefix,
          side: TimelineRunEdgeSide.start,
          layerId: layer.id,
          blockStartIndex: run.startIndex,
          anchorValue: run.anchorFrameId.value,
          mode: startBehavior?.mode,
          showAdd: startEdge > 0 && freeAt(startEdge - 1),
          edgeOffset: edgeX(startEdge),
          frameCellExtent: frameCellExtent,
          crossAxisExtent: crossAxisExtent,
          callbacks: callbacks,
          axis: axis,
        ),
      );
    }
  }
  return handles;
}

/// One run edge's affordance cluster: the accent [+] add chip plus the
/// N/H/R property tag, laid main-axis in block-outward order.
class _RunEdgeCluster extends StatefulWidget {
  const _RunEdgeCluster({
    super.key,
    required this.keyPrefix,
    required this.side,
    required this.layerId,
    required this.blockStartIndex,
    required this.anchorValue,
    required this.mode,
    required this.showAdd,
    required this.edgeOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
    required this.axis,
  });

  final String keyPrefix;
  final TimelineRunEdgeSide side;
  final LayerId layerId;
  final int blockStartIndex;
  final String anchorValue;

  /// The edge's current mode; null = None (tag shows on hover only).
  final TimelineRunEdgeMode? mode;
  final bool showAdd;

  /// Main-axis offset of the run edge (start of free space for the end
  /// side; the run/lead-in start for the start side).
  final double edgeOffset;
  final double frameCellExtent;
  final double crossAxisExtent;
  final TimelineRunEditCallbacks callbacks;
  final Axis axis;

  @override
  State<_RunEdgeCluster> createState() => _RunEdgeClusterState();
}

class _RunEdgeClusterState extends State<_RunEdgeCluster> {
  double _accumulated = 0;
  bool _dragging = false;
  bool _hovered = false;

  bool get _atEnd => widget.side == TimelineRunEdgeSide.end;

  void _startAdd() {
    final accepted = widget.callbacks.onAddBegin(
      widget.layerId,
      widget.blockStartIndex,
      atEnd: _atEnd,
    );
    if (!accepted) {
      return;
    }
    setState(() {
      _dragging = true;
      _accumulated = 0;
    });
  }

  void _updateAdd(Offset delta) {
    if (!_dragging) {
      return;
    }
    _accumulated += widget.axis == Axis.horizontal ? delta.dx : delta.dy;
    final frames = commaDragFrameDelta(
      accumulatedDelta: _accumulated,
      frameCellExtent: widget.frameCellExtent,
    );
    widget.callbacks.onAddUpdate(
      _atEnd ? (frames < 0 ? 0 : frames) : (frames > 0 ? 0 : -frames),
    );
  }

  void _endAdd() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onAddEnd();
  }

  void _cancelAdd() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.callbacks.onAddCancel();
  }

  @override
  void dispose() {
    if (_dragging) {
      final callbacks = widget.callbacks;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => callbacks.onAddEnd(),
      );
    }
    super.dispose();
  }

  void _openModeFlyout(BuildContext anchorContext) {
    void pick(TimelineRunEdgeMode? mode) => widget.callbacks
        .onEdgeModeSelected(
          widget.layerId,
          widget.blockStartIndex,
          widget.side,
          mode,
        );
    showPanelFlyout(
      anchorContext,
      entries: [
        PanelFlyoutItem(
          keyValue: 'run-edge-mode-none',
          label: 'None',
          checked: widget.mode == null,
          onSelected: () => pick(null),
        ),
        PanelFlyoutItem(
          keyValue: 'run-edge-mode-hold',
          label: 'Hold',
          checked: widget.mode == TimelineRunEdgeMode.hold,
          onSelected: () => pick(TimelineRunEdgeMode.hold),
        ),
        PanelFlyoutItem(
          keyValue: 'run-edge-mode-repeat',
          label: 'Repeat',
          checked: widget.mode == TimelineRunEdgeMode.repeat,
          onSelected: () => pick(TimelineRunEdgeMode.repeat),
        ),
      ],
    );
  }

  Widget _addChip(ColorScheme colorScheme) {
    final horizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      opaque: false,
      child: GestureDetector(
        key: ValueKey<String>(
          '${widget.keyPrefix}-run-add-${_atEnd ? 'end' : 'start'}-'
          '${widget.layerId}-${widget.anchorValue}',
        ),
        behavior: HitTestBehavior.opaque,
        supportedDevices: const {
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.invertedStylus,
        },
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (_) => _startAdd(),
        onPanUpdate: (details) => _updateAdd(details.delta),
        onPanEnd: (_) => _endAdd(),
        onPanCancel: _cancelAdd,
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            // The accent chip (UI-R9 #10: "[+] = 칩 확대 + 액센트").
            color: _dragging
                ? colorScheme.primary.withValues(alpha: 0.45)
                : colorScheme.primaryContainer.withValues(alpha: 0.9),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.55),
            ),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          child: Icon(
            Icons.add,
            size: 10,
            color: _dragging
                ? colorScheme.onSurface
                : colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _propertyTag(ColorScheme colorScheme) {
    final label = switch (widget.mode) {
      TimelineRunEdgeMode.hold => 'H',
      TimelineRunEdgeMode.repeat => 'R',
      null => '·',
    };
    final active = widget.mode != null;
    return Builder(
      builder: (anchorContext) => MouseRegion(
        cursor: SystemMouseCursors.click,
        opaque: false,
        child: GestureDetector(
          key: ValueKey<String>(
            '${widget.keyPrefix}-run-edge-tag-${widget.layerId}-'
            '${widget.anchorValue}-${widget.side.name}',
          ),
          behavior: HitTestBehavior.opaque,
          onTap: () => _openModeFlyout(anchorContext),
          child: Container(
            margin: const EdgeInsets.all(1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? colorScheme.primary.withValues(alpha: 0.25)
                  : colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
              border: Border.all(
                color: active
                    ? colorScheme.primary.withValues(alpha: 0.55)
                    : colorScheme.outlineVariant,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w700,
                color: active
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontal = widget.axis == Axis.horizontal;
    final showTag = widget.mode != null || _hovered || _dragging;

    // Block-outward order: end = [+] then tag; start = tag then [+].
    // Slot keys keep the [+] ELEMENT alive when the hover-revealed tag
    // shifts it within the Row — a positional rematch would remount the
    // chip mid-pan and its dispose would commit the drag at one frame
    // (the R12-③ failure mode, one layer up).
    final slots = <Widget>[
      if (widget.showAdd)
        SizedBox(
          key: const ValueKey<String>('run-edge-slot-add'),
          width: horizontal ? timelineRunHandleExtent : null,
          height: horizontal ? null : timelineRunHandleExtent,
          child: _addChip(colorScheme),
        ),
      if (showTag)
        SizedBox(
          key: const ValueKey<String>('run-edge-slot-tag'),
          width: horizontal ? timelineRunHandleExtent : null,
          height: horizontal ? null : timelineRunHandleExtent,
          child: _propertyTag(colorScheme),
        ),
    ];
    final children = _atEnd ? slots : slots.reversed.toList();

    // The whole reserved area is the HOVER zone — the tag must appear when
    // the pointer nears the edge even while it is the only hidden slot.
    final cluster = MouseRegion(
      opaque: false,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Align(
        alignment: horizontal
            ? (_atEnd ? Alignment.centerLeft : Alignment.centerRight)
            : (_atEnd ? Alignment.topCenter : Alignment.bottomCenter),
        child: horizontal
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
      ),
    );

    // Reserve both slots' extent; the start side grows leftward (upward)
    // from the edge.
    const clusterExtent = timelineRunHandleExtent * 2;
    final mainStart = _atEnd
        ? widget.edgeOffset
        : widget.edgeOffset - clusterExtent;

    if (horizontal) {
      return Positioned(
        left: mainStart,
        top: 0,
        width: clusterExtent,
        height: widget.crossAxisExtent,
        child: cluster,
      );
    }
    return Positioned(
      top: mainStart,
      left: 0,
      height: clusterExtent,
      width: widget.crossAxisExtent,
      child: cluster,
    );
  }
}
