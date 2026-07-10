import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_drag_preview.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_cursor_layer.dart';
import 'timeline_frame_grid_stack.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_frame_scroll_viewport.dart';
import 'timeline_frame_ruler.dart';
import 'timeline_frame_rows_scroll_body.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_horizontal_offset_policy.dart';
import 'timeline_horizontal_scrollbar_rail.dart';
import 'property_lane_model.dart';
import 'se_audio_lane.dart' show AudioOffsetDragCallbacks;
import 'timeline_lane_rows.dart';
import 'timeline_layer_controls_header.dart';
import 'timeline_layer_frame_body_layout.dart';
import 'timeline_zoom_anchor_policy.dart';
import 'timeline_layer_controls_row.dart';
import 'timeline_panel_virtualization_adapter.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';
import 'timeline_section_bracket_rail.dart';
import 'timeline_vertical_scrollbar_rail.dart';
import 'timeline_visible_range.dart';

class LayerTimelineGrid extends StatefulWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.frameCursor,
    this.cacheProgress,
    required this.playbackFrameCount,
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
    this.layerFxEnabledOf,
    this.onToggleLayerFx,
    required this.onLayerMarkSelected,
    this.onToggleLayerMuted,
    this.commaDrag,
    this.isFrameCached,
    this.metrics = TimelineGridMetrics.defaults,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.lanesForLayer,
    this.laneEdit,
    this.onToggleLaneGroup,
    this.hiddenSections = const {},
    this.dragPreview,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;

  /// The session's edit-drag preview channel: a comma-drag step rebuilds
  /// only the dragged layer's row (its gate) and the cursor overlay —
  /// never this grid.
  final ValueListenable<TimelineDragPreview?>? dragPreview;

  /// The frame cursor (editing playhead, or the playback position while
  /// playing). ONLY the cursor layer, the ruler and the lane labels
  /// subscribe — a tick never rebuilds the grid or its cells (the
  /// playback-performance architecture).
  final ValueListenable<int> frameCursor;

  /// Repaints the ruler's cached-range green strip as frames warm; never
  /// rebuilds anything else.
  final Listenable? cacheProgress;

  final int playbackFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  /// Ruler-scrub path: per-move frames go to [onScrubFrame] (cursor-only,
  /// no commit) and the pointer's release fires [onScrubEnd] to commit
  /// once. Null falls back to [onSelectFrame] per move.
  final ValueChanged<int>? onScrubFrame;
  final VoidCallback? onScrubEnd;

  /// Double-tap cell editor hook (SE label dialog; see
  /// [layerKindOpensCellEditorOnDoubleTap]).
  final void Function(LayerId layerId, int frameIndex)? onActivateCell;

  /// Resolves instruction ids to defs for CAM row chips.
  final CameraInstructionDef? Function(String instructionId)?
  instructionDefById;

  /// Waveform peaks for SE rows' audio clips + the removal hook.
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

  /// The AE-style layer fx switch (session view state); null hides it.
  final bool Function(LayerId layerId)? layerFxEnabledOf;
  final ValueChanged<LayerId>? onToggleLayerFx;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

  /// SE rows' speaker button (mute); null hides it.
  final ValueChanged<LayerId>? onToggleLayerMuted;

  /// Comma-drag hooks for the block edge grips (shared policy with the
  /// X-sheet); null hides the grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// Cached-range resolver for the ruler's green strip.
  final bool Function(int frameIndex)? isFrameCached;

  /// Grid geometry; the frame-axis cell width carries the panel zoom.
  final TimelineGridMetrics metrics;

  /// AE-style property lanes: layers whose twirl-down is open, the toggle,
  /// and the lane provider (generic — transform lanes now, FX lanes later).
  final Set<LayerId> expandedLaneLayerIds;
  final ValueChanged<LayerId>? onToggleLayerLanes;
  final List<PropertyLaneRow> Function(Layer layer)? lanesForLayer;

  /// Lane key editing hooks (navigator toggle, marker drags, hold/delete).
  final PropertyLaneEditCallbacks? laneEdit;

  /// Group headers: tapping twirls the group's member lanes (AE collapse).
  final void Function(Layer layer, PropertyLaneRow lane)? onToggleLaneGroup;

  /// Sections folded to one stub row (SE/camera; drawing never folds) and
  /// the gutter-label toggle.
  /// Sections hidden from the grid entirely (toolbar visibility toggles).
  final Set<TimelineSection> hiddenSections;

  @override
  State<LayerTimelineGrid> createState() => _LayerTimelineGridState();
}

