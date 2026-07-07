import 'package:flutter/material.dart';

import '../../models/layer.dart';
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';

/// The label-rail row of one property lane: an indented AE-style property
/// name plus the keyframe navigator (◀ previous key · ◆ toggle key at the
/// playhead · ▶ next key).
class TimelineLaneControlsRow extends StatelessWidget {
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

  int? get _previousKeyFrame {
    int? best;
    for (final frame in lane.keyedFrames) {
      if (frame < currentFrameIndex && (best == null || frame > best)) {
        best = frame;
      }
    }
    return best;
  }

  int? get _nextKeyFrame {
    int? best;
    for (final frame in lane.keyedFrames) {
      if (frame > currentFrameIndex && (best == null || frame < best)) {
        best = frame;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyedNow = lane.keyedFrames.contains(currentFrameIndex);
    final previousKey = _previousKeyFrame;
    final nextKey = _nextKeyFrame;

    return Container(
      key: ValueKey<String>('timeline-lane-label-${layer.id}-${lane.laneId}'),
      width: metrics.layerControlsWidth,
      height: metrics.layerRowHeight,
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
                laneEdit!.onToggleKeyAt(layer, lane, currentFrameIndex),
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
