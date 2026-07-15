import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../theme/app_theme.dart' show instantMenuAnimation;
import 'layer_label_controls.dart' show LayerSectionBandCell;
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';

/// The label cell of one property lane: an AE-style property name, the
/// keyframe navigator (◀ previous key · ◆ toggle key at the playhead · ▶
/// next key) and the property's value at the playhead — tappable to type a
/// new value (which keys it, AE-style) or draggable to scrub it.
///
/// Axis rule: one widget serves both orientations. Horizontal = a rail row
/// under the layer's controls row (the timeline); vertical = a column
/// header cell beside the layer's header (the X-sheet), stacking the same
/// controls vertically.
class TimelineLaneControlsRow extends StatefulWidget {
  const TimelineLaneControlsRow({
    super.key,
    required this.layer,
    required this.lane,
    required this.metrics,
    this.currentFrameIndex = 0,
    this.onSelectFrame,
    this.laneEdit,
    this.onToggleLaneGroup,
    this.axis = Axis.horizontal,
    this.keyPrefix = 'timeline',
    this.width,
    this.height,
    this.leadingInset = 0,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final TimelineGridMetrics metrics;
  final int currentFrameIndex;

  /// Extra leading indent (horizontal axis only): the timeline rail's
  /// inline section-tag slot (UI-R5) so lane labels stay aligned with
  /// their layer row's content.
  final double leadingInset;
  final ValueChanged<int>? onSelectFrame;
  final PropertyLaneEditCallbacks? laneEdit;

  /// Group headers: tapping the header twirls its member lanes open/closed
  /// (AE group collapse); null leaves the header inert.
  final void Function(Layer layer, PropertyLaneRow lane)? onToggleLaneGroup;

  /// The owning grid's frame-axis direction (drives only the cell's
  /// composition; every control behaves identically).
  final Axis axis;

  /// Key namespace ('timeline' | 'xsheet') so tests address one
  /// orientation.
  final String keyPrefix;

  /// Explicit cell size; defaults to the horizontal rail-row geometry.
  final double? width;
  final double? height;

  @override
  State<TimelineLaneControlsRow> createState() =>
      _TimelineLaneControlsRowState();
}

class _TimelineLaneControlsRowState extends State<TimelineLaneControlsRow> {
  bool _editingValue = false;
  late final TextEditingController _valueController = TextEditingController();

  Layer get layer => widget.layer;
  PropertyLaneRow get lane => widget.lane;
  String get _keyPrefix => widget.keyPrefix;

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

  Widget _navigator(ColorScheme colorScheme) {
    final keyedNow = lane.keyedFrames.contains(widget.currentFrameIndex);
    final previousKey = _previousKeyFrame;
    final nextKey = _nextKeyFrame;
    final onSelectFrame = widget.onSelectFrame;
    final laneEdit = widget.laneEdit;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _NavigatorButton(
          buttonKey: ValueKey<String>(
            '$_keyPrefix-lane-prev-key-${layer.id}-${lane.laneId}',
          ),
          icon: Icons.chevron_left,
          enabled: previousKey != null && onSelectFrame != null,
          onTap: () => onSelectFrame!(previousKey!),
        ),
        _NavigatorButton(
          buttonKey: ValueKey<String>(
            '$_keyPrefix-lane-key-toggle-${layer.id}-${lane.laneId}',
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
            '$_keyPrefix-lane-next-key-${layer.id}-${lane.laneId}',
          ),
          icon: Icons.chevron_right,
          enabled: nextKey != null && onSelectFrame != null,
          onTap: () => onSelectFrame!(nextKey!),
        ),
      ],
    );
  }

