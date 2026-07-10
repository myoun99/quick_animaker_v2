import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_mark.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'layer_label_controls.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cell.dart';
import 'timeline_frame_cells_row.dart' show timelineRowBlockEdgeGrips;
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_cursor_layer.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_body_cut_end_boundary.dart';
import 'timeline_cell_editor_policy.dart';
import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';
import 'se_audio_lane.dart';
import 'timeline_lane_rows.dart';
import 'timeline_instruction_row_visual.dart';
import 'timeline_se_row_visual.dart';
import 'timeline_horizontal_offset_policy.dart';
import 'timeline_horizontal_scrollbar_rail.dart';
import 'timeline_ruler_cut_end_boundary.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';
import 'timeline_vertical_scrollbar_rail.dart';
import 'timeline_virtualization_plan.dart';
import 'timeline_zoom_anchor_policy.dart';

/// The vertical X-sheet: the SAME grid logic as the horizontal
/// [LayerTimelineGrid], transposed.
///
/// The transposition is a metrics trick: the frame axis runs vertically, so
/// [_metrics.frameCellWidth] is the frame ROW height and
/// [_metrics.layerRowHeight] is the layer COLUMN width. Every policy the
/// horizontal grid uses — frame range, offset resolution, virtualization
/// plan, coordinate conversion, cell style/block visuals, selected exposure
/// range, playhead visibility, cut-end boundary — is reused unchanged with
/// the axes swapped; only the thin widget composition differs.
class XSheetTimelineGrid extends StatefulWidget {
  const XSheetTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.frameCursor,
    this.cacheProgress,
    required this.frameCount,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.onScrubFrame,
    this.onScrubEnd,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.projectFps = 24,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.onSetAudioClipOffset,
    this.audioOffsetDrag,
    this.onSetAudioClipFades,
    this.onSetAudioClipGain,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
    this.onToggleLayerMuted,
    this.commaDrag,
    this.isFrameCached,
    this.metrics = defaultMetrics,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.lanesForLayer,
    this.laneEdit,
    this.onToggleLaneGroup,
    this.hiddenSections = const {},
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;

  /// The frame cursor (editing playhead / playback position). Only the
  /// cursor layer, the frame-number rail and the lane headers subscribe —
  /// ticks never rebuild the grid (playback-performance architecture,
  /// mirroring the horizontal timeline).
  final ValueListenable<int> frameCursor;

  /// Repaints the frame rail's cached-range green strip as frames warm.
  final Listenable? cacheProgress;

  /// Playback frame count of the active cut (the visible range extends to
  /// the shared minimum, exactly like the horizontal timeline).
  final int frameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Frame-rail scrub path: per-move frames go to [onScrubFrame]
  /// (cursor-only, no commit) and the pointer's release fires [onScrubEnd]
  /// to commit once. Null falls back to [onSelectFrame] per move.
  final ValueChanged<int>? onScrubFrame;
  final VoidCallback? onScrubEnd;

  /// Double-tap cell editor hook (SE label dialog; see
  /// [layerKindOpensCellEditorOnDoubleTap]).
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;

  /// Resolves instruction ids to defs for CAM column chips.
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;

  /// Waveform peaks for SE columns' audio clips + the removal hook.
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final int projectFps;
  final void Function(LayerId layerId, int clipIndex)? onRemoveAudioClip;

  /// Links a media-browser asset to an SE block (drag-drop).
  final void Function(LayerId layerId, int blockStartFrame, String path)?
  onDropMediaAsset;

  /// Commits an audio-lane slide (the clip's offset trim).
  final void Function(LayerId layerId, int clipIndex, int offsetFrames)?
  onSetAudioClipOffset;

  /// Live drag session for the slide (repo-direct preview + one undo).
  final AudioOffsetDragCallbacks? audioOffsetDrag;

  /// Commits an audio-lane fade-handle drag.
  final void Function(
    LayerId layerId,
    int clipIndex,
    int fadeInFrames,
    int fadeOutFrames,
  )?
  onSetAudioClipFades;

  /// Commits the audio-lane gain dialog.
  final void Function(LayerId layerId, int clipIndex, double gain)?
  onSetAudioClipGain;

  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// The AE-style layer fx switch (session view state); null hides it.
  final bool Function(LayerId layerId)? layerFxEnabledOf;
  final ValueChanged<LayerId>? onToggleLayerFx;

  /// SE columns' speaker button (mute); null hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// Comma-drag hooks for the block edge grips (shared policy with the
  /// horizontal timeline); null hides the grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// Cached-range resolver for the frame rail's green strip (the transposed
  /// counterpart of the horizontal ruler's strip).
  final bool Function(int frameIndex)? isFrameCached;

  /// Grid geometry (transposed); frameCellWidth carries the frame-axis zoom
  /// as the frame ROW height here.
  final TimelineGridMetrics metrics;

  /// AE-style property lanes, transposed: an expanded layer's lanes appear
  /// as COLUMNS beside it (the layer axis runs horizontally here). Same
  /// generic provider + edit hooks as the horizontal timeline.
  final Set<LayerId> expandedLaneLayerIds;
  final ValueChanged<LayerId>? onToggleLayerLanes;
  final List<PropertyLaneRow> Function(Layer layer)? lanesForLayer;
  final PropertyLaneEditCallbacks? laneEdit;

  /// Group headers: tapping twirls the group's member lanes (AE collapse).
  final void Function(Layer layer, PropertyLaneRow lane)? onToggleLaneGroup;

  /// Sections hidden from the grid entirely (toolbar visibility toggles;
  /// the section axis runs horizontally here, so hiding drops columns).
  final Set<TimelineSection> hiddenSections;

