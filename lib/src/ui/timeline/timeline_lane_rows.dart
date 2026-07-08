import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';

/// The label-rail row of one property lane: an indented AE-style property
/// name, the keyframe navigator (◀ previous key · ◆ toggle key at the
/// playhead · ▶ next key) and the property's value at the playhead —
/// tappable to type a new value (which keys it, AE-style).
class TimelineLaneControlsRow extends StatefulWidget {
  const TimelineLaneControlsRow({
    super.key,
    required this.layer,
    required this.lane,
    required this.metrics,
    this.currentFrameIndex = 0,
    this.onSelectFrame,
    this.laneEdit,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final TimelineGridMetrics metrics;
  final int currentFrameIndex;
  final ValueChanged<int>? onSelectFrame;
  final PropertyLaneEditCallbacks? laneEdit;

  @override
  State<TimelineLaneControlsRow> createState() =>
      _TimelineLaneControlsRowState();
}

class _TimelineLaneControlsRowState extends State<TimelineLaneControlsRow> {
  bool _editingValue = false;
  late final TextEditingController _valueController = TextEditingController();

  Layer get layer => widget.layer;
  PropertyLaneRow get lane => widget.lane;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  int? get _previousKeyFrame {
    int? best;
    for (final frame in lane.keyedFrames) {
      if (frame < widget.currentFrameIndex && (best == null || frame > best)) {
        best = frame;
      }
    }
    return best;
  }

  int? get _nextKeyFrame {
    int? best;
    for (final frame in lane.keyedFrames) {
      if (frame > widget.currentFrameIndex && (best == null || frame < best)) {
        best = frame;
      }
    }
    return best;
  }

  void _startValueEdit(String currentValue) {
    _valueController.text = currentValue;
    setState(() => _editingValue = true);
  }

  // AE-style value scrubbing: the drag's TOTAL delta (positions against
  // the pointer-down origin — slop never eats into the value) maps the
  // label captured at the start; a live preview repaints only this row and
  // the release commits ONCE through the normal onSetValue path — one undo.
  String? _scrubBaseLabel;
  Offset? _scrubOrigin;
  String? _scrubPreview;

  void _startScrub(Offset globalPosition, String currentLabel) {
    _scrubBaseLabel = currentLabel;
    _scrubOrigin = globalPosition;
  }

  void _updateScrub(Offset globalPosition) {
    final base = _scrubBaseLabel;
    final origin = _scrubOrigin;
    final scrub = lane.scrubValue;
    if (base == null || origin == null || scrub == null) {
      return;
    }
    final preview = scrub(base, globalPosition - origin);
    if (preview != null) {
      setState(() => _scrubPreview = preview);
    }
  }

  void _endScrub() {
    final preview = _scrubPreview;
    setState(() {
      _scrubPreview = null;
      _scrubBaseLabel = null;
      _scrubOrigin = null;
    });
    if (preview != null) {
      widget.laneEdit?.onSetValue?.call(
        layer,
        lane,
        widget.currentFrameIndex,
        preview,
      );
    }
  }

  void _cancelScrub() {
    setState(() {
      _scrubPreview = null;
      _scrubBaseLabel = null;
      _scrubOrigin = null;
    });
  }

  void _commitValueEdit() {
    final input = _valueController.text;
    setState(() => _editingValue = false);
    widget.laneEdit?.onSetValue?.call(
      layer,
      lane,
      widget.currentFrameIndex,
      input,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyedNow = lane.keyedFrames.contains(widget.currentFrameIndex);
    final previousKey = _previousKeyFrame;
    final nextKey = _nextKeyFrame;
    final onSelectFrame = widget.onSelectFrame;
    final laneEdit = widget.laneEdit;
    final valueLabel = lane.valueLabel?.call(widget.currentFrameIndex);

    return Container(
      key: ValueKey<String>('timeline-lane-label-${layer.id}-${lane.laneId}'),
      // The section bracket occupies the leading gutter beside the rail.
      width:
          widget.metrics.layerControlsWidth -
          widget.metrics.sectionLabelGutterWidth,
      height: widget.metrics.layerRowHeight,
      // Indent past the twirl-down chevron slot so lane labels stay aligned
      // under their layer's controls.
      padding: const EdgeInsets.only(left: 24, right: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          // AE keyframe navigator.
          _NavigatorButton(
            buttonKey: ValueKey<String>(
              'timeline-lane-prev-key-${layer.id}-${lane.laneId}',
            ),
            icon: Icons.chevron_left,
            enabled: previousKey != null && onSelectFrame != null,
            onTap: () => onSelectFrame!(previousKey!),
          ),
          _NavigatorButton(
            buttonKey: ValueKey<String>(
              'timeline-lane-key-toggle-${layer.id}-${lane.laneId}',
            ),
            enabled: laneEdit != null,
            onTap: () =>
                laneEdit!.onToggleKeyAt(layer, lane, widget.currentFrameIndex),
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: keyedNow ? colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: keyedNow
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          _NavigatorButton(
            buttonKey: ValueKey<String>(
              'timeline-lane-next-key-${layer.id}-${lane.laneId}',
            ),
            icon: Icons.chevron_right,
            enabled: nextKey != null && onSelectFrame != null,
            onTap: () => onSelectFrame!(nextKey!),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              lane.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // AE's blue value column: the property's value at the playhead;
          // tap to type (Enter commits and keys the value there).
          if (valueLabel != null)
            Expanded(
              child: _editingValue
                  ? SizedBox(
                      height: 20,
                      child: TextField(
                        key: ValueKey<String>(
                          'timeline-lane-value-field-${layer.id}-${lane.laneId}',
                        ),
                        controller: _valueController,
                        autofocus: true,
                        style: const TextStyle(fontSize: 11),
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _commitValueEdit(),
                        onTapOutside: (_) {
                          // Tap-away cancels (Enter commits, AE-style).
                          setState(() => _editingValue = false);
                        },
                      ),
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      // Tap types a value; a drag SCRUBS it (AE-style —
                      // horizontal for the first component, vertical for
                      // Position's y) and commits once on release.
                      child: GestureDetector(
                        // .down: positions measure from the pointer-down
                        // origin, so the recognizer's slop never eats into
                        // the scrubbed value.
                        dragStartBehavior: DragStartBehavior.down,
                        onPanStart: laneEdit?.onSetValue == null
                            ? null
                            : (details) => _startScrub(
                                details.globalPosition,
                                valueLabel,
                              ),
                        onPanUpdate: laneEdit?.onSetValue == null
                            ? null
                            : (details) => _updateScrub(details.globalPosition),
                        onPanEnd: laneEdit?.onSetValue == null
                            ? null
                            : (_) => _endScrub(),
                        onPanCancel: laneEdit?.onSetValue == null
                            ? null
                            : _cancelScrub,
                        child: MouseRegion(
                          cursor: laneEdit?.onSetValue == null
                              ? MouseCursor.defer
                              : SystemMouseCursors.resizeLeftRight,
                          child: InkWell(
                            key: ValueKey<String>(
                              'timeline-lane-value-${layer.id}-${lane.laneId}',
                            ),
                            onTap: laneEdit?.onSetValue == null
                                ? null
                                : () => _startValueEdit(valueLabel),
                            child: Text(
                              _scrubPreview ?? valueLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _NavigatorButton extends StatelessWidget {
  const _NavigatorButton({
    required this.buttonKey,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.child,
  });

  final Key buttonKey;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      key: buttonKey,
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: 16,
        height: 20,
        child: Center(
          child:
              child ??
              Icon(
                icon,
                size: 14,
                color: enabled
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
        ),
      ),
    );
  }
}

/// The frame-axis row of one property lane: a quiet band with key markers
/// at keyed frames (AE-style: linear keys are diamonds, HOLD keys squares).
/// Markers drag horizontally to move their key (snapping per frame) and
/// open the hold/delete menu on right-click or long-press.
class TimelineLaneFrameRow extends StatelessWidget {
  const TimelineLaneFrameRow({
    super.key,
    required this.layer,
    required this.lane,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.metrics,
    this.laneEdit,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final PropertyLaneEditCallbacks? laneEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cellWidth = metrics.frameCellWidth;
    final rowHeight = metrics.layerRowHeight;
    final visibleWidth = (frameEndIndexExclusive - frameStartIndex) * cellWidth;
    final markerSize = (rowHeight * 0.32).clamp(6.0, 11.0).toDouble();
    final hitSize = (markerSize + 8).clamp(14.0, rowHeight).toDouble();

    return Row(
      key: ValueKey<String>('timeline-lane-row-${layer.id}-${lane.laneId}'),
      children: [
        SizedBox(width: leadingFrameSpacerWidth, height: rowHeight),
        SizedBox(
          width: visibleWidth,
          height: rowHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (final frame in lane.keyedFrames)
                  if (frame >= frameStartIndex &&
                      frame < frameEndIndexExclusive)
                    Positioned(
                      left:
                          (frame - frameStartIndex) * cellWidth +
                          cellWidth / 2 -
                          hitSize / 2,
                      top: rowHeight / 2 - hitSize / 2,
                      width: hitSize,
                      height: hitSize,
                      child: _LaneKeyMarker(
                        key: ValueKey<String>(
                          'timeline-lane-key-${layer.id}-${lane.laneId}-$frame',
                        ),
                        layer: layer,
                        lane: lane,
                        frame: frame,
                        hold: lane.holdOutFrames.contains(frame),
                        markerSize: markerSize,
                        cellWidth: cellWidth,
                        laneEdit: laneEdit,
                      ),
                    ),
              ],
            ),
          ),
        ),
        SizedBox(width: trailingFrameSpacerWidth, height: rowHeight),
      ],
    );
  }
}

/// One draggable key marker.
class _LaneKeyMarker extends StatefulWidget {
  const _LaneKeyMarker({
    super.key,
    required this.layer,
    required this.lane,
    required this.frame,
    required this.hold,
    required this.markerSize,
    required this.cellWidth,
    required this.laneEdit,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final int frame;
  final bool hold;
  final double markerSize;
  final double cellWidth;
  final PropertyLaneEditCallbacks? laneEdit;

  @override
  State<_LaneKeyMarker> createState() => _LaneKeyMarkerState();
}

class _LaneKeyMarkerState extends State<_LaneKeyMarker> {
  double _dragDx = 0;
  bool _dragging = false;

  int get _frameDelta {
    final delta = (_dragDx / widget.cellWidth).round();
    // Keys never move before frame 0.
    return delta.clamp(-widget.frame, 1 << 20);
  }

  void _endDrag() {
    final delta = _frameDelta;
    setState(() {
      _dragging = false;
      _dragDx = 0;
    });
    if (delta != 0) {
      widget.laneEdit?.onMoveKey(
        widget.layer,
        widget.lane,
        widget.frame,
        widget.frame + delta,
      );
    }
  }

  Future<void> _showKeyMenu(Offset globalPosition) async {
    final laneEdit = widget.laneEdit;
    if (laneEdit == null) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          key: const ValueKey<String>('lane-key-menu-hold'),
          value: 'hold',
          child: Text(widget.hold ? 'Linear Keyframe' : 'Toggle Hold Keyframe'),
        ),
        const PopupMenuItem(
          key: ValueKey<String>('lane-key-menu-delete'),
          value: 'delete',
          child: Text('Delete Keyframe'),
        ),
      ],
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case 'hold':
        laneEdit.onToggleHold(widget.layer, widget.lane, widget.frame);
      case 'delete':
        laneEdit.onRemoveKey(widget.layer, widget.lane, widget.frame);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shape = Container(
      width: widget.markerSize,
      height: widget.markerSize,
      decoration: BoxDecoration(
        color: _dragging
            ? colorScheme.primary.withValues(alpha: 0.6)
            : colorScheme.primary,
        border: Border.all(color: colorScheme.surface, width: 1),
      ),
    );
    // AE convention: linear keys read as diamonds, hold keys as squares.
    final marker = widget.hold
        ? shape
        : Transform.rotate(angle: 0.785398, child: shape);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: widget.laneEdit == null
          ? null
          : (_) => setState(() => _dragging = true),
      onHorizontalDragUpdate: widget.laneEdit == null
          ? null
          : (details) => setState(() => _dragDx += details.delta.dx),
      onHorizontalDragEnd: widget.laneEdit == null ? null : (_) => _endDrag(),
      onHorizontalDragCancel: widget.laneEdit == null
          ? null
          : () => setState(() {
              _dragging = false;
              _dragDx = 0;
            }),
      onSecondaryTapUp: (details) => _showKeyMenu(details.globalPosition),
      onLongPressStart: (details) => _showKeyMenu(details.globalPosition),
      child: Transform.translate(
        // Snap the ghost per frame while dragging (AE feel).
        offset: Offset(_dragging ? _frameDelta * widget.cellWidth : 0, 0),
        child: Center(child: marker),
      ),
    );
  }
}
