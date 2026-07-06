import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../models/cut_id.dart';
import '../models/project.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import 'panels/panel_scrollbar.dart';
import 'storyboard_layer_policy.dart';
import 'storyboard_timeline_layout.dart';
import 'timeline/timeline_block.dart';
import 'timeline/timeline_playhead.dart' show timelinePlayheadColor;
import 'timeline/timeline_scale.dart';

/// Same-track cut reorder request: drop [draggedCutId] at [targetCutIndex]
/// of [targetTrackId]. (Moved here from the retired top-bar CutListBar.)
typedef CutReorderedCallback =
    void Function({
      required CutId draggedCutId,
      required TrackId targetTrackId,
      required int targetCutIndex,
    });

class StoryboardPanel extends StatefulWidget {
  const StoryboardPanel({
    super.key,
    required this.project,
    required this.activeCutId,
    required this.onCutSelected,
    this.onCutReordered,
    this.playheadGlobalFrame,
    this.onSeekGlobalFrame,
    this.onNewCut,
    this.onRenameActiveCut,
    this.onEditActiveCutNote,
    this.onResizeActiveCutCanvas,
    this.onDuplicateActiveCut,
    this.onMoveActiveCutLeft,
    this.onMoveActiveCutRight,
    this.onDeleteActiveCut,
  });

  static const TimelineScale _timelineScale = TimelineScale();
  static const double _trackLabelWidth = 56;
  static const double _trackLaneHeight = 64;
  static const double _trackRowBottomPadding = 4;
  static const double _rulerHeight = 22;
  static const double _timelineTrailingPadding = 12;

  final Project project;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;

  /// Dragging a cut block onto another block of the same track reorders the
  /// cuts (same semantics as the top-bar chips). Null disables dragging.
  final CutReorderedCallback? onCutReordered;

  /// Track-global frame the playhead line sits on (playback position while
  /// playing, the active cut's playhead otherwise). Null hides the line.
  final int? playheadGlobalFrame;

  /// Tapping or scrubbing the ruler reports the track-global frame under
  /// the pointer. Null makes the ruler display-only.
  final ValueChanged<int>? onSeekGlobalFrame;

  // Cut management actions (the storyboard owns cut lifecycle; these were
  // the temporary top-toolbar controls). All act on the active cut.
  final VoidCallback? onNewCut;
  final VoidCallback? onRenameActiveCut;
  final VoidCallback? onEditActiveCutNote;
  final VoidCallback? onResizeActiveCutCanvas;
  final VoidCallback? onDuplicateActiveCut;
  final VoidCallback? onMoveActiveCutLeft;
  final VoidCallback? onMoveActiveCutRight;
  final VoidCallback? onDeleteActiveCut;

  bool get _hasCutActions =>
      onNewCut != null ||
      onRenameActiveCut != null ||
      onEditActiveCutNote != null ||
      onResizeActiveCutCanvas != null ||
      onDuplicateActiveCut != null ||
      onMoveActiveCutLeft != null ||
      onMoveActiveCutRight != null ||
      onDeleteActiveCut != null;

  @override
  State<StoryboardPanel> createState() => _StoryboardPanelState();
}