  /// TRANSPOSED metrics: frameCellWidth = frame row height, layerRowHeight
  /// = layer column width, layerControlsWidth = frame-number rail width.
  /// No section gutter here — the X-sheet's section axis is horizontal and
  /// section controls live on the column headers.
  static const TimelineGridMetrics defaultMetrics = TimelineGridMetrics(
    frameCellWidth: 36,
    layerRowHeight: 164,
    layerControlsWidth: 72,
    sectionLabelGutterWidth: 0,
  );

  static const double _headerHeight = 92;

  /// The section band above the layer headers: the paper sheet's
  /// ACTION/SE/CAM group headings, each wrapping its columns.
  static const double _sectionBandHeight = 20;
  static const double _totalHeaderHeight = _headerHeight + _sectionBandHeight;

  @override
  State<XSheetTimelineGrid> createState() => _XSheetTimelineGridState();
}

class _XSheetTimelineGridState extends State<XSheetTimelineGrid> {
  late final ScrollController _frameScrollController;
  late final ScrollController _layerScrollController;
  double _frameScrollOffset = 0;
  double _lastEffectiveFrameScrollOffset = 0;
  double? _scheduledFrameOffsetCorrection;
  int _endlessTrailingFrames = 0;
  final GlobalKey _railScrubViewportKey = GlobalKey();
  int? _lastRailScrubbedFrameIndex;

  TimelineGridMetrics get _metrics => widget.metrics;

  @override
  void initState() {
    super.initState();
    _frameScrollController = ScrollController();
    _layerScrollController = ScrollController();
    _frameScrollController.addListener(_handleFrameScroll);
  }

  @override
  void didUpdateWidget(covariant XSheetTimelineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Zoom-around-playhead (transposed): the playhead ROW stays put on
    // screen through zoom when visible; otherwise the top-edge frame
    // anchors. Same policy as the horizontal timeline (Axis rule).
    final oldCell = oldWidget.metrics.frameCellWidth;
    final newCell = widget.metrics.frameCellWidth;
    if (oldCell != newCell && _frameScrollController.hasClients) {
      _frameScrollController.jumpTo(
        zoomAnchoredScrollOffset(
          oldOffset: _frameScrollController.offset,
          oldPixelsPerFrame: oldCell,
          newPixelsPerFrame: newCell,
          viewportExtent: _frameScrollController.position.viewportDimension,
          anchorFrame: widget.frameCursor.value,
        ),
      );
    }
  }

  @override
  void dispose() {
    _frameScrollController
      ..removeListener(_handleFrameScroll)
      ..dispose();
    _layerScrollController.dispose();
    super.dispose();
  }

  void _handleFrameScroll() {
    final offset = _frameScrollController.hasClients
        ? _frameScrollController.offset
        : 0.0;
    if (offset == _frameScrollOffset) {
      return;
    }
    final nextTrailingFrames = _frameScrollController.hasClients
        ? endlessTrailingFrames(
            baseFrameCount: _visibleFrameCount,
            currentTrailingFrames: _endlessTrailingFrames,
            scrollOffset: offset,
            viewportExtent: _frameScrollController.position.viewportDimension,
            frameCellExtent: _metrics.frameCellWidth,
          )
        : _endlessTrailingFrames;
    setState(() {
      _frameScrollOffset = offset;
      _endlessTrailingFrames = nextTrailingFrames;
    });
  }

