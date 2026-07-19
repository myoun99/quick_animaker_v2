import 'package:flutter/gestures.dart'
    show DragStartBehavior, TapGestureRecognizer;
import 'package:flutter/material.dart';

import '../input/app_input_settings.dart' show AppInput;
import '../input/eager_pan_gesture_recognizer.dart';

import '../../models/frame_id.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/timeline_repeat.dart';
import '../theme/app_theme.dart' show AppColors;
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
    this.canScopeToSelection,
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

  /// The tag flyout picked a mode for the run edge; null clears it
  /// (None). [scopeToSelection] carries the flyout's EXPLICIT choice
  /// (UI-R19 #2): "Repeat" = the whole run even while a selection is
  /// live; "Repeat selection" = the selection scopes the pattern.
  final void Function(
    LayerId layerId,
    int blockStartIndex,
    TimelineRunEdgeSide side,
    TimelineRunEdgeMode? mode, {
    bool scopeToSelection,
  })
  onEdgeModeSelected;

  /// Whether the LIVE frame-range selection can scope a repeat pattern
  /// on this edge — gates the flyout's "Repeat selection" entry. Null =
  /// the entry never shows (hosts without selection support).
  final bool Function(
    LayerId layerId,
    int blockStartIndex,
    TimelineRunEdgeSide side,
  )?
  canScopeToSelection;
}

/// Legacy main-axis extent constant (pre-UI-R11 fixed chips); the cluster
/// now scales with the zoom (half a frame cell, [_clusterMainExtent]).
const double timelineRunHandleExtent = 14;

double _clusterMainExtent(double frameCellExtent) =>
    (frameCellExtent / 2).clamp(7.0, 24.0);