class _LayerTimelineGridState extends State<LayerTimelineGrid> {
  TimelineGridMetrics get _metrics => widget.metrics;

  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;
  double _horizontalScrollOffset = 0;
  double _verticalScrollOffset = 0;
  double _lastEffectiveHorizontalScrollOffset = 0;
  double? _scheduledHorizontalOffsetCorrection;
  int _endlessTrailingFrames = 0;
  final GlobalKey _rulerScrubViewportKey = GlobalKey();
  int? _lastRulerScrubbedFrameIndex;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
    _horizontalScrollController.addListener(_handleHorizontalScroll);
    _verticalScrollController.addListener(_handleVerticalScroll);
  }

  @override
  void didUpdateWidget(covariant LayerTimelineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Zoom-around-playhead: the playhead stays put on screen through zoom
    // when visible; otherwise the leading-edge frame anchors.
    final oldCell = oldWidget.metrics.frameCellWidth;
    final newCell = widget.metrics.frameCellWidth;
    if (oldCell != newCell && _horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(
        zoomAnchoredScrollOffset(
          oldOffset: _horizontalScrollController.offset,
          oldPixelsPerFrame: oldCell,
          newPixelsPerFrame: newCell,
          viewportExtent:
              _horizontalScrollController.position.viewportDimension,
          anchorFrame: widget.frameCursor.value,
        ),
      );
    }
  }

  @override
  void dispose() {
    _horizontalScrollController
      ..removeListener(_handleHorizontalScroll)
      ..dispose();
    _verticalScrollController
      ..removeListener(_handleVerticalScroll)
      ..dispose();
    super.dispose();
  }

  /// Layer-axis virtualization: re-plan only when the scroll crosses a
  /// row boundary (the ≥2-row overscan absorbs sub-row movement).
  void _handleVerticalScroll() {
    final offset = _verticalScrollController.hasClients
        ? _verticalScrollController.offset
        : 0.0;
    if (offset == _verticalScrollOffset) {
      return;
    }
    final rowExtent = _metrics.layerRowHeight;
    final oldBucket = (_verticalScrollOffset / rowExtent).floor();
    final newBucket = (offset / rowExtent).floor();
    _verticalScrollOffset = offset;
    if (oldBucket != newBucket) {
      setState(() {});
    }
  }

  void _handleHorizontalScroll() {
    final offset = _horizontalScrollController.hasClients
        ? _horizontalScrollController.offset
        : 0.0;
    if (offset == _horizontalScrollOffset) {
      return;
    }
    final nextTrailingFrames = _horizontalScrollController.hasClients
        ? endlessTrailingFrames(
            baseFrameCount: _visibleFrameCount,
            currentTrailingFrames: _endlessTrailingFrames,
            scrollOffset: offset,
            viewportExtent:
                _horizontalScrollController.position.viewportDimension,
            frameCellExtent: _metrics.frameCellWidth,
          )
        : _endlessTrailingFrames;
    setState(() {
      _horizontalScrollOffset = offset;
      _endlessTrailingFrames = nextTrailingFrames;
    });
  }

  TimelineFrameRange get _frameRangePolicy =>
      TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: widget.playbackFrameCount,
        minimumVisibleFrameCells: _metrics.minimumVisibleFrameCells,
      );

  int get _visibleFrameCount => _frameRangePolicy.visibleFrameCount;

  /// Render extent: the endless-axis runway extends past the base count as
  /// the user scrolls. Interaction clamps stay on [_visibleFrameCount].
  int get _renderedFrameCount => _visibleFrameCount + _endlessTrailingFrames;

  double _effectiveHorizontalScrollOffset({
    required double requestedOffset,
    required double viewportWidth,
  }) {
    final totalFrameContentWidth =
        _renderedFrameCount * _metrics.frameCellWidth;

    return resolveTimelineHorizontalOffset(
      requestedOffset: requestedOffset,
      totalContentWidth: totalFrameContentWidth,
      viewportWidth: viewportWidth,
    ).effectiveOffset;
  }

  void _synchronizeHorizontalScrollController(double effectiveOffset) {
    if (!_horizontalScrollController.hasClients ||
        _horizontalScrollController.offset == effectiveOffset ||
        _scheduledHorizontalOffsetCorrection == effectiveOffset) {
      return;
    }

    _scheduledHorizontalOffsetCorrection = effectiveOffset;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalScrollController.hasClients) {
        _scheduledHorizontalOffsetCorrection = null;
        return;
      }

      final maxScrollExtent =
          _horizontalScrollController.position.maxScrollExtent;
      final targetOffset = effectiveOffset
          .clamp(0.0, maxScrollExtent)
          .toDouble();

      _scheduledHorizontalOffsetCorrection = null;
      if (_horizontalScrollController.offset != targetOffset) {
        _horizontalScrollController.jumpTo(targetOffset);
      }
    });
  }

  int? _frameIndexForRulerLocalX(double localX) {
    return frameIndexFromLocalX(
      localX: localX,
      horizontalScrollOffset: _lastEffectiveHorizontalScrollOffset,
      frameCellWidth: _metrics.frameCellWidth,
      visibleFrameCount: _visibleFrameCount,
    );
  }

  void _selectClampedFrameFromRuler(int frameIndex) {
    final clampedFrameIndex = clampFrameIndex(
      frameIndex: frameIndex,
      visibleFrameCount: _visibleFrameCount,
    );
    if (clampedFrameIndex == null ||
        clampedFrameIndex == _lastRulerScrubbedFrameIndex) {
      return;
    }

    _lastRulerScrubbedFrameIndex = clampedFrameIndex;
    (widget.onScrubFrame ?? widget.onSelectFrame)(clampedFrameIndex);
  }

  /// The scrub gesture's release (raw pointer up/cancel — fires for taps
  /// AND drags, wherever the pointer ends up). Tracking is NOT reset here
  /// so the ruler InkWell's trailing onTap stays deduplicated.
  void _endRulerScrub() {
    widget.onScrubEnd?.call();
  }

  double? _rulerViewportLocalXFromGlobal(Offset globalPosition) {
    final renderObject = _rulerScrubViewportKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }

    return renderObject.globalToLocal(globalPosition).dx;
  }

  void _selectFrameFromRulerGlobalPosition(Offset globalPosition) {
    final localX = _rulerViewportLocalXFromGlobal(globalPosition);
    if (localX == null) {
      return;
    }

    final frameIndex = _frameIndexForRulerLocalX(localX);
    if (frameIndex == null) {
      return;
    }

    _selectClampedFrameFromRuler(frameIndex);
  }

  void _resetRulerScrubTracking() {
    _lastRulerScrubbedFrameIndex = null;
  }

  List<PropertyLaneRow> _lanesFor(Layer layer) =>
      widget.lanesForLayer?.call(layer) ?? const [];

  /// One rail row (layer controls or a lane label), extracted so the
  /// windowed rail loop stays readable.
  Widget _railRow(TimelineDisplayRow row) {
    if (row.isLane) {
      // Lane labels show the value AT the cursor: subscribe here so a
      // tick rebuilds only these small cells.
      return ValueListenableBuilder<int>(
        valueListenable: widget.frameCursor,
        builder: (context, cursorFrame, _) => TimelineLaneControlsRow(
          layer: row.layer,
          lane: row.lane!,
          metrics: _metrics,
          currentFrameIndex: cursorFrame,
          onSelectFrame: widget.onSelectFrame,
          laneEdit: widget.laneEdit,
          onToggleLaneGroup: widget.onToggleLaneGroup,
        ),
      );
    }
    return TimelineLayerControlsRow(
      layer: row.layer,
      active: row.layer.id == widget.activeLayerId,
      sectionStart: timelineSectionStartsAt(widget.layers, row.layerIndex),
      metrics: _metrics,
      onSelectLayer: widget.onSelectLayer,
      onToggleLayerVisibility: widget.onToggleLayerVisibility,
      onLayerOpacityChanged: widget.onLayerOpacityChanged,
      onToggleLayerTimesheet: widget.onToggleLayerTimesheet,
      fxEnabled: widget.layerFxEnabledOf?.call(row.layer.id) ?? true,
      onToggleLayerFx: widget.onToggleLayerFx,
      onLayerMarkSelected: widget.onLayerMarkSelected,
      onToggleLayerMuted: widget.onToggleLayerMuted,
      hasLanes: _lanesFor(row.layer).isNotEmpty,
      lanesExpanded: widget.expandedLaneLayerIds.contains(row.layer.id),
      onToggleLanes: widget.onToggleLayerLanes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const bottomScrollbarRailHeight = 16.0;
    final rows = buildTimelineDisplayRows(
      layers: widget.layers,
      expandedLayerIds: widget.expandedLaneLayerIds,
      lanesForLayer: _lanesFor,
      hiddenSections: widget.hiddenSections,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - bottomScrollbarRailHeight)
                  .clamp(0.0, double.infinity)
                  .toDouble()
            : 0.0;

        return KeyedSubtree(
          key: const ValueKey<String>('timeline-scrollbar-area'),
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final headerHeight = _metrics.layerRowHeight;
                    final bodyViewportHeight = constraints.hasBoundedHeight
                        ? (constraints.maxHeight - headerHeight)
                              .clamp(0.0, double.infinity)
                              .toDouble()
                        : viewportHeight;
                    // Rows are no longer uniformly tall: collapsed sections
                    // fold to a slim strip.
                    final verticalContentHeight = math.max(
                      timelineDisplayRowsExtent(rows, _metrics),
                      _metrics.layerRowHeight,
                    );
                    // Layer-axis window: only the rows in view (plus
                    // overscan) are built; spacers preserve the scroll
                    // geometry of the rest. The cursor and preview
                    // overlays keep the FULL row list — their offsets are
                    // absolute. Without a real viewport measurement
                    // (unbounded hosts) every row builds, like before.
                    final rowWindow = bodyViewportHeight <= 0
                        ? TimelineVisibleRange(
                            startIndex: 0,
                            endIndexExclusive: rows.length,
                          )
                        : calculateVisibleIndexRange(
                            scrollOffset: _verticalScrollOffset,
                            viewportExtent: bodyViewportHeight,
                            itemExtent: _metrics.layerRowHeight,
                            itemCount: rows.length,
                          );
                    final windowRows = rows.sublist(
                      rowWindow.startIndex,
                      rowWindow.endIndexExclusive,
                    );
                    final leadingRowSpacerHeight =
                        rowWindow.startIndex * _metrics.layerRowHeight;
                    final trailingRowSpacerHeight =
                        (rows.length - rowWindow.endIndexExclusive) *
                        _metrics.layerRowHeight;

                    return Column(
                      children: [
                        KeyedSubtree(
                          key: const ValueKey<String>(
                            'timeline-sticky-header-row',
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TimelineLayerControlsHeader(
                                metrics: _metrics,
                                onAddLayer: widget.onAddLayer,
                              ),
                              TimelineVerticalScrollbarSlot(
                                width: _metrics.verticalScrollbarWidth,
                                height: headerHeight,
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final viewportWidth =
                                        constraints.hasBoundedWidth
                                        ? constraints.maxWidth
                                        : 0.0;
                                    final effectiveHorizontalScrollOffset =
                                        _effectiveHorizontalScrollOffset(
                                          requestedOffset:
                                              _horizontalScrollOffset,
                                          viewportWidth: viewportWidth,
                                        );
                                    _lastEffectiveHorizontalScrollOffset =
                                        effectiveHorizontalScrollOffset;
                                    _synchronizeHorizontalScrollController(
                                      effectiveHorizontalScrollOffset,
                                    );
                                    final plan =
                                        calculateLayerTimelineGridVirtualizationPlan(
                                          horizontalScrollOffset:
                                              effectiveHorizontalScrollOffset,
                                          verticalScrollOffset: 0,
                                          viewportWidth: viewportWidth,
                                          viewportHeight: viewportHeight,
                                          visibleFrameCount:
                                              _renderedFrameCount,
                                          layerCount: rows.length,
                                          metrics: _metrics,
                                        );
                                    final frameRange = plan.frameRange;

                                    return Listener(
                                      key: const ValueKey<String>(
                                        'timeline-frame-ruler-scrub-area',
                                      ),
                                      behavior: HitTestBehavior.translucent,
                                      onPointerDown: (event) {
                                        _resetRulerScrubTracking();
                                        _selectFrameFromRulerGlobalPosition(
                                          event.position,
                                        );
                                      },
                                      onPointerUp: (_) => _endRulerScrub(),
                                      onPointerCancel: (_) => _endRulerScrub(),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onHorizontalDragStart: (details) {
                                          _selectFrameFromRulerGlobalPosition(
                                            details.globalPosition,
                                          );
                                        },
                                        onHorizontalDragUpdate: (details) {
                                          _selectFrameFromRulerGlobalPosition(
                                            details.globalPosition,
                                          );
                                        },
                                        onHorizontalDragEnd: (_) =>
                                            _resetRulerScrubTracking(),
                                        onHorizontalDragCancel:
                                            _resetRulerScrubTracking,
                                        child: SizedBox(
                                          key: _rulerScrubViewportKey,
                                          width: viewportWidth,
                                          height: headerHeight,
                                          child: ClipRect(
                                            child: OverflowBox(
                                              alignment: Alignment.topLeft,
                                              minWidth:
                                                  plan.totalFrameContentWidth,
                                              maxWidth:
                                                  plan.totalFrameContentWidth,
                                              minHeight: headerHeight,
                                              maxHeight: headerHeight,
                                              child: Transform.translate(
                                                offset: Offset(
                                                  -effectiveHorizontalScrollOffset,
                                                  0,
                                                ),
                                                child: SizedBox(
                                                  width: plan
                                                      .totalFrameContentWidth,
                                                  height: headerHeight,
                                                  // The ruler subscribes to
                                                  // the cursor + cache
                                                  // progress ITSELF: ticks
                                                  // and warming frames
                                                  // repaint this subtree
                                                  // only.
                                                  child: ListenableBuilder(
                                                    listenable:
                                                        Listenable.merge([
                                                          widget.frameCursor,
                                                          ?widget.cacheProgress,
                                                        ]),
                                                    builder: (context, _) => TimelineFrameRuler(
                                                      frameStartIndex:
                                                          frameRange.startIndex,
                                                      frameEndIndexExclusive:
                                                          frameRange
                                                              .endIndexExclusive,
                                                      currentFrameIndex: widget
                                                          .frameCursor
                                                          .value,
                                                      playbackFrameCount: widget
                                                          .playbackFrameCount,
                                                      leadingFrameSpacerWidth: plan
                                                          .leadingFrameSpacerWidth,
                                                      trailingFrameSpacerWidth:
                                                          plan.trailingFrameSpacerWidth,
                                                      metrics: _metrics,
                                                      onSelectFrame:
                                                          _selectClampedFrameFromRuler,
                                                      isFrameCached:
                                                          widget.isFrameCached,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              SingleChildScrollView(
                                key: const ValueKey<String>(
                                  'timeline-vertical-scroll-viewport',
                                ),
                                controller: _verticalScrollController,
                                child: KeyedSubtree(
                                  key: const ValueKey<String>(
                                    'timeline-scrollable-body',
                                  ),
                                  child: TimelineLayerFrameBodyLayout(
                                    layerControlsRail: KeyedSubtree(
                                      key: const ValueKey<String>(
                                        'timeline-layer-controls-rail',
                                      ),
                                      child: KeyedSubtree(
                                        key: const ValueKey<String>(
                                          'timeline-layer-rows-scroll-body',
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Timesheet-style bracket: one
                                            // enclosing gutter cell per
                                            // section, wrapping its rows.
                                            TimelineSectionBracketRail(
                                              rows: rows,
                                              metrics: _metrics,
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // The rail is windowed with
                                                // the same layer-axis slice
                                                // as the frame rows; keys
                                                // keep row state glued to
                                                // its layer through window
                                                // shifts.
                                                if (leadingRowSpacerHeight > 0)
                                                  SizedBox(
                                                    height:
                                                        leadingRowSpacerHeight,
                                                  ),
                                                for (final row in windowRows)
                                                  KeyedSubtree(
                                                    key: ValueKey<String>(
                                                      'timeline-rail-row-'
                                                      '${row.layer.id}-'
                                                      '${row.lane?.laneId ?? 'row'}',
                                                    ),
                                                    child: _railRow(row),
                                                  ),
                                                if (trailingRowSpacerHeight > 0)
                                                  SizedBox(
                                                    height:
                                                        trailingRowSpacerHeight,
                                                  ),
                                                if (widget.layers.isEmpty)
                                                  SizedBox(
                                                    width:
                                                        _metrics
                                                            .layerControlsWidth -
                                                        _metrics
                                                            .sectionLabelGutterWidth,
                                                    height:
                                                        _metrics.layerRowHeight,
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      child: Text(
                                                        'No layers',
                                                        style: TextStyle(
                                                          color: colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    verticalScrollbarSlot: SizedBox(
                                      width: _metrics.verticalScrollbarWidth,
                                      height: verticalContentHeight,
                                    ),
                                    frameGridArea: Expanded(
                                      child: KeyedSubtree(
                                        key: const ValueKey<String>(
                                          'timeline-frame-grid-area',
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final viewportWidth =
                                                constraints.hasBoundedWidth
                                                ? constraints.maxWidth
                                                : 0.0;
                                            final effectiveHorizontalScrollOffset =
                                                _effectiveHorizontalScrollOffset(
                                                  requestedOffset:
                                                      _horizontalScrollOffset,
                                                  viewportWidth: viewportWidth,
                                                );
                                            _lastEffectiveHorizontalScrollOffset =
                                                effectiveHorizontalScrollOffset;
                                            _synchronizeHorizontalScrollController(
                                              effectiveHorizontalScrollOffset,
                                            );
                                            final plan =
                                                calculateLayerTimelineGridVirtualizationPlan(
                                                  horizontalScrollOffset:
                                                      effectiveHorizontalScrollOffset,
                                                  verticalScrollOffset: 0,
                                                  viewportWidth: viewportWidth,
                                                  viewportHeight:
                                                      viewportHeight,
                                                  visibleFrameCount:
                                                      _renderedFrameCount,
                                                  layerCount: rows.length,
                                                  metrics: _metrics,
                                                );
                                            final frameRange = plan.frameRange;

                                            return TimelineFrameScrollViewport(
                                              controller:
                                                  _horizontalScrollController,
                                              contentWidth:
                                                  plan.totalFrameContentWidth,
                                              contentHeight:
                                                  verticalContentHeight,
                                              child: TimelineFrameGridStack(
                                                rowsBody: TimelineFrameRowsScrollBody(
                                                  layers: widget.layers,
                                                  rows: windowRows,
                                                  leadingLayerSpacerHeight:
                                                      leadingRowSpacerHeight,
                                                  trailingLayerSpacerHeight:
                                                      trailingRowSpacerHeight,
                                                  dragPreview:
                                                      widget.dragPreview,
                                                  activeLayerId:
                                                      widget.activeLayerId,
                                                  playbackFrameCount:
                                                      widget.playbackFrameCount,
                                                  frameStartIndex:
                                                      frameRange.startIndex,
                                                  frameEndIndexExclusive:
                                                      frameRange
                                                          .endIndexExclusive,
                                                  leadingFrameSpacerWidth: plan
                                                      .leadingFrameSpacerWidth,
                                                  trailingFrameSpacerWidth: plan
                                                      .trailingFrameSpacerWidth,
                                                  totalFrameContentWidth: plan
                                                      .totalFrameContentWidth,
                                                  metrics: _metrics,
                                                  exposureStateForLayer: widget
                                                      .exposureStateForLayer,
                                                  frameNameForLayer:
                                                      widget.frameNameForLayer,
                                                  onSelectLayer:
                                                      widget.onSelectLayer,
                                                  onSelectFrame:
                                                      widget.onSelectFrame,
                                                  onActivateCell:
                                                      widget.onActivateCell,
                                                  instructionDefById:
                                                      widget.instructionDefById,
                                                  audioPeaksFor:
                                                      widget.audioPeaksFor,
                                                  projectFps: widget.projectFps,
                                                  onRemoveAudioClip:
                                                      widget.onRemoveAudioClip,
                                                  onDropMediaAsset:
                                                      widget.onDropMediaAsset,
                                                  onSetAudioClipOffset: widget
                                                      .onSetAudioClipOffset,
                                                  audioOffsetDrag:
                                                      widget.audioOffsetDrag,
                                                  onSetAudioClipFades: widget
                                                      .onSetAudioClipFades,
                                                  onSetAudioClipGain:
                                                      widget.onSetAudioClipGain,
                                                  commaDrag: widget.commaDrag,
                                                  laneEdit: widget.laneEdit,
                                                ),
                                                cutEndBoundaryLeft:
                                                    timelineCutEndBoundaryX(
                                                      playbackFrameCount: widget
                                                          .playbackFrameCount,
                                                      metrics: _metrics,
                                                    ),
                                                // The cursor layer decides
                                                // per frame what to show —
                                                // the slot itself is static
                                                // so ticks rebuild nothing
                                                // here.
                                                showPlayhead: true,
                                                playheadWidth:
                                                    plan.totalFrameContentWidth,
                                                playhead: TimelineCursorLayer(
                                                  frameCursor:
                                                      widget.frameCursor,
                                                  dragPreview:
                                                      widget.dragPreview,
                                                  rows: rows,
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
                                                      verticalContentHeight,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: _metrics.layerControlsWidth,
                                top: 0,
                                bottom: 0,
                                width: _metrics.verticalScrollbarWidth,
                                child: TimelineVerticalScrollbarRail(
                                  controller: _verticalScrollController,
                                  viewportHeight: bodyViewportHeight,
                                  contentHeight: verticalContentHeight,
                                  width: _metrics.verticalScrollbarWidth,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                children: [
                  SizedBox(
                    key: const ValueKey<String>(
                      'timeline-bottom-scrollbar-left-spacer',
                    ),
                    width: _metrics.layerControlsWidth,
                    height: bottomScrollbarRailHeight,
                  ),
                  SizedBox(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-bottom-spacer',
                    ),
                    width: _metrics.verticalScrollbarWidth,
                    height: bottomScrollbarRailHeight,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : 0.0;
                        final effectiveFrameCount = _renderedFrameCount;
                        final contentWidth =
                            effectiveFrameCount * _metrics.frameCellWidth;

                        return TimelineHorizontalScrollbarRail(
                          key: const ValueKey<String>(
                            'timeline-horizontal-scrollbar',
                          ),
                          controller: _horizontalScrollController,
                          viewportWidth: viewportWidth,
                          contentWidth: contentWidth,
                          height: bottomScrollbarRailHeight,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
