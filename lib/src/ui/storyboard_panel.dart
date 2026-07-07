import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';

import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/project.dart';
import '../models/timeline_coverage.dart' show TimelineBlockEdge;
import '../models/track.dart';
import '../models/track_id.dart';
import 'panels/panel_scrollbar.dart';
import 'storyboard_layer_policy.dart';
import 'storyboard_timeline_layout.dart';
import 'timeline/timeline_block.dart';
import 'timeline/timeline_cell_style.dart'
    show timelineDrawingInkColor, timelineSelectedFrameBorderColor;
import 'timeline/timeline_exposure_comma_drag_policy.dart'
    show commaDragFrameDelta;
import 'timeline/timeline_frame_range_policy.dart'
    show defaultEndlessRunwayFrames, endlessTrailingFrames;
import 'timeline/timeline_frame_ruler.dart';
import 'timeline/timeline_grid_metrics.dart';
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

/// The trim-drag hooks the cut edge grips need, mirroring the timeline's
/// comma-drag callbacks: wired to the session's
/// begin/update/end/cancelCutEdgeDrag (live preview, ONE undo per drag).
class StoryboardCutTrimCallbacks {
  const StoryboardCutTrimCallbacks({
    required this.onBegin,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
  });

  /// Returns whether the drag may start (the first cut has no start grip
  /// partner, deleted cuts refuse).
  final bool Function(CutId cutId, TimelineBlockEdge edge) onBegin;

  /// Reports the cumulative whole-frame delta since drag start.
  final ValueChanged<int> onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
}

class StoryboardPanel extends StatefulWidget {
  const StoryboardPanel({
    super.key,
    required this.project,
    required this.activeCutId,
    required this.onCutSelected,
    this.onCutReordered,
    this.cutTrim,
    this.playheadGlobalFrame,
    this.onSeekGlobalFrame,
    this.thumbnailFor,
    this.onNewCut,
    this.onRenameActiveCut,
    this.onEditActiveCutNote,
    this.onResizeActiveCutCanvas,
    this.onDuplicateActiveCut,
    this.onMoveActiveCutLeft,
    this.onMoveActiveCutRight,
    this.onDeleteActiveCut,
  });

  /// Frame-axis zoom steps (pixels per frame); index 1 is the classic 8px.
  static const List<double> _zoomSteps = [4, 8, 16, 24, 32];
  static const int _defaultZoomIndex = 1;

  /// Blocks are strictly frame-linear (Premiere-style): a large minimum
  /// width would make neighbours overlap when zoomed out. The tiny floor
  /// only keeps zero-length cuts visible.
  static const double _minBlockWidth = 8;

  static const double _trackLabelWidth = 56;
  static const double _trackLaneHeight = 64;
  static const double _trackRowBottomPadding = 4;
  static const double _rulerHeight = 24;
  static const double _timelineTrailingPadding = 12;

  final Project project;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;

  /// Dragging a cut block onto another block of the same track reorders the
  /// cuts (same semantics as the top-bar chips). Null disables dragging.
  final CutReorderedCallback? onCutReordered;

  /// Edge-grip trim hooks: the END grip changes a cut's duration (later
  /// cuts ripple), the START grip rolls the boundary with the previous cut.
  /// Null hides the grips.
  final StoryboardCutTrimCallbacks? cutTrim;

  /// Track-global frame the playhead line sits on (playback position while
  /// playing, the active cut's playhead otherwise). Null hides the line.
  final int? playheadGlobalFrame;

  /// Tapping or scrubbing the ruler reports the track-global frame under
  /// the pointer. Null makes the ruler display-only.
  final ValueChanged<int>? onSeekGlobalFrame;

  /// Build-time resolver for the cut blocks' first-frame thumbnails (the
  /// store behind it kicks async renders and re-notifies). The image stays
  /// OWNED BY THE RESOLVER — blocks paint it without disposing. Null hides
  /// the thumbnail strip.
  final ui.Image? Function(Cut cut)? thumbnailFor;

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