  TimelineFrameRange get _frameRangePolicy =>
      TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: widget.frameCount,
        minimumVisibleFrameCells: _metrics.minimumVisibleFrameCells,
      );

  int get _visibleFrameCount => _frameRangePolicy.visibleFrameCount;

  /// Render extent: the endless-axis runway extends past the base count as
  /// the user scrolls. Interaction clamps stay on [_visibleFrameCount].
  int get _renderedFrameCount => _visibleFrameCount + _endlessTrailingFrames;

  double get _totalFrameContentHeight =>
      _renderedFrameCount * _metrics.frameCellWidth;

  double _effectiveFrameScrollOffset({
    required double requestedOffset,
    required double viewportExtent,
  }) {
    // Same offset policy as the horizontal grid, transposed to y.
    return resolveTimelineHorizontalOffset(
      requestedOffset: requestedOffset,
      totalContentWidth: _totalFrameContentHeight,
      viewportWidth: viewportExtent,
    ).effectiveOffset;
  }

  void _synchronizeFrameScrollController(double effectiveOffset) {
    if (!_frameScrollController.hasClients ||
        _frameScrollController.offset == effectiveOffset ||
        _scheduledFrameOffsetCorrection == effectiveOffset) {
      return;
    }

    _scheduledFrameOffsetCorrection = effectiveOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_frameScrollController.hasClients) {
        _scheduledFrameOffsetCorrection = null;
        return;
      }

      final maxScrollExtent = _frameScrollController.position.maxScrollExtent;
      final targetOffset = effectiveOffset
          .clamp(0.0, maxScrollExtent)
          .toDouble();

      _scheduledFrameOffsetCorrection = null;
      if (_frameScrollController.offset != targetOffset) {
        _frameScrollController.jumpTo(targetOffset);
      }
    });
  }

  int? _frameIndexForRailLocalY(double localY) {
    // Shared frame/x conversion policy; the rail's local y is the "x".
    return frameIndexFromLocalX(
      localX: localY,
      horizontalScrollOffset: _lastEffectiveFrameScrollOffset,
      frameCellWidth: _metrics.frameCellWidth,
      visibleFrameCount: _visibleFrameCount,
    );
  }

  void _selectClampedFrameFromRail(int frameIndex) {
    final clampedFrameIndex = clampFrameIndex(
      frameIndex: frameIndex,
      visibleFrameCount: _visibleFrameCount,
    );
    if (clampedFrameIndex == null ||
        clampedFrameIndex == _lastRailScrubbedFrameIndex) {
      return;
    }

    _lastRailScrubbedFrameIndex = clampedFrameIndex;
    (widget.onScrubFrame ?? widget.onSelectFrame)(clampedFrameIndex);
  }

  /// The scrub gesture's release (raw pointer up/cancel — fires for taps
  /// AND drags). Tracking is NOT reset here so trailing tap handlers stay
  /// deduplicated.
  void _endRailScrub() {
    widget.onScrubEnd?.call();
  }

  void _selectFrameFromRailGlobalPosition(Offset globalPosition) {
    final renderObject = _railScrubViewportKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final localY = renderObject.globalToLocal(globalPosition).dy;
    final frameIndex = _frameIndexForRailLocalY(localY);
    if (frameIndex == null) {
      return;
    }

    _selectClampedFrameFromRail(frameIndex);
  }

  void _resetRailScrubTracking() {
    _lastRailScrubbedFrameIndex = null;
  }

  List<PropertyLaneRow> _lanesFor(Layer layer) =>
      widget.lanesForLayer?.call(layer) ?? const [];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const bottomScrollbarRailHeight = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyViewportHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight -
                      XSheetTimelineGrid._totalHeaderHeight -
                      bottomScrollbarRailHeight)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;
        final effectiveFrameScrollOffset = _effectiveFrameScrollOffset(
          requestedOffset: _frameScrollOffset,
          viewportExtent: bodyViewportHeight,
        );
        _lastEffectiveFrameScrollOffset = effectiveFrameScrollOffset;
        _synchronizeFrameScrollController(effectiveFrameScrollOffset);

        // Hidden sections contribute no columns; the section band above
        // the headers carries each section's bracket (shared row/run
        // policy with the horizontal grid).
        final entries = buildTimelineDisplayRows(
          layers: widget.layers,
          expandedLayerIds: widget.expandedLaneLayerIds,
          lanesForLayer: _lanesFor,
          hiddenSections: widget.hiddenSections,
        );
        final sectionRuns = timelineSectionRuns(entries);

        // The shared virtualization plan with the frame axis fed through the
        // "horizontal" inputs (the axes are swapped in this grid).
        final plan = calculateTimelineVirtualizationPlan(
          horizontalScrollOffset: effectiveFrameScrollOffset,
          verticalScrollOffset: 0,
          viewportWidth: bodyViewportHeight,
          viewportHeight: 0,
          frameCellWidth: _metrics.frameCellWidth,
          layerRowHeight: _metrics.layerRowHeight,
          frameCount: _renderedFrameCount,
          layerCount: entries.length,
        );
        final frameRange = plan.frameRange;
        final totalFrameContentHeight = plan.totalFrameContentWidth;
        // Columns are no longer uniformly wide: collapsed sections fold to
        // a slim strip.
        final columnsContentWidth = timelineDisplayRowsExtent(
          entries,
          _metrics,
        );
        final cutEndBoundaryOffset = timelineCutEndBoundaryX(
          playbackFrameCount: widget.frameCount,
          metrics: _metrics,
        );

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: _metrics.layerControlsWidth,
                    child: Column(
                      children: [
                        _HeaderCell(
                          width: _metrics.layerControlsWidth,
                          height: XSheetTimelineGrid._totalHeaderHeight,
                          child: const Text('Frame'),
                        ),
                        Expanded(
                          child: Listener(
                            key: const ValueKey<String>(
                              'xsheet-frame-rail-scrub-area',
                            ),
                            behavior: HitTestBehavior.translucent,
                            onPointerDown: (event) {
                              _resetRailScrubTracking();
                              _selectFrameFromRailGlobalPosition(
                                event.position,
                              );
                            },
                            onPointerUp: (_) => _endRailScrub(),
                            onPointerCancel: (_) => _endRailScrub(),
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragStart: (details) {
                                _selectFrameFromRailGlobalPosition(
                                  details.globalPosition,
                                );
                              },
                              onVerticalDragUpdate: (details) {
                                _selectFrameFromRailGlobalPosition(
                                  details.globalPosition,
                                );
                              },
                              onVerticalDragEnd: (_) =>
                                  _resetRailScrubTracking(),
                              onVerticalDragCancel: _resetRailScrubTracking,
                              child: ClipRect(
                                key: _railScrubViewportKey,
                                child: OverflowBox(
                                  alignment: Alignment.topLeft,
                                  minHeight: totalFrameContentHeight,
                                  maxHeight: totalFrameContentHeight,
                                  minWidth: _metrics.layerControlsWidth,
                                  maxWidth: _metrics.layerControlsWidth,
                                  child: Transform.translate(
                                    offset: Offset(
                                      0,
                                      -effectiveFrameScrollOffset,
                                    ),
                                    child: SizedBox(
                                      width: _metrics.layerControlsWidth,
                                      height: totalFrameContentHeight,
                                      child: Stack(
                                        children: [
                                          // The rail subscribes to the
                                          // cursor + cache progress itself:
                                          // ticks repaint this subtree only.
                                          ListenableBuilder(
                                            listenable: Listenable.merge([
                                              widget.frameCursor,
                                              ?widget.cacheProgress,
                                            ]),
                                            builder: (context, _) =>
                                                _XSheetFrameNumberRail(
                                                  frameStartIndex:
                                                      frameRange.startIndex,
                                                  frameEndIndexExclusive:
                                                      frameRange
                                                          .endIndexExclusive,
                                                  currentFrameIndex:
                                                      widget.frameCursor.value,
                                                  playbackFrameCount:
                                                      widget.frameCount,
                                                  leadingFrameSpacerHeight: plan
                                                      .leadingFrameSpacerWidth,
                                                  trailingFrameSpacerHeight: plan
                                                      .trailingFrameSpacerWidth,
                                                  metrics: _metrics,
                                                  onSelectFrame:
                                                      _selectClampedFrameFromRail,
                                                  isFrameCached:
                                                      widget.isFrameCached,
                                                ),
                                          ),
                                          TimelineRulerCutEndBoundary(
                                            axis: Axis.vertical,
                                            left: cutEndBoundaryOffset,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: _metrics.verticalScrollbarWidth,
                    child: Column(
                      children: [
                        TimelineVerticalScrollbarSlot(
                          width: _metrics.verticalScrollbarWidth,
                          height: XSheetTimelineGrid._totalHeaderHeight,
                        ),
                        Expanded(
                          child: TimelineVerticalScrollbarRail(
                            controller: _frameScrollController,
                            viewportHeight: bodyViewportHeight,
                            contentHeight: totalFrameContentHeight,
                            width: _metrics.verticalScrollbarWidth,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: widget.layers.isEmpty
                        ? Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                'No layers',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            key: const ValueKey<String>(
                              'xsheet-layer-horizontal-viewport',
                            ),
                            controller: _layerScrollController,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: columnsContentWidth,
                              child: Column(
                                children: [
                                  // The paper sheet's group headings: one
                                  // bracket cell per section run, wrapping
                                  // its columns.
                                  Row(
                                    children: [
                                      for (final run in sectionRuns)
                                        _XSheetSectionBandCell(
                                          run: run,
                                          extent: timelineSectionRunExtent(
                                            run,
                                            entries,
                                            _metrics,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < entries.length;
                                        index += 1
                                      )
                                        entries[index].isLane
                                            // Lane headers show the value AT
                                            // the cursor: subscribe here so
                                            // ticks rebuild only these cells.
                                            ? ValueListenableBuilder<int>(
                                                valueListenable:
                                                    widget.frameCursor,
                                                builder:
                                                    (
                                                      context,
                                                      cursorFrame,
                                                      _,
                                                    ) => TimelineLaneControlsRow(
                                                      axis: Axis.vertical,
                                                      keyPrefix: 'xsheet',
                                                      layer:
                                                          entries[index].layer,
                                                      lane:
                                                          entries[index].lane!,
                                                      metrics: _metrics,
                                                      width: _metrics
                                                          .layerRowHeight,
                                                      height: XSheetTimelineGrid
                                                          ._headerHeight,
                                                      currentFrameIndex:
                                                          cursorFrame,
                                                      onSelectFrame:
                                                          widget.onSelectFrame,
                                                      laneEdit: widget.laneEdit,
                                                      onToggleLaneGroup: widget
                                                          .onToggleLaneGroup,
                                                    ),
                                              )
                                            : _LayerHeader(
                                                layer: entries[index].layer,
                                                active:
                                                    entries[index].layer.id ==
                                                    widget.activeLayerId,
                                                metrics: _metrics,
                                                sectionStart:
                                                    timelineSectionStartsAt(
                                                      widget.layers,
                                                      entries[index].layerIndex,
                                                    ),
                                                onSelectLayer:
                                                    widget.onSelectLayer,
                                                onToggleLayerVisibility: widget
                                                    .onToggleLayerVisibility,
                                                onLayerOpacityChanged: widget
                                                    .onLayerOpacityChanged,
                                                onToggleLayerTimesheet: widget
                                                    .onToggleLayerTimesheet,
                                                fxEnabled:
                                                    widget.layerFxEnabledOf
                                                        ?.call(
                                                          entries[index]
                                                              .layer
                                                              .id,
                                                        ) ??
                                                    true,
                                                onToggleLayerFx:
                                                    widget.onToggleLayerFx,
                                                onLayerMarkSelected:
                                                    widget.onLayerMarkSelected,
                                                onToggleLayerMuted:
                                                    widget.onToggleLayerMuted,
                                                hasLanes: _lanesFor(
                                                  entries[index].layer,
                                                ).isNotEmpty,
                                                lanesExpanded: widget
                                                    .expandedLaneLayerIds
                                                    .contains(
                                                      entries[index].layer.id,
                                                    ),
                                                onToggleLanes:
                                                    widget.onToggleLayerLanes,
                                              ),
                                    ],
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      key: const ValueKey<String>(
                                        'xsheet-frame-vertical-viewport',
                                      ),
                                      controller: _frameScrollController,
                                      child: SizedBox(
                                        height: totalFrameContentHeight,
                                        child: Stack(
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // RepaintBoundary per column
                                                // (mirrors the horizontal
                                                // rows): the cursor layer
                                                // repaints alone on ticks.
                                                for (
                                                  var index = 0;
                                                  index < entries.length;
                                                  index += 1
                                                )
                                                  RepaintBoundary(
                                                    child: entries[index].isLane
                                                        ? (laneIsSeAudio(
                                                                entries[index]
                                                                    .lane!,
                                                              )
                                                              ? SeAudioLaneFrameRow(
                                                                  axis: Axis
                                                                      .vertical,
                                                                  keyPrefix:
                                                                      'xsheet',
                                                                  layer:
                                                                      entries[index]
                                                                          .layer,
                                                                  frameStartIndex:
                                                                      frameRange
                                                                          .startIndex,
                                                                  frameEndIndexExclusive:
                                                                      frameRange
                                                                          .endIndexExclusive,
                                                                  leadingFrameSpacerWidth:
                                                                      plan.leadingFrameSpacerWidth,
                                                                  trailingFrameSpacerWidth:
                                                                      plan.trailingFrameSpacerWidth,
                                                                  metrics:
                                                                      _metrics,
                                                                  fps: widget
                                                                      .projectFps,
                                                                  audioPeaksFor:
                                                                      widget
                                                                          .audioPeaksFor,
                                                                  onSetClipOffset:
                                                                      widget.onSetAudioClipOffset ==
                                                                          null
                                                                      ? null
                                                                      : (
                                                                          clipIndex,
                                                                          offsetFrames,
                                                                        ) => widget.onSetAudioClipOffset!(
                                                                          entries[index]
                                                                              .layer
                                                                              .id,
                                                                          clipIndex,
                                                                          offsetFrames,
                                                                        ),
                                                                  offsetDrag: widget
                                                                      .audioOffsetDrag,
                                                                  onSetClipFades:
                                                                      widget.onSetAudioClipFades ==
                                                                          null
                                                                      ? null
                                                                      : (
                                                                          clipIndex,
                                                                          fadeIn,
                                                                          fadeOut,
                                                                        ) => widget.onSetAudioClipFades!(
                                                                          entries[index]
                                                                              .layer
                                                                              .id,
                                                                          clipIndex,
                                                                          fadeIn,
                                                                          fadeOut,
                                                                        ),
                                                                  onSetClipGain:
                                                                      widget.onSetAudioClipGain ==
                                                                          null
                                                                      ? null
                                                                      : (
                                                                          clipIndex,
                                                                          gain,
                                                                        ) => widget.onSetAudioClipGain!(
                                                                          entries[index]
                                                                              .layer
                                                                              .id,
                                                                          clipIndex,
                                                                          gain,
                                                                        ),
                                                                )
                                                              : TimelineLaneFrameRow(
                                                                  axis: Axis
                                                                      .vertical,
                                                                  keyPrefix:
                                                                      'xsheet',
                                                                  layer:
                                                                      entries[index]
                                                                          .layer,
                                                                  lane:
                                                                      entries[index]
                                                                          .lane!,
                                                                  frameStartIndex:
                                                                      frameRange
                                                                          .startIndex,
                                                                  frameEndIndexExclusive:
                                                                      frameRange
                                                                          .endIndexExclusive,
                                                                  leadingFrameSpacerWidth:
                                                                      plan.leadingFrameSpacerWidth,
                                                                  trailingFrameSpacerWidth:
                                                                      plan.trailingFrameSpacerWidth,
                                                                  metrics:
                                                                      _metrics,
                                                                  laneEdit: widget
                                                                      .laneEdit,
                                                                ))
                                                        : _XSheetFrameCellsColumn(
                                                            onActivateCell: widget
                                                                .onActivateCell,
                                                            instructionDefById:
                                                                widget
                                                                    .instructionDefById,
                                                            audioPeaksFor: widget
                                                                .audioPeaksFor,
                                                            projectFps: widget
                                                                .projectFps,
                                                            onRemoveAudioClip:
                                                                widget
                                                                    .onRemoveAudioClip,
                                                            onDropMediaAsset: widget
                                                                .onDropMediaAsset,
                                                            layer:
                                                                entries[index]
                                                                    .layer,
                                                            active:
                                                                entries[index]
                                                                    .layer
                                                                    .id ==
                                                                widget
                                                                    .activeLayerId,
                                                            sectionStart:
                                                                timelineSectionStartsAt(
                                                                  widget.layers,
                                                                  entries[index]
                                                                      .layerIndex,
                                                                ),
                                                            playbackFrameCount:
                                                                widget
                                                                    .frameCount,
                                                            frameStartIndex:
                                                                frameRange
                                                                    .startIndex,
                                                            frameEndIndexExclusive:
                                                                frameRange
                                                                    .endIndexExclusive,
                                                            leadingFrameSpacerHeight:
                                                                plan.leadingFrameSpacerWidth,
                                                            trailingFrameSpacerHeight:
                                                                plan.trailingFrameSpacerWidth,
                                                            metrics: _metrics,
                                                            exposureStateForLayer:
                                                                widget
                                                                    .exposureStateForLayer,
                                                            frameNameForLayer:
                                                                widget
                                                                    .frameNameForLayer,
                                                            onSelectLayer: widget
                                                                .onSelectLayer,
                                                            onSelectFrame: widget
                                                                .onSelectFrame,
                                                            commaDrag: widget
                                                                .commaDrag,
                                                          ),
                                                  ),
                                              ],
                                            ),
                                            // The cursor layer carries the
                                            // playhead + selection visuals;
                                            // ticks repaint it alone.
                                            Positioned.fill(
                                              child: TimelineCursorLayer(
                                                axis: Axis.vertical,
                                                selectedSemanticsKey:
                                                    const ValueKey<String>(
                                                      'xsheet-selected-cell',
                                                    ),
                                                frameCursor: widget.frameCursor,
                                                rows: entries,
                                                activeLayerId:
                                                    widget.activeLayerId,
                                                frameStartIndex:
                                                    frameRange.startIndex,
                                                frameEndIndexExclusive:
                                                    frameRange
                                                        .endIndexExclusive,
                                                leadingFrameSpacerWidth: plan
                                                    .leadingFrameSpacerWidth,
                                                metrics: _metrics,
                                                exposureStateForLayer: widget
                                                    .exposureStateForLayer,
                                                crossAxisExtent:
                                                    entries.length *
                                                    _metrics.layerRowHeight,
                                              ),
                                            ),
                                            TimelineBodyCutEndBoundary(
                                              axis: Axis.vertical,
                                              left: cutEndBoundaryOffset,
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
            Row(
              children: [
                SizedBox(
                  key: const ValueKey<String>(
                    'xsheet-bottom-scrollbar-left-spacer',
                  ),
                  width:
                      _metrics.layerControlsWidth +
                      _metrics.verticalScrollbarWidth,
                  height: bottomScrollbarRailHeight,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewportWidth = constraints.hasBoundedWidth
                          ? constraints.maxWidth
                          : 0.0;

                      return TimelineHorizontalScrollbarRail(
                        key: const ValueKey<String>(
                          'xsheet-horizontal-scrollbar',
                        ),
                        controller: _layerScrollController,
                        viewportWidth: viewportWidth,
                        contentWidth: math.max(
                          columnsContentWidth,
                          _metrics.layerRowHeight,
                        ),
                        height: bottomScrollbarRailHeight,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The vertical frame-number rail: the X-sheet counterpart of the
/// horizontal grid's frame header row, sharing its styling and dim rules.
class _XSheetFrameNumberRail extends StatelessWidget {
  const _XSheetFrameNumberRail({
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.leadingFrameSpacerHeight,
    required this.trailingFrameSpacerHeight,
    required this.metrics,
    required this.onSelectFrame,
    this.isFrameCached,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerHeight;
  final double trailingFrameSpacerHeight;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

  /// Whether a frame's playback composite is warmed; drawn as the green
  /// strip along the cell edge that faces the frame cells.
  final bool Function(int frameIndex)? isFrameCached;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey<String>('xsheet-frame-number-rail'),
      children: [
        SizedBox(
          key: const ValueKey<String>('xsheet-frame-rail-leading-spacer'),
          height: leadingFrameSpacerHeight,
          width: metrics.layerControlsWidth,
        ),
        for (
          var frameIndex = frameStartIndex;
          frameIndex < frameEndIndexExclusive;
          frameIndex += 1
        )
          _FrameNumberCell(
            frameIndex: frameIndex,
            selected: frameIndex == currentFrameIndex,
            outsidePlaybackRange: frameIndex >= playbackFrameCount,
            cached:
                frameIndex < playbackFrameCount &&
                (isFrameCached?.call(frameIndex) ?? false),
            metrics: metrics,
            onSelectFrame: onSelectFrame,
          ),
        SizedBox(
          key: const ValueKey<String>('xsheet-frame-rail-trailing-spacer'),
          height: trailingFrameSpacerHeight,
          width: metrics.layerControlsWidth,
        ),
      ],
    );
  }
}

class _FrameNumberCell extends StatelessWidget {
  const _FrameNumberCell({
    required this.frameIndex,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.cached,
    required this.metrics,
    required this.onSelectFrame,
  });

  final int frameIndex;
  final bool selected;
  final bool outsidePlaybackRange;
  final bool cached;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      // Key kept from the old per-frame row so existing flows/tests hold.
      key: ValueKey<String>('xsheet-frame-row-$frameIndex'),
      onTap: () => onSelectFrame(frameIndex),
      child: Container(
        width: metrics.layerControlsWidth,
        height: metrics.frameCellWidth,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
                  colorScheme.surface,
                )
              : outsidePlaybackRange
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
              : colorScheme.surface,
          border: Border.all(
            color: outsidePlaybackRange
                ? colorScheme.outlineVariant.withValues(alpha: 0.55)
                : colorScheme.outlineVariant,
          ),
        ),
        // The Stack must FILL the cell (no Container alignment, which
        // loosens constraints and shrink-wraps it to the text) so the
        // cached strip's right edge is the rail/cells boundary — the
        // transposed twin of the horizontal header's bottom-edge strip.
        child: Stack(
          children: [
            Center(
              child: Text(
                '${frameIndex + 1}',
                style: TextStyle(
                  color: outsidePlaybackRange
                      ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                      : colorScheme.onSurface,
                ),
              ),
            ),
            // Transposed cached-range strip: the horizontal header draws it
            // along the bottom edge (facing the cells); here the cells sit
            // to the RIGHT of the rail.
            if (cached)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(
                  key: ValueKey<String>('xsheet-frame-cached-$frameIndex'),
                  width: 3,
                  color: const Color(0xFF54B435),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One layer's vertical run of frame cells: the transposed counterpart of
/// the horizontal `TimelineFrameCellsRow`, reusing the same policies.
class _XSheetFrameCellsColumn extends StatelessWidget {
  const _XSheetFrameCellsColumn({
    required this.layer,
    required this.active,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerHeight,
    required this.trailingFrameSpacerHeight,
    required this.metrics,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.projectFps = 24,
    this.onRemoveAudioClip,
    this.onDropMediaAsset,
    this.commaDrag,
    this.sectionStart = false,
  });

  final Layer layer;
  final bool active;

  /// Whether this column opens a new timesheet section; draws a heavier
  /// divider along the column's left edge.
  final bool sectionStart;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerHeight;
  final double trailingFrameSpacerHeight;
  final TimelineGridMetrics metrics;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;
  final AudioPeaks? Function(String filePath)? audioPeaksFor;
  final int projectFps;
  final void Function(LayerId layerId, int clipIndex)? onRemoveAudioClip;

  /// Links a media-browser asset to an SE block (drag-drop); null hides
  /// the drop targets.
  final void Function(LayerId layerId, int blockStartFrame, String path)?
  onDropMediaAsset;

  final TimelineCommaDragCallbacks? commaDrag;

  @override
  Widget build(BuildContext context) {
    // Instruction columns adapt their events onto the shared exposure
    // states so the cells paint the same paper blocks (Axis policy —
    // mirrors TimelineFrameCellsRow).
    TimelineCellExposureState stateAt(int frameIndex) =>
        layer.kind == LayerKind.instruction
        ? instructionCellExposureState(layer, frameIndex)
        : exposureStateForLayer(layer, frameIndex);
    final commaDrag = this.commaDrag;
    return SizedBox(
      width: metrics.layerRowHeight,
      child: Stack(
        key: ValueKey<String>('xsheet-frame-column-area-${layer.id}'),
        children: [
          Column(
            children: [
              SizedBox(
                key: ValueKey<String>(
                  'xsheet-frame-column-leading-spacer-${layer.id}',
                ),
                height: leadingFrameSpacerHeight,
                width: metrics.layerRowHeight,
              ),
              for (
                var frameIndex = frameStartIndex;
                frameIndex < frameEndIndexExclusive;
                frameIndex += 1
              )
                TimelineFrameCell(
                  layer: layer,
                  frameIndex: frameIndex,
                  active: active,
                  outsidePlaybackRange: frameIndex >= playbackFrameCount,
                  exposureState: stateAt(frameIndex),
                  exposureBlockSegment:
                      calculateTimelineExposureBlockVisualSegment(
                        previous: frameIndex == 0
                            ? null
                            : stateAt(frameIndex - 1),
                        current: stateAt(frameIndex),
                        next: stateAt(frameIndex + 1),
                      ),
                  emptyRunStart: timelineEmptyRunStartsAt(
                    current: stateAt(frameIndex),
                    previous: frameIndex == 0 ? null : stateAt(frameIndex - 1),
                  ),
                  frameName: frameNameForLayer?.call(layer, frameIndex),
                  onSelectLayer: onSelectLayer,
                  onSelectFrame: onSelectFrame,
                  onActivateCell:
                      layerKindOpensCellEditorOnDoubleTap(layer.kind)
                      ? onActivateCell
                      : null,
                  axis: Axis.vertical,
                  width: metrics.layerRowHeight,
                  height: metrics.frameCellWidth,
                  cellKeyPrefix: 'xsheet-cell',
                ),
              SizedBox(
                key: ValueKey<String>(
                  'xsheet-frame-column-trailing-spacer-${layer.id}',
                ),
                height: trailingFrameSpacerHeight,
                width: metrics.layerRowHeight,
              ),
            ],
          ),
          if (sectionStart)
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 2,
              child: IgnorePointer(
                child: Container(
                  key: ValueKey<String>(
                    'xsheet-section-divider-column-${layer.id}',
                  ),
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          // NO empty-stretch furniture here (R5-②): uncovered X-sheet cells
          // are already dark — the gray wash is print-sheet-only.
          // SE audio clips paint over the paper cells, under the writing —
          // clipped to the column's drawing blocks (no block, no waveform).
          if (layerKindUsesSeSheetCells(layer.kind) && audioPeaksFor != null)
            ...timelineRowAudioOverlays(
              layer: layer,
              frameStartIndex: frameStartIndex,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              axis: Axis.vertical,
              fps: projectFps,
              audioPeaksFor: audioPeaksFor!,
              onRemoveClip: onRemoveAudioClip == null
                  ? null
                  : (clipIndex) => onRemoveAudioClip!(layer.id, clipIndex),
              color: timelineDrawingInkColor.withValues(alpha: 0.22),
              keyPrefix: 'xsheet',
            ),
          // SE columns: the sheet's writing on the paper blocks — name box
          // at the block start plus the dialogue fitted across the span.
          if (layerKindUsesSeSheetCells(layer.kind))
            ...timelineRowSeLabelOverlays(
              layer: layer,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              axis: Axis.vertical,
              keyPrefix: 'xsheet',
            ),
          // Media-browser drops land on SE blocks (sound → block frame).
          if (layerKindUsesSeSheetCells(layer.kind) && onDropMediaAsset != null)
            ...timelineRowSeAssetDropTargets(
              layer: layer,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              axis: Axis.vertical,
              onAssetDropped: (blockStartFrame, path) =>
                  onDropMediaAsset!(layer.id, blockStartFrame, path),
              keyPrefix: 'xsheet',
            ),
          // Instruction columns: the sheet's CAM column — bar arrows or
          // the O.L bowtie on the paper block, A → B endpoint values and
          // the name snapped to the anchor cell.
          if (layer.kind == LayerKind.instruction && instructionDefById != null)
            ...timelineRowInstructionOverlays(
              layer: layer,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              axis: Axis.vertical,
              defById: instructionDefById!,
              keyPrefix: 'xsheet',
            ),
          if (commaDrag != null && layerKindHoldsDrawings(layer.kind))
            ...timelineRowBlockEdgeGrips(
              layer: layer,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              commaDrag: commaDrag,
              axis: Axis.vertical,
            ),
          if (commaDrag != null && layer.kind == LayerKind.instruction)
            ...timelineRowInstructionEdgeGrips(
              layer: layer,
              frameStartIndex: frameStartIndex,
              frameEndIndexExclusive: frameEndIndexExclusive,
              leadingFrameSpacerWidth: leadingFrameSpacerHeight,
              frameCellExtent: metrics.frameCellWidth,
              crossAxisExtent: metrics.layerRowHeight,
              commaDrag: commaDrag,
              axis: Axis.vertical,
            ),
        ],
      ),
    );
  }
}

/// One cell of the section band above the layer headers: the paper sheet's
/// group heading wrapping its columns. Display-only — section visibility
/// lives on the toolbar toggles. The band label is horizontal already (the
/// band runs along the layer axis here).
class _XSheetSectionBandCell extends StatelessWidget {
  const _XSheetSectionBandCell({required this.run, required this.extent});

  final TimelineSectionRun run;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: extent,
        height: XSheetTimelineGrid._sectionBandHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outline, width: 1),
        ),
        child: Center(
          child: Text(
            timelineSectionLabel(run.section),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LayerHeader extends StatelessWidget {
  const _LayerHeader({
    required this.layer,
    required this.active,
    required this.onSelectLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    required this.metrics,
    this.onToggleLayerMuted,
    this.sectionStart = false,
    this.hasLanes = false,
    this.lanesExpanded = false,
    this.onToggleLanes,
    this.fxEnabled = true,
    this.onToggleLayerFx,
  });

  final TimelineGridMetrics metrics;

  final Layer layer;
  final bool active;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// SE columns' speaker button (mute); null hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// Whether this column opens a new timesheet section; draws a heavier
  /// divider along the header's left edge.
  final bool sectionStart;

  /// AE-style property-lane twirl-down: layers with lanes lead their name
  /// row with a chevron (lane COLUMNS open beside the layer's). Headers
  /// without lanes skip the slot — names center per column here, so no
  /// cross-column alignment to preserve.
  final bool hasLanes;
  final bool lanesExpanded;
  final ValueChanged<LayerId>? onToggleLanes;

  /// The AE-style fx switch (session view state). Null hides it.
  final bool fxEnabled;
  final ValueChanged<LayerId>? onToggleLayerFx;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showLaneToggle = hasLanes && onToggleLanes != null;

    final header = InkWell(
      key: ValueKey<String>('xsheet-layer-header-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        width: metrics.layerRowHeight,
        height: XSheetTimelineGrid._headerHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: active ? colorScheme.secondary : colorScheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Semantics(
          key: active ? const ValueKey<String>('xsheet-selected-layer') : null,
          label: active ? 'selected layer' : 'layer',
          container: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  if (showLaneToggle)
                    InkWell(
                      key: ValueKey<String>('xsheet-lane-toggle-${layer.id}'),
                      onTap: () => onToggleLanes!(layer.id),
                      child: SizedBox(
                        width: 16,
                        height: 24,
                        child: Icon(
                          lanesExpanded
                              ? Icons.arrow_drop_down
                              : Icons.arrow_right,
                          size: 16,
                        ),
                      ),
                    ),
                  // Timesheet + mark chips lead the name; ineligible layers
                  // keep empty slots so names align across columns.
                  if (layerKindEligibleForTimesheetToggle(layer.kind))
                    LayerTimesheetToggleButton(
                      keyPrefix: 'xsheet',
                      layerId: layer.id,
                      onTimesheet: layer.onTimesheet,
                      onToggle: onToggleLayerTimesheet,
                    )
                  else
                    const SizedBox(width: layerTimesheetSlotWidth),
                  const SizedBox(width: 4),
                  LayerMarkChip(
                    keyPrefix: 'xsheet',
                    layerId: layer.id,
                    mark: layer.mark,
                    onMarkSelected: onLayerMarkSelected,
                  ),
                  Expanded(
                    child: InkWell(
                      key: ValueKey<String>('xsheet-layer-name-${layer.id}'),
                      onTap: () => onSelectLayer(layer.id),
                      child: Text(
                        layer.name,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: active ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                  // Balance the leading chips so the name stays centered.
                  SizedBox(
                    width:
                        layerTimesheetSlotWidth +
                        layerMarkSlotWidth +
                        4 +
                        (showLaneToggle ? 16 : 0),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onToggleLayerFx != null &&
                      layerKindShowsFxToggle(layer.kind))
                    LayerFxToggleButton(
                      keyPrefix: 'xsheet',
                      layerId: layer.id,
                      fxEnabled: fxEnabled,
                      onToggle: onToggleLayerFx!,
                    ),
                  IconButton(
                    key: ValueKey<String>(
                      'xsheet-layer-visibility-${layer.id}',
                    ),
                    tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      layer.isVisible ? Icons.visibility : Icons.visibility_off,
                      size: 16,
                    ),
                    onPressed: () => onToggleLayerVisibility(layer.id),
                  ),
                  // SE columns carry the mute speaker beside the eye. Tight
                  // SizedBox: the M3 IconButton otherwise inflates to the
                  // 48px tap target, overflowing the header column.
                  if (layer.kind == LayerKind.se && onToggleLayerMuted != null)
                    SizedBox(
                      width: 24,
                      height: 28,
                      child: IconButton(
                        key: ValueKey<String>('xsheet-layer-mute-${layer.id}'),
                        tooltip: layer.muted ? 'Unmute layer' : 'Mute layer',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 28,
                        ),
                        icon: Icon(
                          layer.muted ? Icons.volume_off : Icons.volume_up,
                          size: 16,
                        ),
                        onPressed: () => onToggleLayerMuted!(layer.id),
                      ),
                    ),
                  // The camera column's slider drives the camera-view DIM
                  // opacity (unified layer controls).
                  if (layerKindShowsOpacityControl(layer.kind)) ...[
                    Expanded(
                      child: Slider(
                        key: ValueKey<String>(
                          'xsheet-layer-opacity-${layer.id}',
                        ),
                        min: 0,
                        max: 1,
                        value: layer.opacity.clamp(0.0, 1.0).toDouble(),
                        onChanged: (opacity) =>
                            onLayerOpacityChanged(layer.id, opacity),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${(layer.opacity * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ] else
                    const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!sectionStart) {
      return header;
    }
    return Stack(
      children: [
        header,
        Positioned(
          top: 0,
          bottom: 0,
          left: 0,
          width: 2,
          child: IgnorePointer(
            child: Container(
              key: ValueKey<String>(
                'xsheet-section-divider-header-${layer.id}',
              ),
              color: colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.height,
    required this.child,
  });

  final double width;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}