  /// AE's blue value column: the property's value at the playhead; tap to
  /// type (Enter commits and keys the value there), drag to scrub.
  Widget _valueCell(ColorScheme colorScheme, String valueLabel) {
    final laneEdit = widget.laneEdit;
    if (_editingValue) {
      return SizedBox(
        height: 20,
        child: TextField(
          key: ValueKey<String>(
            '$_keyPrefix-lane-value-field-${layer.id}-${lane.laneId}',
          ),
          controller: _valueController,
          autofocus: true,
          style: const TextStyle(fontSize: 11),
          textAlign: widget.axis == Axis.horizontal
              ? TextAlign.right
              : TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _commitValueEdit(),
          onTapOutside: (_) {
            // Tap-away cancels (Enter commits, AE-style).
            setState(() => _editingValue = false);
          },
        ),
      );
    }

    // Tap types a value; a drag SCRUBS it (AE-style — horizontal for the
    // first component, vertical for Position's y; the drag-axis mapping is
    // the lane's, identical in both orientations) and commits once on
    // release.
    return GestureDetector(
      // .down: positions measure from the pointer-down origin, so the
      // recognizer's slop never eats into the scrubbed value.
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: laneEdit?.onSetValue == null
          ? null
          : (details) => _startScrub(details.globalPosition, valueLabel),
      onPanUpdate: laneEdit?.onSetValue == null
          ? null
          : (details) => _updateScrub(details.globalPosition),
      onPanEnd: laneEdit?.onSetValue == null ? null : (_) => _endScrub(),
      onPanCancel: laneEdit?.onSetValue == null ? null : _cancelScrub,
      child: MouseRegion(
        cursor: laneEdit?.onSetValue == null
            ? MouseCursor.defer
            : SystemMouseCursors.resizeLeftRight,
        child: InkWell(
          key: ValueKey<String>(
            '$_keyPrefix-lane-value-${layer.id}-${lane.laneId}',
          ),
          onTap: laneEdit?.onSetValue == null
              ? null
              : () => _startValueEdit(valueLabel),
          child: Text(
            _scrubPreview ?? valueLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colorScheme.primary),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (lane.isGroupHeader) {
      // AE group header ('Transform'): a structural label one indent LEFT
      // of its member lanes, no navigator/value. Tapping the header
      // twirls the group's member lanes open/closed (default collapsed);
      // the chevron mirrors the state.
      final onToggleGroup = widget.onToggleLaneGroup;
      return Container(
        key: ValueKey<String>(
          '$_keyPrefix-lane-label-${layer.id}-${lane.laneId}',
        ),
        width:
            widget.width ??
            (widget.metrics.layerControlsWidth -
                widget.metrics.sectionLabelGutterWidth),
        height: widget.height ?? widget.metrics.layerRowHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
        ),
        child: InkWell(
          key: ValueKey<String>(
            '$_keyPrefix-lane-group-toggle-${layer.id}-${lane.laneId}',
          ),
          onTap: onToggleGroup == null
              ? null
              : () => onToggleGroup(layer, lane),
          child: Padding(
            padding: widget.axis == Axis.horizontal
                ? const EdgeInsets.only(right: 8)
                : const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: widget.axis == Axis.horizontal
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                if (widget.axis == Axis.horizontal &&
                    widget.leadingInset > 0) ...[
                  // The rows' section band continues through lane rows
                  // (UI-R6 #5).
                  const LayerSectionBandCell(),
                  const SizedBox(width: 10),
                ],
                Icon(
                  lane.groupExpanded
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  size: 16,
                ),
                Flexible(
                  child: Text(
                    lane.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final valueLabel = lane.valueLabel?.call(widget.currentFrameIndex);
    final label = Text(
      lane.label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
    );

    final Widget content;
    if (widget.axis == Axis.horizontal) {
      content = Row(
        children: [
          if (lane.showsKeyNavigator) ...[
            _navigator(colorScheme),
            const SizedBox(width: 6),
          ],
          Flexible(child: label),
          const SizedBox(width: 4),
          if (valueLabel != null)
            Expanded(
              child: _editingValue
                  ? _valueCell(colorScheme, valueLabel)
                  : Align(
                      alignment: Alignment.centerRight,
                      child: _valueCell(colorScheme, valueLabel),
                    ),
            )
          else
            const Spacer(),
        ],
      );
    } else {
      // X-sheet lane column header: the same controls stacked vertically.
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          label,
          if (lane.showsKeyNavigator) ...[
            const SizedBox(height: 4),
            _navigator(colorScheme),
          ],
          if (valueLabel != null) ...[
            const SizedBox(height: 4),
            _valueCell(colorScheme, valueLabel),
          ],
        ],
      );
    }

    return Container(
      key: ValueKey<String>(
        '$_keyPrefix-lane-label-${layer.id}-${lane.laneId}',
      ),
      // Horizontal: the section bracket occupies the leading gutter beside
      // the rail, and lane labels indent past the twirl-down chevron slot.
      width:
          widget.width ??
          (widget.metrics.layerControlsWidth -
              widget.metrics.sectionLabelGutterWidth),
      height: widget.height ?? widget.metrics.layerRowHeight,
      padding: widget.axis == Axis.horizontal
          ? (widget.leadingInset > 0
                ? const EdgeInsets.only(right: 8)
                : const EdgeInsets.only(left: 24, right: 8))
          : const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      alignment: widget.axis == Axis.horizontal
          ? Alignment.centerLeft
          : Alignment.center,
      child: widget.axis == Axis.horizontal && widget.leadingInset > 0
          ? Row(
              children: [
                // The rows' section band continues through lane rows
                // (UI-R6 #5); the 24px lane indent follows it.
                const LayerSectionBandCell(),
                const SizedBox(width: 24),
                Expanded(child: content),
              ],
            )
          : content,
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

/// The frame-axis band of one property lane: a quiet strip with key markers
/// at keyed frames (AE-style: linear keys are diamonds, HOLD keys squares).
/// Markers drag along the frame axis to move their key (snapping per frame)
/// and open the hold/delete menu on right-click or long-press.
///
/// Horizontal = a row under the layer's frame cells (the timeline);
/// vertical = a column beside the layer's frame cells (the X-sheet).
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
    this.axis = Axis.horizontal,
    this.keyPrefix = 'timeline',
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final PropertyLaneEditCallbacks? laneEdit;

  /// Frame-axis direction; the marker/menu behavior is shared, only the
  /// band's composition transposes.
  final Axis axis;

  /// Key namespace ('timeline' | 'xsheet').
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cellExtent = metrics.frameCellWidth;
    // Cross-axis extent: rail-row height in the timeline, column width in
    // the X-sheet (the transposed metrics carry both as layerRowHeight).
    final crossExtent = metrics.layerRowHeight;
    final visibleExtent =
        (frameEndIndexExclusive - frameStartIndex) * cellExtent;
    final markerSize = (crossExtent * 0.32).clamp(6.0, 11.0).toDouble();
    final hitSize = (markerSize + 8).clamp(14.0, crossExtent).toDouble();
    final horizontal = axis == Axis.horizontal;

    final band = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        // The divider faces the NEXT lane: below in the timeline, to the
        // right in the X-sheet.
        border: horizontal
            ? Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              )
            : Border(
                right: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 0.5,
                ),
              ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final frame in lane.keyedFrames)
            if (frame >= frameStartIndex && frame < frameEndIndexExclusive)
              Positioned(
                left: horizontal
                    ? (frame - frameStartIndex) * cellExtent +
                          cellExtent / 2 -
                          hitSize / 2
                    : crossExtent / 2 - hitSize / 2,
                top: horizontal
                    ? crossExtent / 2 - hitSize / 2
                    : (frame - frameStartIndex) * cellExtent +
                          cellExtent / 2 -
                          hitSize / 2,
                width: hitSize,
                height: hitSize,
                child: _LaneKeyMarker(
                  key: ValueKey<String>(
                    '$keyPrefix-lane-key-${layer.id}-${lane.laneId}-$frame',
                  ),
                  layer: layer,
                  lane: lane,
                  frame: frame,
                  hold: lane.holdOutFrames.contains(frame),
                  markerSize: markerSize,
                  frameCellExtent: cellExtent,
                  axis: axis,
                  laneEdit: laneEdit,
                ),
              ),
        ],
      ),
    );

    if (horizontal) {
      return Row(
        key: ValueKey<String>('$keyPrefix-lane-row-${layer.id}-${lane.laneId}'),
        children: [
          SizedBox(width: leadingFrameSpacerWidth, height: crossExtent),
          SizedBox(width: visibleExtent, height: crossExtent, child: band),
          SizedBox(width: trailingFrameSpacerWidth, height: crossExtent),
        ],
      );
    }
    return Column(
      key: ValueKey<String>('$keyPrefix-lane-row-${layer.id}-${lane.laneId}'),
      children: [
        SizedBox(width: crossExtent, height: leadingFrameSpacerWidth),
        SizedBox(width: crossExtent, height: visibleExtent, child: band),
        SizedBox(width: crossExtent, height: trailingFrameSpacerWidth),
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
    required this.frameCellExtent,
    required this.axis,
    required this.laneEdit,
  });

  final Layer layer;
  final PropertyLaneRow lane;
  final int frame;
  final bool hold;
  final double markerSize;
  final double frameCellExtent;
  final Axis axis;
  final PropertyLaneEditCallbacks? laneEdit;

  @override
  State<_LaneKeyMarker> createState() => _LaneKeyMarkerState();
}

class _LaneKeyMarkerState extends State<_LaneKeyMarker> {
  double _dragDelta = 0;
  bool _dragging = false;

  int get _frameDelta {
    final delta = (_dragDelta / widget.frameCellExtent).round();
    // Keys never move before frame 0.
    return delta.clamp(-widget.frame, 1 << 20);
  }

  void _startDrag() => setState(() => _dragging = true);

  void _updateDrag(DragUpdateDetails details) {
    setState(() {
      _dragDelta += widget.axis == Axis.horizontal
          ? details.delta.dx
          : details.delta.dy;
    });
  }

  void _endDrag() {
    final delta = _frameDelta;
    setState(() {
      _dragging = false;
      _dragDelta = 0;
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

  void _cancelDrag() {
    setState(() {
      _dragging = false;
      _dragDelta = 0;
    });
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
      popUpAnimationStyle: instantMenuAnimation,
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
    final horizontal = widget.axis == Axis.horizontal;
    final editable = widget.laneEdit != null;
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
      // The key drags along the frame axis of the owning grid.
      onHorizontalDragStart: editable && horizontal
          ? (_) => _startDrag()
          : null,
      onHorizontalDragUpdate: editable && horizontal ? _updateDrag : null,
      onHorizontalDragEnd: editable && horizontal ? (_) => _endDrag() : null,
      onHorizontalDragCancel: editable && horizontal ? _cancelDrag : null,
      onVerticalDragStart: editable && !horizontal ? (_) => _startDrag() : null,
      onVerticalDragUpdate: editable && !horizontal ? _updateDrag : null,
      onVerticalDragEnd: editable && !horizontal ? (_) => _endDrag() : null,
      onVerticalDragCancel: editable && !horizontal ? _cancelDrag : null,
      onSecondaryTapUp: (details) => _showKeyMenu(details.globalPosition),
      onLongPressStart: (details) => _showKeyMenu(details.globalPosition),
      child: Transform.translate(
        // Snap the ghost per frame while dragging (AE feel).
        offset: horizontal
            ? Offset(_dragging ? _frameDelta * widget.frameCellExtent : 0, 0)
            : Offset(0, _dragging ? _frameDelta * widget.frameCellExtent : 0),
        child: Center(child: marker),
      ),
    );
  }
}