  int _zoomIndex = StoryboardPanel._defaultZoomIndex;
  int _endlessTrailingFrames = 0;
  double _horizontalScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_handleHorizontalScroll);
  }

  void _handleHorizontalScroll() {
    if (!_horizontalController.hasClients) {
      return;
    }
    final offset = _horizontalController.offset;
    final next = endlessTrailingFrames(
      baseFrameCount: _totalFrames(
        buildStoryboardTimelineLayout(widget.project),
      ),
      currentTrailingFrames: _endlessTrailingFrames,
      scrollOffset: offset,
      viewportExtent: _horizontalController.position.viewportDimension,
      frameCellExtent: _scale.pixelsPerFrame,
    );
    if (next != _endlessTrailingFrames || offset != _horizontalScrollOffset) {
      setState(() {
        _endlessTrailingFrames = next;
        // The shared frame ruler windows itself to the viewport.
        _horizontalScrollOffset = offset;
      });
    }
  }

  TimelineScale get _scale => TimelineScale(
    pixelsPerFrame: StoryboardPanel._zoomSteps[_zoomIndex],
    minBlockWidth: StoryboardPanel._minBlockWidth,
  );

  bool get _canZoomIn => _zoomIndex < StoryboardPanel._zoomSteps.length - 1;
  bool get _canZoomOut => _zoomIndex > 0;

  void _applyZoom(int nextIndex) {
    final previousPixels = StoryboardPanel._zoomSteps[_zoomIndex];
    setState(() => _zoomIndex = nextIndex);
    // Keep the frame at the viewport's left edge anchored through the zoom.
    if (_horizontalController.hasClients) {
      final factor = StoryboardPanel._zoomSteps[nextIndex] / previousPixels;
      final position = _horizontalController.position;
      _horizontalController.jumpTo(
        (position.pixels * factor).clamp(0.0, double.maxFinite),
      );
    }
  }

  @override
  void dispose() {
    _horizontalController.removeListener(_handleHorizontalScroll);
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// The widest content edge across every track (blocks can outgrow their
  /// duration via the minimum block width) plus trailing padding — the
  /// ruler and playhead overlay both span it.
  double _timelineContentWidth(
    List<StoryboardTimelineLayoutEntry> entries,
    TimelineScale scale,
  ) {
    var width = 0.0;
    for (final entry in entries) {
      final right =
          scale.leftForFrame(entry.startFrame) +
          scale.widthForDuration(entry.duration);
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
    final scale = _scale;
    final totalFrames = _totalFrames(layoutEntries);
    // Endless frame axis: the ruler (and scrollable area) always shows a
    // runway past the cuts, growing with how far the user has scrolled
    // (short content could never scroll into a grow-on-approach runway
    // otherwise); seeks stay content-bound.
    final renderedFrames =
        totalFrames +
        math.max<int>(_endlessTrailingFrames, defaultEndlessRunwayFrames);
    final contentWidth = math.max(
      _timelineContentWidth(layoutEntries, scale),
      scale.leftForFrame(renderedFrames) +
          StoryboardPanel._timelineTrailingPadding,
    );
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
            _StoryboardCutActionsToolbar(
              panel: widget,
              onZoomIn: _canZoomIn ? () => _applyZoom(_zoomIndex + 1) : null,
              onZoomOut: _canZoomOut ? () => _applyZoom(_zoomIndex - 1) : null,
            ),
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final viewportWidth = constraints.hasBoundedWidth
                                ? constraints.maxWidth
                                : contentWidth;
                            return PanelScrollbar(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _StoryboardRuler(
                                          width: contentWidth,
                                          renderedFrames: renderedFrames,
                                          seekableFrames: totalFrames,
                                          playheadFrame: playheadFrame,
                                          scrollOffset: _horizontalScrollOffset,
                                          viewportWidth: viewportWidth,
                                          timelineScale: scale,
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
                                            onCutReordered:
                                                widget.onCutReordered,
                                            cutTrim: widget.cutTrim,
                                            thumbnailFor: widget.thumbnailFor,
                                            timelineScale: scale,
                                          ),
                                      ],
                                    ),
                                    if (playheadFrame != null)
                                      // Frame-wide accent tint, same as the
                                      // timeline playhead; the solid left edge
                                      // keeps it visible over colorful blocks.
                                      Positioned(
                                        key: const ValueKey<String>(
                                          'storyboard-playhead',
                                        ),
                                        left: scale.leftForFrame(playheadFrame),
                                        top: 0,
                                        bottom: 0,
                                        width: scale.pixelsPerFrame,
                                        child: IgnorePointer(
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ColoredBox(
                                                  color: timelinePlayheadColor
                                                      .withValues(alpha: 0.18),
                                                ),
                                              ),
                                              const Positioned(
                                                left: 0,
                                                top: 0,
                                                bottom: 0,
                                                width: 2,
                                                child: ColoredBox(
                                                  color: timelinePlayheadColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
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
/// cut). The frame-zoom cluster sits at the right edge.
class _StoryboardCutActionsToolbar extends StatelessWidget {
  const _StoryboardCutActionsToolbar({
    required this.panel,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final StoryboardPanel panel;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: panel._hasCutActions
                ? _cutActionsScroller()
                : const SizedBox.shrink(),
          ),
          _CutActionButton(
            key: const ValueKey<String>('storyboard-zoom-out-button'),
            tooltip: 'Zoom Out',
            icon: Icons.zoom_out,
            onPressed: onZoomOut,
          ),
          _CutActionButton(
            key: const ValueKey<String>('storyboard-zoom-in-button'),
            tooltip: 'Zoom In',
            icon: Icons.zoom_in,
            onPressed: onZoomIn,
          ),
        ],
      ),
    );
  }

  Widget _cutActionsScroller() {
    return Align(
      alignment: Alignment.centerLeft,
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
/// The storyboard's frame ruler IS the timeline's ([TimelineFrameRuler] with
/// the cell extent carrying the storyboard zoom): identical header cells,
/// adaptive labels, runway dimming and the cut-end boundary line. The row is
/// windowed to the scrolled viewport because the storyboard's scroll content
/// is not otherwise virtualized.
class _StoryboardRuler extends StatelessWidget {
  const _StoryboardRuler({
    required this.width,
    required this.renderedFrames,
    required this.seekableFrames,
    required this.playheadFrame,
    required this.scrollOffset,
    required this.viewportWidth,
    required this.timelineScale,
    required this.onSeekGlobalFrame,
  });

  static const int _overscanCells = 4;

  final double width;

  /// Rendered range — includes the endless-axis runway past the cuts.
  final int renderedFrames;

  /// Seeks clamp here (the cuts' actual end); the runway is display-only.
  final int seekableFrames;

  final int? playheadFrame;
  final double scrollOffset;
  final double viewportWidth;
  final TimelineScale timelineScale;
  final ValueChanged<int>? onSeekGlobalFrame;

  void _seekFrame(int frame) {
    final onSeek = onSeekGlobalFrame;
    if (onSeek == null || seekableFrames <= 0) {
      return;
    }
    onSeek(frame.clamp(0, seekableFrames - 1));
  }

  void _seekAt(double dx) {
    _seekFrame((dx / timelineScale.pixelsPerFrame).floor());
  }

  @override
  Widget build(BuildContext context) {
    final cellWidth = timelineScale.pixelsPerFrame;
    final startIndex = math.max(
      0,
      (scrollOffset / cellWidth).floor() - _overscanCells,
    );
    final endIndexExclusive = math.min(
      renderedFrames,
      ((scrollOffset + viewportWidth) / cellWidth).ceil() + _overscanCells,
    );
    final metrics = TimelineGridMetrics(
      frameCellWidth: cellWidth,
      layerRowHeight: StoryboardPanel._rulerHeight,
      layerControlsWidth: 0,
      verticalScrollbarWidth: 0,
    );

    return GestureDetector(
      key: const ValueKey<String>('storyboard-ruler'),
      behavior: HitTestBehavior.translucent,
      // .down reports the true pointer-down position, so a scrub seeks the
      // pressed frame first instead of the post-slop position. Plain taps
      // are the header cells' own InkWells.
      dragStartBehavior: DragStartBehavior.down,
      // Scrubbing claims horizontal drags on the ruler strip only; the
      // track rows below still pan the panel.
      onHorizontalDragStart: (details) => _seekAt(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _seekAt(details.localPosition.dx),
      child: SizedBox(
        width: width,
        height: StoryboardPanel._rulerHeight,
        child: TimelineFrameRuler(
          key: const ValueKey<String>('storyboard-frame-ruler'),
          frameStartIndex: startIndex,
          frameEndIndexExclusive: math.max(startIndex, endIndexExclusive),
          currentFrameIndex: playheadFrame ?? -1,
          playbackFrameCount: seekableFrames,
          leadingFrameSpacerWidth: startIndex * cellWidth,
          trailingFrameSpacerWidth: math.max(
            0,
            (renderedFrames - math.max(startIndex, endIndexExclusive)) *
                cellWidth,
          ),
          metrics: metrics,
          onSelectFrame: _seekFrame,
        ),
      ),
    );
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
    required this.cutTrim,
    required this.thumbnailFor,
    required this.timelineScale,
  });

  final Track track;
  final List<StoryboardTimelineLayoutEntry> layoutEntries;
  final CutId activeCutId;
  final ValueChanged<CutId> onCutSelected;
  final CutReorderedCallback? onCutReordered;
  final StoryboardCutTrimCallbacks? cutTrim;
  final ui.Image? Function(Cut cut)? thumbnailFor;
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
                  thumbnail: thumbnailFor?.call(entry.cut),
                  showThumbnail: thumbnailFor != null,
                ),
              ),
            // Trim grips paint over the block edges (their 12px strips win
            // pointer contests there; block taps/reorder keep the middle).
            if (cutTrim != null)
              for (final entry in layoutEntries) ...[
                if (entry.cutIndex > 0)
                  _StoryboardCutEdgeGrip(
                    cutId: entry.cutId,
                    cutOrdinal: entry.cutIndex,
                    edge: TimelineBlockEdge.start,
                    blockStartOffset: timelineScale.leftForFrame(
                      entry.startFrame,
                    ),
                    blockEndOffset:
                        timelineScale.leftForFrame(entry.startFrame) +
                        timelineScale.widthForDuration(entry.duration),
                    frameCellExtent: timelineScale.pixelsPerFrame,
                    crossAxisExtent: StoryboardPanel._trackLaneHeight,
                    callbacks: cutTrim!,
                  ),
                _StoryboardCutEdgeGrip(
                  cutId: entry.cutId,
                  cutOrdinal: entry.cutIndex,
                  edge: TimelineBlockEdge.end,
                  blockStartOffset: timelineScale.leftForFrame(
                    entry.startFrame,
                  ),
                  blockEndOffset:
                      timelineScale.leftForFrame(entry.startFrame) +
                      timelineScale.widthForDuration(entry.duration),
                  frameCellExtent: timelineScale.pixelsPerFrame,
                  crossAxisExtent: StoryboardPanel._trackLaneHeight,
                  callbacks: cutTrim!,
                ),
              ],
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

/// One cut trim grip: an inset vertical bar just inside a cut block's start
/// or end edge, mirroring the timeline's [TimelineBlockEdgeGrip] visuals and
/// gesture state machine (cumulative whole-frame deltas via the shared
/// comma-drag policy; the session recomputes the preview from its drag-start
/// snapshot).
///
/// The Positioned key derives from the cut ORDINAL, never its start frame —
/// a roll drag moves the start every step, and a key change there would
/// rebuild the gesture subtree mid-drag and kill it (same constraint as the
/// timeline grips).
class _StoryboardCutEdgeGrip extends StatefulWidget {
  const _StoryboardCutEdgeGrip({
    required this.cutId,
    required this.cutOrdinal,
    required this.edge,
    required this.blockStartOffset,
    required this.blockEndOffset,
    required this.frameCellExtent,
    required this.crossAxisExtent,
    required this.callbacks,
  });

  final CutId cutId;
  final int cutOrdinal;
  final TimelineBlockEdge edge;
  final double blockStartOffset;
  final double blockEndOffset;
  final double frameCellExtent;
  final double crossAxisExtent;
  final StoryboardCutTrimCallbacks callbacks;

  static const double hitExtent = 12;
  static const double _barThickness = 3.5;
  static const double _barInset = 2.5;

  @override
  State<_StoryboardCutEdgeGrip> createState() => _StoryboardCutEdgeGripState();
}

class _StoryboardCutEdgeGripState extends State<_StoryboardCutEdgeGrip> {
  double _accumulatedDelta = 0;
  int _lastReportedFrames = 0;
  bool _dragging = false;

  void _startDrag() {
    if (!widget.callbacks.onBegin(widget.cutId, widget.edge)) {
      return;
    }
    setState(() {
      _dragging = true;
      _accumulatedDelta = 0;
      _lastReportedFrames = 0;
    });
  }

  void _updateDrag(double delta) {
    if (!_dragging) {
      return;
    }
    _accumulatedDelta += delta;
    final frames = commaDragFrameDelta(
      accumulatedDelta: _accumulatedDelta,
      frameCellExtent: widget.frameCellExtent,
    );
    if (frames == _lastReportedFrames) {
      return;
    }
    _lastReportedFrames = frames;
    widget.callbacks.onUpdate(frames);
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
    // A grip can unmount mid-drag; commit rather than leak an open session
    // (same policy as the timeline grips).
    if (_dragging) {
      widget.callbacks.onEnd();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStartEdge = widget.edge == TimelineBlockEdge.start;
    final hitStart = isStartEdge
        ? widget.blockStartOffset
        : widget.blockEndOffset - _StoryboardCutEdgeGrip.hitExtent;
    final barColor = _dragging
        ? timelineSelectedFrameBorderColor
        : timelineDrawingInkColor.withValues(alpha: 0.38);

    return Positioned(
      key: ValueKey<String>(
        'storyboard-cut-edge-grip-${widget.edge.name}-${widget.cutOrdinal}',
      ),
      left: hitStart,
      top: 0,
      width: _StoryboardCutEdgeGrip.hitExtent,
      height: widget.crossAxisExtent,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _startDrag(),
          onHorizontalDragUpdate: (details) => _updateDrag(details.delta.dx),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _cancelDrag,
          child: Align(
            alignment: isStartEdge
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                left: isStartEdge ? _StoryboardCutEdgeGrip._barInset : 0,
                right: isStartEdge ? 0 : _StoryboardCutEdgeGrip._barInset,
              ),
              child: Container(
                width: _StoryboardCutEdgeGrip._barThickness,
                height: widget.crossAxisExtent * 0.55,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    required this.thumbnail,
    required this.showThumbnail,
  });

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;
  final bool canReorder;
  final CutReorderedCallback? onCutReordered;
  final ui.Image? thumbnail;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    final block = _StoryboardCutBlock(
      layoutEntry: layoutEntry,
      width: width,
      isActive: isActive,
      onSelected: onSelected,
      thumbnail: thumbnail,
      showThumbnail: showThumbnail,
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
                  thumbnail: thumbnail,
                  showThumbnail: showThumbnail,
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
    this.thumbnail,
    this.showThumbnail = false,
  });

  static const double _thumbnailWidth = 44;

  final StoryboardTimelineLayoutEntry layoutEntry;
  final double width;
  final bool isActive;
  final ValueChanged<CutId> onSelected;

  /// Painted, never disposed here: the thumbnail store owns the image.
  final ui.Image? thumbnail;
  final bool showThumbnail;

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Zoomed-out blocks are too narrow for the fixed-width thumb;
              // the flexible texts just ellipsize.
              if (showThumbnail &&
                  width >= _StoryboardCutBlock._thumbnailWidth + 28) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    width: _StoryboardCutBlock._thumbnailWidth,
                    child: thumbnail == null
                        ? ColoredBox(
                            key: ValueKey<String>(
                              'storyboard-cut-thumb-empty-${cut.id.value}',
                            ),
                            color: colorScheme.surfaceContainerHighest,
                          )
                        : RawImage(
                            key: ValueKey<String>(
                              'storyboard-cut-thumb-${cut.id.value}',
                            ),
                            image: thumbnail,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: isActive ? 48 : 0),
                      child: Text(
                        cut.name,
                        key: ValueKey<String>(
                          'storyboard-cut-title-${cut.id.value}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${layoutEntry.duration}f',
                            key: ValueKey<String>(
                              'storyboard-cut-duration-${cut.id.value}',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
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
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            )
                          : Container(
                              key: ValueKey<String>(
                                'storyboard-layer-strip-${cut.id.value}',
                              ),
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
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