class _StoryboardPanelState extends State<StoryboardPanel> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// The widest content edge across every track (blocks can outgrow their
  /// duration via the minimum block width) plus trailing padding — the
  /// ruler and playhead overlay both span it.
  double _timelineContentWidth(List<StoryboardTimelineLayoutEntry> entries) {
    var width = 0.0;
    for (final entry in entries) {
      final right =
          StoryboardPanel._timelineScale.leftForFrame(entry.startFrame) +
          StoryboardPanel._timelineScale.widthForDuration(entry.duration);
      if (right > width) {
        width = right;
      }
    }
    return width + StoryboardPanel._timelineTrailingPadding;
  }

  int _totalFrames(List<StoryboardTimelineLayoutEntry> entries) {
    var total = 0;
    for (final entry in entries) {
      if (entry.endFrame > total) {
        total = entry.endFrame;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final layoutEntries = buildStoryboardTimelineLayout(widget.project);
    final contentWidth = _timelineContentWidth(layoutEntries);
    final totalFrames = _totalFrames(layoutEntries);
    final playheadFrame = widget.playheadGlobalFrame;

    return DecoratedBox(
      key: const ValueKey<String>('storyboard-panel'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget._hasCutActions)
              _StoryboardCutActionsToolbar(panel: widget),
            Expanded(
              child: PanelScrollbar(
                controller: _verticalController,
                child: SingleChildScrollView(
                  key: const ValueKey<String>('storyboard-vertical-viewport'),
                  controller: _verticalController,
                  padding: const EdgeInsets.only(right: panelScrollbarGutter),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        key: const ValueKey<String>(
                          'storyboard-track-label-rail',
                        ),
                        width: StoryboardPanel._trackLabelWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Keeps the labels aligned with the track rows
                            // below the ruler strip.
                            const SizedBox(
                              height: StoryboardPanel._rulerHeight,
                            ),
                            for (
                              var index = 0;
                              index < widget.project.tracks.length;
                              index++
                            )
                              _StoryboardTrackLabel(
                                track: widget.project.tracks[index],
                                trackLabel: 'V${index + 1}',
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: PanelScrollbar(
                          controller: _horizontalController,
                          child: SingleChildScrollView(
                            key: const ValueKey<String>(
                              'storyboard-timeline-horizontal-viewport',
                            ),
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(
                              bottom: panelScrollbarGutter,
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  key: const ValueKey<String>(
                                    'storyboard-timeline-scroll-content',
                                  ),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _StoryboardRuler(
                                      width: contentWidth,
                                      totalFrames: totalFrames,
                                      timelineScale:
                                          StoryboardPanel._timelineScale,
                                      onSeekGlobalFrame:
                                          widget.onSeekGlobalFrame,
                                    ),
                                    for (
                                      var index = 0;
                                      index < widget.project.tracks.length;
                                      index++
                                    )
                                      _StoryboardTrackRow(
                                        track: widget.project.tracks[index],
                                        layoutEntries: layoutEntries
                                            .where(
                                              (entry) =>
                                                  entry.trackIndex == index,
                                            )
                                            .toList(growable: false),
                                        activeCutId: widget.activeCutId,
                                        onCutSelected: widget.onCutSelected,
                                        onCutReordered: widget.onCutReordered,
                                        timelineScale:
                                            StoryboardPanel._timelineScale,
                                      ),
                                  ],
                                ),
                                if (playheadFrame != null)
                                  Positioned(
                                    key: const ValueKey<String>(
                                      'storyboard-playhead',
                                    ),
                                    left:
                                        StoryboardPanel._timelineScale
                                            .leftForFrame(playheadFrame) -
                                        1,
                                    top: 0,
                                    bottom: 0,
                                    child: const IgnorePointer(
                                      child: SizedBox(
                                        width: 2,
                                        child: ColoredBox(
                                          color: timelinePlayheadColor,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The compact cut-management toolbar at the top of the storyboard: the
/// storyboard owns the cut lifecycle, so new/rename/note/canvas/duplicate/
/// move/delete live here (icon-only with tooltips, acting on the active
/// cut).
class _StoryboardCutActionsToolbar extends StatelessWidget {
  const _StoryboardCutActionsToolbar({required this.panel});

  final StoryboardPanel panel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        key: const ValueKey<String>('storyboard-cut-actions'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CutActionButton(
              key: const ValueKey<String>('new-cut-button'),
              tooltip: 'New Cut',
              icon: Icons.add,
              onPressed: panel.onNewCut,
            ),
            _CutActionButton(
              key: const ValueKey<String>('rename-cut-button'),
              tooltip: 'Rename Cut',
              icon: Icons.edit_outlined,
              onPressed: panel.onRenameActiveCut,
            ),
            _CutActionButton(
              key: const ValueKey<String>('edit-cut-note-button'),
              tooltip: 'Edit Cut Note',
              icon: Icons.note_alt_outlined,
              onPressed: panel.onEditActiveCutNote,
            ),
            _CutActionButton(
              key: const ValueKey<String>('resize-cut-canvas-button'),
              tooltip: 'Canvas Size',
              icon: Icons.aspect_ratio,
              onPressed: panel.onResizeActiveCutCanvas,
            ),
            _CutActionButton(
              key: const ValueKey<String>('duplicate-cut-button'),
              tooltip: 'Duplicate Cut',
              icon: Icons.content_copy,
              onPressed: panel.onDuplicateActiveCut,
            ),
            _CutActionButton(
              key: const ValueKey<String>('move-cut-left-button'),
              tooltip: 'Move Cut Left',
              icon: Icons.chevron_left,
              onPressed: panel.onMoveActiveCutLeft,
            ),
            _CutActionButton(
              key: const ValueKey<String>('move-cut-right-button'),
              tooltip: 'Move Cut Right',
              icon: Icons.chevron_right,
              onPressed: panel.onMoveActiveCutRight,
            ),
            _CutActionButton(
              key: const ValueKey<String>('delete-cut-button'),
              tooltip: 'Delete Cut',
              icon: Icons.delete_outline,
              onPressed: panel.onDeleteActiveCut,
            ),
          ],
        ),
      ),
    );
  }
}

class _CutActionButton extends StatelessWidget {
  const _CutActionButton({
    required super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The Premiere-style frame ruler across the top of the track area: frame
/// ticks and 1-based labels on the shared [TimelineScale], scrolling with
/// the blocks. Tapping or dragging seeks via [onSeekGlobalFrame].
class _StoryboardRuler extends StatelessWidget {
  const _StoryboardRuler({
    required this.width,
    required this.totalFrames,
    required this.timelineScale,
    required this.onSeekGlobalFrame,
  });

  final double width;
  final int totalFrames;
  final TimelineScale timelineScale;
  final ValueChanged<int>? onSeekGlobalFrame;

  void _seekAt(double dx) {
    final onSeek = onSeekGlobalFrame;
    if (onSeek == null || totalFrames <= 0) {
      return;
    }
    final frame = (dx / timelineScale.pixelsPerFrame).floor().clamp(
      0,
      totalFrames - 1,
    );
    onSeek(frame);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey<String>('storyboard-ruler'),
      behavior: HitTestBehavior.opaque,
      // .down reports the true pointer-down position, so a scrub seeks the
      // pressed frame first instead of the post-slop position (same fix as
      // the camera overlay handles).
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: (details) => _seekAt(details.localPosition.dx),
      // Scrubbing claims horizontal drags on the ruler strip only; the
      // track rows below still pan the panel.
      onHorizontalDragStart: (details) => _seekAt(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _seekAt(details.localPosition.dx),
      child: CustomPaint(
        size: Size(width, StoryboardPanel._rulerHeight),
        painter: _StoryboardRulerPainter(
          totalFrames: totalFrames,
          pixelsPerFrame: timelineScale.pixelsPerFrame,
          tickColor: colorScheme.onSurfaceVariant,
          labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _StoryboardRulerPainter extends CustomPainter {
  const _StoryboardRulerPainter({
    required this.totalFrames,
    required this.pixelsPerFrame,
    required this.tickColor,
    required this.labelStyle,
  });

  static const int _labelEveryFrames = 12;
  static const int _minorTickEveryFrames = 4;

  final int totalFrames;
  final double pixelsPerFrame;
  final Color tickColor;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = tickColor.withValues(alpha: 0.6)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      tickPaint,
    );

    for (var frame = 0; frame <= totalFrames; frame += _minorTickEveryFrames) {
      final x = frame * pixelsPerFrame;
      if (x > size.width) {
        break;
      }
      final isLabeled = frame % _labelEveryFrames == 0;
      canvas.drawLine(
        Offset(x, size.height - (isLabeled ? 10 : 5)),
        Offset(x, size.height - 1),
        tickPaint,
      );
      if (isLabeled) {
        final painter = TextPainter(
          text: TextSpan(text: '${frame + 1}', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(canvas, Offset(x + 2, 0));
      }
    }
  }

  @override
  bool shouldRepaint(_StoryboardRulerPainter oldDelegate) {
    return oldDelegate.totalFrames != totalFrames ||
        oldDelegate.pixelsPerFrame != pixelsPerFrame ||
        oldDelegate.tickColor != tickColor ||
        oldDelegate.labelStyle != labelStyle;
  }
}

class _StoryboardTrackLabel extends StatelessWidget {
  const _StoryboardTrackLabel({required this.track, required this.trackLabel});

  final Track track;
  final String trackLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: StoryboardPanel._trackRowBottomPadding,
      ),
      child: SizedBox(
        key: ValueKey<String>('storyboard-track-label-row-${track.id.value}'),
        width: StoryboardPanel._trackLabelWidth,
        height: StoryboardPanel._trackLaneHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            trackLabel,
            key: ValueKey<String>('storyboard-track-label-${track.id.value}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _StoryboardTrackRow extends StatelessWidget {
  const _StoryboardTrackRow({
    required this.track,
    required this.layoutEntries,
    required this.activeCutId,
    required this.onCutSelected,
    required this.onCutReordered,
    required this.timelineScale,
  });

  final Track track;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;
  final CutReorderedCallback? onCutReordered;
  final TimelineScale timelineScale;

  @override
  Widget build(BuildContext context) {
    final timelineWidth = _timelineWidthFor(layoutEntries, timelineScale);

    return Padding(
      key: ValueKey<String>('storyboard-track-row-${track.id.value}'),
      padding: const EdgeInsets.only(
        bottom: StoryboardPanel._trackRowBottomPadding,
      ),
      child: SizedBox(
        key: ValueKey<String>(
          'storyboard-track-timeline-area-${track.id.value}',
        ),
        width: timelineWidth,
        height: StoryboardPanel._trackLaneHeight,
        child: Stack(
          children: [
            for (final entry in layoutEntries)
              Positioned(
                key: ValueKey<String>(
                  'storyboard-cut-positioned-${entry.cutId.value}',
                ),
                left: timelineScale.leftForFrame(entry.startFrame),
                width: timelineScale.widthForDuration(entry.duration),
                top: 0,
                bottom: 0,
                child: _ReorderableStoryboardCutBlock(
                  layoutEntry: entry,
                  width: timelineScale.widthForDuration(entry.duration),
                  isActive: entry.cutId == activeCutId,
                  onSelected: onCutSelected,
                  canReorder:
                      onCutReordered != null && layoutEntries.length > 1,
                  onCutReordered: onCutReordered,
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _timelineWidthFor(
    List<StoryboardTimelineLayoutEntry> entries,
    TimelineScale scale,
  ) {
    const trailingPadding = 12.0;

    if (entries.isEmpty) {
      return 0;
    }

    return entries
            .map(
              (entry) =>
                  scale.leftForFrame(entry.startFrame) +
                  scale.widthForDuration(entry.duration),
            )
            .reduce(
              (width, nextWidth) => width > nextWidth ? width : nextWidth,
            ) +
        trailingPadding;
  }
}

/// The drag layer around a cut block: mirrors the top-bar chips' semantics
/// (drop on a target block = same-track reorder to its index) so both
/// surfaces stay interchangeable.
class _ReorderableStoryboardCutBlock extends StatelessWidget {
  const _ReorderableStoryboardCutBlock({
    required this.layoutEntry,
    required this.width,
    required this.isActive,
    required this.onSelected,
    required this.canReorder,
    required this.onCutReordered,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;
  final bool canReorder;
  final CutReorderedCallback? onCutReordered;

  @override
  Widget build(BuildContext context) {
    final block = _StoryboardCutBlock(
      layoutEntry: layoutEntry,
      width: width,
      isActive: isActive,
      onSelected: onSelected,
    );
    if (!canReorder) {
      return block;
    }

    return DragTarget<CutId>(
      onWillAcceptWithDetails: (details) => details.data != layoutEntry.cutId,
      onAcceptWithDetails: (details) {
        if (details.data == layoutEntry.cutId) {
          return;
        }

        onCutReordered?.call(
          draggedCutId: details.data,
          targetTrackId: layoutEntry.trackId,
          targetCutIndex: layoutEntry.cutIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Draggable<CutId>(
          key: ValueKey<String>(
            'storyboard-cut-draggable-${layoutEntry.cutId.value}',
          ),
          data: layoutEntry.cutId,
          axis: Axis.horizontal,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: SizedBox(
                width: width,
                height: StoryboardPanel._trackLaneHeight,
                child: _StoryboardCutBlock(
                  layoutEntry: layoutEntry,
                  width: width,
                  isActive: isActive,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.45, child: block),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isDropTarget
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: block,
          ),
        );
      },
    );
  }
}

class _StoryboardCutBlock extends StatelessWidget {
  const _StoryboardCutBlock({
    required this.layoutEntry,
    required this.width,
    required this.isActive,
    required this.onSelected,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cut = layoutEntry.cut;
    final storyboardLayer = storyboardLayerForCut(cut);

    return TimelineBlock(
      key: ValueKey<String>('storyboard-cut-block-${cut.id.value}'),
      width: width,
      isActive: isActive,
      minHeight: 0,
      padding: const EdgeInsets.all(4),
      onTap: isActive ? null : () => onSelected(cut.id),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: isActive ? 48 : 0),
                child: Text(
                  cut.name,
                  key: ValueKey<String>('storyboard-cut-title-${cut.id.value}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Text(
                    '${layoutEntry.duration}f',
                    key: ValueKey<String>(
                      'storyboard-cut-duration-${cut.id.value}',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${layoutEntry.startFrame}f - ${layoutEntry.endFrame}f',
                      key: ValueKey<String>(
                        'storyboard-cut-frame-range-${cut.id.value}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Expanded(
                child: storyboardLayer == null
                    ? ClipRect(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            'No Storyboard Layer',
                            key: ValueKey<String>(
                              'storyboard-layer-empty-${cut.id.value}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : Container(
                        key: ValueKey<String>(
                          'storyboard-layer-strip-${cut.id.value}',
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.centerLeft,
                        child: ClipRect(
                          child: Text(
                            storyboardLayer.name,
                            key: ValueKey<String>(
                              'storyboard-layer-name-${cut.id.value}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (isActive)
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                'ACTIVE',
                key: ValueKey<String>(
                  'storyboard-cut-active-indicator-${cut.id.value}',
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