/// The run-edge clusters hugging each glued run (UI-R11 #13): a slim
/// TWO-STACK of text glyphs — [+] over the N/H/R property letter — half a
/// frame cell wide (zoom-scaled), no chrome at all; rest = dim text,
/// hover = white text, operating = accent text.
///
/// Identity vs display (UI-R11 #1/#2): the clusters key and call back on
/// the COMMITTED [baseLayer] runs (stable across drags — R12-③), but
/// POSITION on the display [layer] (the drag-preview substitution), so
/// they ride block moves and [+] adds live.
///
/// Ghost runs themselves get no clusters (their timing is derived).
List<Widget> timelineRowRunEndHandles({
  required Layer layer,
  Layer? baseLayer,
  required int frameStartIndex,
  required int frameEndIndexExclusive,
  required double leadingFrameSpacerWidth,
  required double frameCellExtent,
  required double crossAxisExtent,
  required TimelineRunEditCallbacks callbacks,
  required Axis axis,
  String keyPrefix = 'timeline',
}) {
  final identity = baseLayer ?? layer;
  final handles = <Widget>[];
  final seenRunStarts = <int>{};

  double edgeX(int frameIndex) => frameVisibleX(
    frameIndex: frameIndex,
    frameStartIndex: frameStartIndex,
    frameCellWidth: frameCellExtent,
    leadingFrameSpacerWidth: leadingFrameSpacerWidth,
  );

  /// Lowest non-ghost display start carrying [frameId]; null when the
  /// block left this layer (e.g. a cross-layer move preview).
  int? displayStartOf(FrameId frameId) {
    for (final entry in layer.timeline.entries) {
      if (!entry.value.ghost && entry.value.frameId == frameId) {
        return entry.key;
      }
    }
    return null;
  }

  for (final key in identity.timeline.keys) {
    final entry = identity.timeline[key]!;
    if (!entry.isDrawing || entry.ghost) {
      continue;
    }
    final baseRun = gluedRunAt(identity, key);
    if (baseRun == null || !seenRunStarts.add(baseRun.startIndex)) {
      continue;
    }
    // Resolve the LIVE display run for positions/modes: previews shift
    // the anchor block, the glued run containing it is the visual unit.
    final displayAnchorStart = displayStartOf(baseRun.anchorFrameId);
    if (displayAnchorStart == null) {
      continue;
    }
    final run = gluedRunAt(layer, displayAnchorStart);
    if (run == null ||
        run.endIndexExclusive < frameStartIndex ||
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
      final anchorStart = displayStartOf(behavior.patternAnchorFrameId!);
      if (anchorStart == null ||
          anchorStart < run.startIndex ||
          anchorStart >= run.endIndexExclusive) {
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
      // The pattern span reads at a glance now (UI-R19 #2): a light wash
      // over the repeated cels plus a firm outline — in ACCENT 2 (UI-R22
      // #5), the program's secondary highlight.
      final outline = IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent2.withValues(alpha: 0.10),
            border: Border.all(
              color: AppColors.accent2.withValues(alpha: 0.85),
              width: 2,
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

    // END cluster on the display run edge.
    handles.add(
      _RunEdgeCluster(
        // Keys carry the BASE run's ANCHOR identity, never an index: a
        // preview shift would remount an index-keyed handle mid-gesture
        // (killing the pan and committing one frame) — R12-③.
        key: ValueKey<String>(
          '$keyPrefix-run-edge-end-${layer.id}-${baseRun.anchorFrameId.value}',
        ),
        keyPrefix: keyPrefix,
        side: TimelineRunEdgeSide.end,
        layerId: layer.id,
        blockStartIndex: baseRun.startIndex,
        anchorValue: baseRun.anchorFrameId.value,
        mode: endBehavior?.mode,
        hasPattern: endBehavior?.patternAnchorFrameId != null,
        edgeOffset: edgeX(run.endIndexExclusive),
        frameCellExtent: frameCellExtent,
        crossAxisExtent: crossAxisExtent,
        callbacks: callbacks,
        axis: axis,
      ),
    );

    // START cluster mirror.
    if (run.startIndex > 0) {
      handles.add(
        _RunEdgeCluster(
          key: ValueKey<String>(
            '$keyPrefix-run-edge-start-${layer.id}-'
            '${baseRun.anchorFrameId.value}',
          ),
          keyPrefix: keyPrefix,
          side: TimelineRunEdgeSide.start,
          layerId: layer.id,
          blockStartIndex: baseRun.startIndex,
          anchorValue: baseRun.anchorFrameId.value,
          mode: startBehavior?.mode,
          hasPattern: startBehavior?.patternAnchorFrameId != null,
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

/// One run edge's affordance cluster (UI-R11 #13): [+] stacked over the
/// property letter, text-only, half a frame cell wide.
class _RunEdgeCluster extends StatefulWidget {
  const _RunEdgeCluster({
    super.key,
    required this.keyPrefix,
    required this.side,
    required this.layerId,
    required this.blockStartIndex,
    required this.anchorValue,
    required this.mode,
    required this.hasPattern,
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
  /// way — the letter changes, never an accent (UI-R10 #1).
  final TimelineRunEdgeMode? mode;

  /// A selection-scoped repeat pattern is live on this edge (UI-R19 #2):
  /// the flyout's "Repeat selection" entry reads checked from it.
  final bool hasPattern;

  /// Main-axis offset of the display run edge.
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

  /// A plain tap adds exactly ONE cel beside the run (UI-R17 #4) — the
  /// drag flow with a fixed count of 1, committed immediately.
  void _tapAdd() {
    if (_dragging) {
      return;
    }
    final accepted = widget.callbacks.onAddBegin(
      widget.layerId,
      widget.blockStartIndex,
      atEnd: _atEnd,
    );
    if (!accepted) {
      return;
    }
    widget.callbacks.onAddUpdate(1);
    widget.callbacks.onAddEnd();
  }

  @override
  void dispose() {
    if (_dragging) {
      final callbacks = widget.callbacks;
      WidgetsBinding.instance.addPostFrameCallback((_) => callbacks.onAddEnd());
    }
    super.dispose();
  }

  Future<void> _openModeFlyout(BuildContext anchorContext) async {
    void pick(TimelineRunEdgeMode? mode, {bool scopeToSelection = false}) =>
        widget.callbacks.onEdgeModeSelected(
          widget.layerId,
          widget.blockStartIndex,
          widget.side,
          mode,
          scopeToSelection: scopeToSelection,
        );
    // Whether the LIVE selection can scope a pattern right now (UI-R19
    // #2): the explicit entry replaces the old silent capture — "Repeat"
    // now ALWAYS means the whole run.
    final selectionScopes =
        widget.callbacks.canScopeToSelection?.call(
          widget.layerId,
          widget.blockStartIndex,
          widget.side,
        ) ??
        false;
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
          checked:
              widget.mode == TimelineRunEdgeMode.repeat && !widget.hasPattern,
          onSelected: () => pick(TimelineRunEdgeMode.repeat),
        ),
        // Listed while a selection can scope it — or one already does
        // (the checked row doubles as the "this edge repeats a
        // SELECTION" status).
        if (selectionScopes || widget.hasPattern)
          PanelFlyoutItem(
            keyValue: 'run-edge-mode-repeat-selection',
            label: 'Repeat selection',
            checked:
                widget.mode == TimelineRunEdgeMode.repeat && widget.hasPattern,
            onSelected: () =>
                pick(TimelineRunEdgeMode.repeat, scopeToSelection: true),
          ),
      ],
    );
    if (mounted) {
      setState(() => _menuOpen = false);
    }
  }

  /// The 3-state TEXT color (UI-R11 #13: no chrome — the glyph carries
  /// every state): rest dim, hover white, operating accent.
  Color _glyphColor(
    ColorScheme colorScheme, {
    required bool hovered,
    required bool operating,
  }) {
    if (operating) {
      return colorScheme.primary;
    }
    if (hovered) {
      return Colors.white;
    }
    return colorScheme.onSurfaceVariant.withValues(alpha: 0.65);
  }

  double get _glyphSize => (widget.frameCellExtent * 0.5).clamp(7.0, 12.0);

  Widget _addGlyph(ColorScheme colorScheme) {
    final horizontal = widget.axis == Axis.horizontal;
    return MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      opaque: false,
      onEnter: (_) => setState(() => _addHovered = true),
      onExit: (_) => setState(() => _addHovered = false),
      child: RawGestureDetector(
        key: ValueKey<String>(
          '${widget.keyPrefix}-run-add-${_atEnd ? 'end' : 'start'}-'
          '${widget.layerId}-${widget.anchorValue}',
        ),
        behavior: HitTestBehavior.opaque,
        // Every pointer kind operates the handle (UI-R17 #6): stylus pens
        // report as TOUCH on some Windows/tablet drivers, so the old
        // mouse+stylus allowlist read as "pen dead" there. Touch joins
        // per the input policy (UI-R22 #6); EAGER slop (UI-R22F #2) so a
        // slow [+] drag never loses the arena to the scroll.
        gestures: <Type, GestureRecognizerFactory>{
          // Tap = add ONE cel (UI-R17 #4); a drag keeps the count-preview
          // flow.
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                () => TapGestureRecognizer(debugOwner: this),
                (recognizer) {
                  // PEN-12 #6: TAPS take every device — a clean finger
                  // tap clicks [+] even while touch panning belongs to
                  // the scroll (the arena hands a real drag to the
                  // scroll, so the two never fight).
                  // PEN-11: device gesture settings (RawGestureDetector
                  // does not inject them - kTouchSlop 18 vs device ~8).
                  recognizer.gestureSettings =
                      MediaQuery.maybeGestureSettingsOf(context);
                  recognizer.onTap = _tapAdd;
                },
              ),
          EagerPanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<EagerPanGestureRecognizer>(
                () => EagerPanGestureRecognizer(debugOwner: this),
                (recognizer) {
                  recognizer.supportedDevices = AppInput.timelineEditPanDevices;
                  // PEN-11: device gesture settings (RawGestureDetector
                  // does not inject them - kTouchSlop 18 vs device ~8).
                  recognizer.gestureSettings =
                      MediaQuery.maybeGestureSettingsOf(context);
                  recognizer.dragStartBehavior = DragStartBehavior.down;
                  recognizer.onStart = (_) => _startAdd();
                  recognizer.onUpdate = (details) => _updateAdd(details.delta);
                  recognizer.onEnd = (_) => _endAdd();
                  recognizer.onCancel = _cancelAdd;
                },
              ),
        },
        child: Center(
          child: Text(
            '+',
            style: TextStyle(
              fontSize: _glyphSize + 2,
              height: 1,
              fontWeight: FontWeight.w700,
              color: _glyphColor(
                colorScheme,
                hovered: _addHovered,
                operating: _dragging,
              ),
            ),
          ),
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
    return Builder(
      builder: (anchorContext) => MouseRegion(
        cursor: SystemMouseCursors.click,
        opaque: false,
        onEnter: (_) => setState(() => _tagHovered = true),
        onExit: (_) => setState(() => _tagHovered = false),
        // The flyout opens on POINTER DOWN (UI-R10 #2).
        child: Listener(
          key: ValueKey<String>(
            '${widget.keyPrefix}-run-edge-tag-${widget.layerId}-'
            '${widget.anchorValue}-${widget.side.name}',
          ),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _openModeFlyout(anchorContext),
          // PEN-12 #3: the press already opened the flyout — any drag
          // continuing from it must die HERE, not scroll the timeline
          // under the open menu (every device: a finger press on the
          // tag is the tag's, not the scroll's).
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              EagerPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    EagerPanGestureRecognizer
                  >(() => EagerPanGestureRecognizer(debugOwner: this), (
                    recognizer,
                  ) {
                    recognizer.gestureSettings =
                        MediaQuery.maybeGestureSettingsOf(context);
                    recognizer.onStart = (_) {};
                    recognizer.onUpdate = (_) {};
                    recognizer.onEnd = (_) {};
                    recognizer.onCancel = () {};
                  }),
            },
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _glyphSize,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: _glyphColor(
                    colorScheme,
                    hovered: _tagHovered,
                    operating: _menuOpen,
                  ),
                ),
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
    final mainExtent = _clusterMainExtent(widget.frameCellExtent);

    // [+] over the property letter (UI-R11 #13): the two slots split the
    // CROSS axis so the very next frame stays visible beside them. The
    // whole zone swallows pointer-downs (UI-R10 #12 — a near-miss must
    // not seek the playhead through the cells below).
    final cluster = Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {},
      child: horizontal
          ? Column(
              children: [
                Expanded(child: _addGlyph(colorScheme)),
                Expanded(child: _propertyTag(colorScheme)),
              ],
            )
          : Row(
              children: [
                Expanded(child: _addGlyph(colorScheme)),
                Expanded(child: _propertyTag(colorScheme)),
              ],
            ),
    );

    final mainStart = _atEnd
        ? widget.edgeOffset
        : widget.edgeOffset - mainExtent;

    if (horizontal) {
      return Positioned(
        left: mainStart,
        top: 0,
        width: mainExtent,
        height: widget.crossAxisExtent,
        child: cluster,
      );
    }
    return Positioned(
      top: mainStart,
      left: 0,
      height: mainExtent,
      width: widget.crossAxisExtent,
      child: cluster,
    );
  }
}
