import 'package:flutter/gestures.dart'
    show DragStartBehavior, PointerDeviceKind;
import 'package:flutter/material.dart';

import '../../models/frame_id.dart';
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

/// The run-edge clusters hugging each glued run (UI-R10 #1/#3):
///
/// - run END: `[블록][+][태그]` — the [+] chip drags new frames onto the
///   run; the property tag (N/H/R, ALWAYS visible) opens the mode flyout.
/// - run START: the mirror, `[태그][+][블록]`.
///
/// The cluster sits on the AUTHORED run edge always — hold/repeat ghost
/// tails render past it, never displace it (#3) — and both chips share
/// the quiet 3-state visual: translucent gray at rest, white on hover,
/// accent only WHILE operating (#1). A selection-scoped repeat pattern
/// additionally draws a soft outline around its pattern span (#5).
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

  /// Free of AUTHORED coverage — ghosts are derived and never block the
  /// [+] (adding frames pushes them out on rederive).
  bool freeAt(int index) {
    if (index < 0) {
      return false;
    }
    final entry = layer.timeline[index];
    if (entry != null && !entry.ghost) {
      return false;
    }
    var key = layer.timeline.lastKeyBefore(index);
    while (key != null && layer.timeline[key]!.ghost) {
      key = layer.timeline.lastKeyBefore(key);
    }
    if (key == null) {
      return true;
    }
    final covering = layer.timeline[key]!;
    return index >= key + covering.length!;
  }

  /// Lowest non-ghost block start carrying [frameId] inside the run.
  int? blockStartOf(
    FrameId frameId,
    ({int startIndex, int endIndexExclusive, FrameId anchorFrameId}) run,
  ) {
    for (final entry in layer.timeline.entries) {
      if (entry.value.ghost || entry.value.frameId != frameId) {
        continue;
      }
      if (entry.key >= run.startIndex && entry.key < run.endIndexExclusive) {
        return entry.key;
      }
      return null;
    }
    return null;
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

    final endBehavior = runEdgeBehaviorAt(
      layer,
      run.startIndex,
      TimelineRunEdgeSide.end,
    );
    final startBehavior = runEdgeBehaviorAt(
      layer,
      run.startIndex,
      TimelineRunEdgeSide.start,
    );

    // A selection-scoped repeat pattern shows its span (UI-R10 #5).
    for (final behavior in [endBehavior, startBehavior]) {
      if (behavior == null ||
          behavior.mode != TimelineRunEdgeMode.repeat ||
          behavior.patternAnchorFrameId == null) {
        continue;
      }
      final anchorStart = blockStartOf(behavior.patternAnchorFrameId!, run);
      if (anchorStart == null) {
        continue;
      }
      final (spanStart, spanEnd) = behavior.side == TimelineRunEdgeSide.end
          ? (anchorStart, run.endIndexExclusive)
          : (
              run.startIndex,
              anchorStart + layer.timeline[anchorStart]!.length!,
            );
      final left = edgeX(spanStart);
      final extent = edgeX(spanEnd) - left;
      final outline = IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFE57373).withValues(alpha: 0.55),
              width: 1.5,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
        ),
      );
      handles.add(
        axis == Axis.horizontal
            ? Positioned(
                key: ValueKey<String>(
                  '$keyPrefix-run-pattern-${layer.id}-'
                  '${behavior.anchorFrameId.value}-${behavior.side.name}',
                ),
                left: left,
                top: 0,
                width: extent,
                height: crossAxisExtent,
                child: outline,
              )
            : Positioned(
                key: ValueKey<String>(
                  '$keyPrefix-run-pattern-${layer.id}-'
                  '${behavior.anchorFrameId.value}-${behavior.side.name}',
                ),
                top: left,
                left: 0,
                height: extent,
                width: crossAxisExtent,
                child: outline,
              ),
      );
    }

    // END cluster on the authored edge (#3): [블록][+][태그].
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
        showAdd: freeAt(run.endIndexExclusive),
        edgeOffset: edgeX(run.endIndexExclusive),
        frameCellExtent: frameCellExtent,
        crossAxisExtent: crossAxisExtent,
        callbacks: callbacks,
        axis: axis,
      ),
    );

    // START cluster mirror: [태그][+][블록].
    if (run.startIndex > 0) {
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
          showAdd: freeAt(run.startIndex - 1),
          edgeOffset: edgeX(run.startIndex),
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

/// One run edge's affordance cluster: the [+] add chip plus the N/H/R
/// property tag, laid main-axis in block-outward order. Both chips share
/// the 3-state visual (rest/hover/operating — UI-R10 #1).
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

  /// The edge's current mode; null = None. Display stays quiet either
  /// way — the letter changes, never the accent (#1).
  final TimelineRunEdgeMode? mode;
  final bool showAdd;

  /// Main-axis offset of the authored run edge.
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
  bool _addHovered = false;
  bool _tagHovered = false;
  bool _menuOpen = false;

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

  Future<void> _openModeFlyout(BuildContext anchorContext) async {
    void pick(TimelineRunEdgeMode? mode) => widget.callbacks
        .onEdgeModeSelected(
          widget.layerId,
          widget.blockStartIndex,
          widget.side,
          mode,
        );
    setState(() => _menuOpen = true);
    await showPanelFlyout(
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
    if (mounted) {
      setState(() => _menuOpen = false);
    }
  }

  /// The shared 3-state chip look (UI-R10 #1): rest = translucent gray
  /// (the cells read through), hover = solid white, operating = accent.
  ({Color background, Color border, Color ink}) _chipColors(
    ColorScheme colorScheme, {
    required bool hovered,
    required bool operating,
  }) {
    if (operating) {
      return (
        background: colorScheme.primary.withValues(alpha: 0.45),
        border: colorScheme.primary,
        ink: colorScheme.onSurface,
      );
    }
    if (hovered) {
      return (
        background: Colors.white,
        border: colorScheme.outline,
        ink: Colors.black87,
      );
    }
    return (
      background: colorScheme.surfaceContainerHigh.withValues(alpha: 0.45),
      border: colorScheme.outlineVariant.withValues(alpha: 0.6),
      ink: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
    );
  }

  Widget _addChip(ColorScheme colorScheme) {
    final horizontal = widget.axis == Axis.horizontal;
    final colors = _chipColors(
      colorScheme,
      hovered: _addHovered,
      operating: _dragging,
    );
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      opaque: false,
      onEnter: (_) => setState(() => _addHovered = true),
      onExit: (_) => setState(() => _addHovered = false),
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
            color: colors.background,
            border: Border.all(color: colors.border),
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
          child: Icon(Icons.add, size: 10, color: colors.ink),
        ),
      ),
    );
  }

  Widget _propertyTag(ColorScheme colorScheme) {
    final label = switch (widget.mode) {
      TimelineRunEdgeMode.hold => 'H',
      TimelineRunEdgeMode.repeat => 'R',
      null => 'N',
    };
    final colors = _chipColors(
      colorScheme,
      hovered: _tagHovered,
      operating: _menuOpen,
    );
    return Builder(
      builder: (anchorContext) => MouseRegion(
        cursor: SystemMouseCursors.click,
        opaque: false,
        onEnter: (_) => setState(() => _tagHovered = true),
        onExit: (_) => setState(() => _tagHovered = false),
        // The flyout opens on POINTER DOWN (UI-R10 #2): a tap-up (or an
        // arena-delayed tap) reads as lag next to the pointer-down cell
        // select the grid trained users on.
        child: Listener(
          key: ValueKey<String>(
            '${widget.keyPrefix}-run-edge-tag-${widget.layerId}-'
            '${widget.anchorValue}-${widget.side.name}',
          ),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _openModeFlyout(anchorContext),
          child: Container(
            margin: const EdgeInsets.all(1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.background,
              border: Border.all(color: colors.border),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8,
                height: 1,
                fontWeight: FontWeight.w700,
                color: colors.ink,
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

    // Block-outward order: end = [+] then tag; start = tag then [+]. The
    // tag is ALWAYS visible (#1); slot keys keep the [+] ELEMENT alive
    // across slot shifts so a mid-pan rebuild never remounts it (R12-③
    // one layer up).
    final slots = <Widget>[
      if (widget.showAdd)
        SizedBox(
          key: const ValueKey<String>('run-edge-slot-add'),
          width: horizontal ? timelineRunHandleExtent : null,
          height: horizontal ? null : timelineRunHandleExtent,
          child: _addChip(colorScheme),
        ),
      SizedBox(
        key: const ValueKey<String>('run-edge-slot-tag'),
        width: horizontal ? timelineRunHandleExtent : null,
        height: horizontal ? null : timelineRunHandleExtent,
        child: _propertyTag(colorScheme),
      ),
    ];
    final children = _atEnd ? slots : slots.reversed.toList();

    final cluster = Align(
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
