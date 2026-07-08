import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/camera_instruction.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_mark.dart';
import '../../services/audio/audio_peaks_extractor.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_grid_stack.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_frame_scroll_viewport.dart';
import 'timeline_frame_ruler.dart';
import 'timeline_frame_rows_scroll_body.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_horizontal_offset_policy.dart';
import 'timeline_horizontal_scrollbar_rail.dart';
import 'property_lane_model.dart';
import 'timeline_lane_rows.dart';
import 'timeline_layer_controls_header.dart';
import 'timeline_layer_frame_body_layout.dart';
import 'timeline_layer_controls_row.dart';
import 'timeline_panel_virtualization_adapter.dart';
import 'timeline_playhead.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';
import 'timeline_section_stub_rows.dart';
import 'timeline_vertical_scrollbar_rail.dart';

class LayerTimelineGrid extends StatefulWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    this.onActivateCell,
    this.instructionDefById,
    this.audioPeaksFor,
    this.projectFps = 24,
    this.onRemoveAudioClip,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    required this.onToggleLayerTimesheet,
    required this.onLayerMarkSelected,
    this.commaDrag,
    this.isFrameCached,
    this.metrics = TimelineGridMetrics.defaults,
    this.expandedLaneLayerIds = const {},
    this.onToggleLayerLanes,
    this.lanesForLayer,
    this.laneEdit,
    this.collapsedSections = const {},
    this.onToggleSection,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

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
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;
  final ValueChanged<LayerId> onToggleLayerTimesheet;
  final void Function(LayerId layerId, LayerMark mark) onLayerMarkSelected;

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

  /// Sections folded to one stub row (SE/camera; drawing never folds) and
  /// the gutter-label toggle.
  final Set<TimelineSection> collapsedSections;
  final ValueChanged<TimelineSection>? onToggleSection;

  @override
  State<LayerTimelineGrid> createState() => _LayerTimelineGridState();
}

class _LayerTimelineGridState extends State<LayerTimelineGrid> {
  TimelineGridMetrics get _metrics => widget.metrics;

  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;
  double _horizontalScrollOffset = 0;
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
  }

  @override
  void didUpdateWidget(covariant LayerTimelineGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the frame at the viewport's left edge anchored through zoom.
    final oldCell = oldWidget.metrics.frameCellWidth;
    final newCell = widget.metrics.frameCellWidth;
    if (oldCell != newCell && _horizontalScrollController.hasClients) {
      _horizontalScrollController.jumpTo(
        (_horizontalScrollController.offset * newCell / oldCell).clamp(
          0.0,
          double.maxFinite,
        ),
      );
    }
  }

  @override
  void dispose() {
    _horizontalScrollController
      ..removeListener(_handleHorizontalScroll)
      ..dispose();
    _verticalScrollController.dispose();
    super.dispose();
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
    widget.onSelectFrame(clampedFrameIndex);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const bottomScrollbarRailHeight = 16.0;
    final rows = buildTimelineDisplayRows(
      layers: widget.layers,
      expandedLayerIds: widget.expandedLaneLayerIds,
      lanesForLayer: _lanesFor,
      collapsedSections: widget.collapsedSections,
    );
    int sectionLayerCount(TimelineSection section) => widget.layers
        .where((layer) => timelineSectionForLayerKind(layer.kind) == section)
        .length;

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
                                                  child: TimelineFrameRuler(
                                                    frameStartIndex:
                                                        frameRange.startIndex,
                                                    frameEndIndexExclusive:
                                                        frameRange
                                                            .endIndexExclusive,
                                                    currentFrameIndex: widget
                                                        .currentFrameIndex,
                                                    playbackFrameCount: widget
                                                        .playbackFrameCount,
                                                    leadingFrameSpacerWidth: plan
                                                        .leadingFrameSpacerWidth,
                                                    trailingFrameSpacerWidth: plan
                                                        .trailingFrameSpacerWidth,
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
                                              onToggleSection:
                                                  widget.onToggleSection,
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                for (
                                                  var rowIndex = 0;
                                                  rowIndex < rows.length;
                                                  rowIndex += 1
                                                )
                                                  rows[rowIndex].isSectionStub
                                                      ? TimelineSectionStubRailRow(
                                                          section:
                                                              rows[rowIndex]
                                                                  .stubSection!,
                                                          layerCount:
                                                              sectionLayerCount(
                                                                rows[rowIndex]
                                                                    .stubSection!,
                                                              ),
                                                          metrics: _metrics,
                                                          onToggleSection:
                                                              widget.onToggleSection ==
                                                                  null
                                                              ? null
                                                              : () => widget.onToggleSection!(
                                                                  rows[rowIndex]
                                                                      .stubSection!,
                                                                ),
                                                        )
                                                      : rows[rowIndex].isLane
                                                      ? TimelineLaneControlsRow(
                                                          layer: rows[rowIndex]
                                                              .layer,
                                                          lane: rows[rowIndex]
                                                              .lane!,
                                                          metrics: _metrics,
                                                          currentFrameIndex: widget
                                                              .currentFrameIndex,
                                                          onSelectFrame: widget
                                                              .onSelectFrame,
                                                          laneEdit:
                                                              widget.laneEdit,
                                                        )
                                                      : TimelineLayerControlsRow(
                                                          layer: rows[rowIndex]
                                                              .layer,
                                                          active:
                                                              rows[rowIndex]
                                                                  .layer
                                                                  .id ==
                                                              widget
                                                                  .activeLayerId,
                                                          sectionStart:
                                                              timelineSectionStartsAt(
                                                                widget.layers,
                                                                rows[rowIndex]
                                                                    .layerIndex,
                                                              ),
                                                          metrics: _metrics,
                                                          onSelectLayer: widget
                                                              .onSelectLayer,
                                                          onToggleLayerVisibility:
                                                              widget
                                                                  .onToggleLayerVisibility,
                                                          onLayerOpacityChanged:
                                                              widget
                                                                  .onLayerOpacityChanged,
                                                          onToggleLayerTimesheet:
                                                              widget
                                                                  .onToggleLayerTimesheet,
                                                          onLayerMarkSelected:
                                                              widget
                                                                  .onLayerMarkSelected,
                                                          hasLanes: _lanesFor(
                                                            rows[rowIndex]
                                                                .layer,
                                                          ).isNotEmpty,
                                                          lanesExpanded: widget
                                                              .expandedLaneLayerIds
                                                              .contains(
                                                                rows[rowIndex]
                                                                    .layer
                                                                    .id,
                                                              ),
                                                          onToggleLanes: widget
                                                              .onToggleLayerLanes,
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
                                                  rows: rows,
                                                  activeLayerId:
                                                      widget.activeLayerId,
                                                  currentFrameIndex:
                                                      widget.currentFrameIndex,
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
                                                  commaDrag: widget.commaDrag,
                                                  laneEdit: widget.laneEdit,
                                                ),
                                                cutEndBoundaryLeft:
                                                    timelineCutEndBoundaryX(
                                                      playbackFrameCount: widget
                                                          .playbackFrameCount,
                                                      metrics: _metrics,
                                                    ),
                                                showPlayhead:
                                                    widget.currentFrameIndex >=
                                                        frameRange.startIndex &&
                                                    widget.currentFrameIndex <
                                                        frameRange
                                                            .endIndexExclusive,
                                                playheadWidth:
                                                    plan.totalFrameContentWidth,
                                                playhead: TimelinePlayhead(
                                                  currentFrameIndex:
                                                      widget.currentFrameIndex,
                                                  frameStartIndex:
                                                      frameRange.startIndex,
                                                  frameEndIndexExclusive:
                                                      frameRange
                                                          .endIndexExclusive,
                                                  leadingFrameSpacerWidth: plan
                                                      .leadingFrameSpacerWidth,
                                                  metrics: _metrics,
                                                  layerCount: rows.length,
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
