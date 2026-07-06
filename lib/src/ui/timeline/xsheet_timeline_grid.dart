import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import '../../models/layer_kind.dart';
import 'selected_exposure_display_range_policy.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_exposure_block_visual.dart';
import 'timeline_exposure_comma_drag_policy.dart';
import 'timeline_frame_cell.dart';
import 'timeline_frame_cells_row.dart' show timelineRowBlockEdgeGrips;
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_body_cut_end_boundary.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_horizontal_offset_policy.dart';
import 'timeline_horizontal_scrollbar_rail.dart';
import 'timeline_playhead.dart';
import 'timeline_ruler_cut_end_boundary.dart';
import 'timeline_section_policy.dart';
import 'timeline_selected_exposure_outline.dart';
import 'timeline_vertical_scrollbar_rail.dart';
import 'timeline_virtualization_plan.dart';

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
    required this.currentFrameIndex,
    required this.frameCount,
    required this.exposureStateForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
    this.commaDrag,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;

  /// Playback frame count of the active cut (the visible range extends to
  /// the shared minimum, exactly like the horizontal timeline).
  final int frameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  /// Comma-drag hooks for the block edge grips (shared policy with the
  /// horizontal timeline); null hides the grips.
  final TimelineCommaDragCallbacks? commaDrag;

  /// TRANSPOSED metrics: frameCellWidth = frame row height, layerRowHeight
  /// = layer column width, layerControlsWidth = frame-number rail width.
  static const TimelineGridMetrics _metrics = TimelineGridMetrics(
    frameCellWidth: 36,
    layerRowHeight: 164,
    layerControlsWidth: 72,
  );

  static const double _headerHeight = 92;

  @override
  State<XSheetTimelineGrid> createState() => _XSheetTimelineGridState();
}

class _XSheetTimelineGridState extends State<XSheetTimelineGrid> {
  late final ScrollController _frameScrollController;
  late final ScrollController _layerScrollController;
  double _frameScrollOffset = 0;
  double _lastEffectiveFrameScrollOffset = 0;
  double? _scheduledFrameOffsetCorrection;
  final GlobalKey _railScrubViewportKey = GlobalKey();
  int? _lastRailScrubbedFrameIndex;

  static TimelineGridMetrics get _metrics => XSheetTimelineGrid._metrics;

  @override
  void initState() {
    super.initState();
    _frameScrollController = ScrollController();
    _layerScrollController = ScrollController();
    _frameScrollController.addListener(_handleFrameScroll);
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
    setState(() {
      _frameScrollOffset = offset;
    });
  }

  TimelineFrameRange get _frameRangePolicy =>
      TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: widget.frameCount,
        minimumVisibleFrameCells: _metrics.minimumVisibleFrameCells,
      );

  int get _visibleFrameCount => _frameRangePolicy.visibleFrameCount;

  double get _totalFrameContentHeight =>
      _visibleFrameCount * _metrics.frameCellWidth;

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
    widget.onSelectFrame(clampedFrameIndex);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const bottomScrollbarRailHeight = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyViewportHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight -
                      XSheetTimelineGrid._headerHeight -
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

        // The shared virtualization plan with the frame axis fed through the
        // "horizontal" inputs (the axes are swapped in this grid).
        final plan = calculateTimelineVirtualizationPlan(
          horizontalScrollOffset: effectiveFrameScrollOffset,
          verticalScrollOffset: 0,
          viewportWidth: bodyViewportHeight,
          viewportHeight: 0,
          frameCellWidth: _metrics.frameCellWidth,
          layerRowHeight: _metrics.layerRowHeight,
          frameCount: _visibleFrameCount,
          layerCount: widget.layers.length,
        );
        final frameRange = plan.frameRange;
        final totalFrameContentHeight = plan.totalFrameContentWidth;
        final columnsContentWidth =
            widget.layers.length * _metrics.layerRowHeight;
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
                          height: XSheetTimelineGrid._headerHeight,
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
                                          _XSheetFrameNumberRail(
                                            frameStartIndex:
                                                frameRange.startIndex,
                                            frameEndIndexExclusive:
                                                frameRange.endIndexExclusive,
                                            currentFrameIndex:
                                                widget.currentFrameIndex,
                                            playbackFrameCount:
                                                widget.frameCount,
                                            leadingFrameSpacerHeight:
                                                plan.leadingFrameSpacerWidth,
                                            trailingFrameSpacerHeight:
                                                plan.trailingFrameSpacerWidth,
                                            metrics: _metrics,
                                            onSelectFrame:
                                                _selectClampedFrameFromRail,
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
                          height: XSheetTimelineGrid._headerHeight,
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
                                  Row(
                                    children: [
                                      for (
                                        var index = 0;
                                        index < widget.layers.length;
                                        index += 1
                                      )
                                        _LayerHeader(
                                          layer: widget.layers[index],
                                          active:
                                              widget.layers[index].id ==
                                              widget.activeLayerId,
                                          sectionStart: timelineSectionStartsAt(
                                            widget.layers,
                                            index,
                                          ),
                                          onSelectLayer: widget.onSelectLayer,
                                          onToggleLayerVisibility:
                                              widget.onToggleLayerVisibility,
                                          onLayerOpacityChanged:
                                              widget.onLayerOpacityChanged,
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
                                                for (
                                                  var index = 0;
                                                  index < widget.layers.length;
                                                  index += 1
                                                )
                                                  _XSheetFrameCellsColumn(
                                                    layer: widget.layers[index],
                                                    active:
                                                        widget
                                                            .layers[index]
                                                            .id ==
                                                        widget.activeLayerId,
                                                    sectionStart:
                                                        timelineSectionStartsAt(
                                                          widget.layers,
                                                          index,
                                                        ),
                                                    currentFrameIndex: widget
                                                        .currentFrameIndex,
                                                    playbackFrameCount:
                                                        widget.frameCount,
                                                    frameStartIndex:
                                                        frameRange.startIndex,
                                                    frameEndIndexExclusive:
                                                        frameRange
                                                            .endIndexExclusive,
                                                    leadingFrameSpacerHeight: plan
                                                        .leadingFrameSpacerWidth,
                                                    trailingFrameSpacerHeight: plan
                                                        .trailingFrameSpacerWidth,
                                                    metrics: _metrics,
                                                    exposureStateForLayer: widget
                                                        .exposureStateForLayer,
                                                    frameNameForLayer: widget
                                                        .frameNameForLayer,
                                                    onSelectLayer:
                                                        widget.onSelectLayer,
                                                    onSelectFrame:
                                                        widget.onSelectFrame,
                                                    commaDrag:
                                                        widget.commaDrag,
                                                  ),
                                              ],
                                            ),
                                            TimelinePlayhead(
                                              axis: Axis.vertical,
                                              currentFrameIndex:
                                                  widget.currentFrameIndex,
                                              frameStartIndex:
                                                  frameRange.startIndex,
                                              frameEndIndexExclusive:
                                                  frameRange.endIndexExclusive,
                                              leadingFrameSpacerWidth:
                                                  plan.leadingFrameSpacerWidth,
                                              metrics: _metrics,
                                              layerCount: widget.layers.length,
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
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerHeight;
  final double trailingFrameSpacerHeight;
  final TimelineGridMetrics metrics;
  final ValueChanged<int> onSelectFrame;

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
    required this.metrics,
    required this.onSelectFrame,
  });

  final int frameIndex;
  final bool selected;
  final bool outsidePlaybackRange;
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
        alignment: Alignment.center,
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
        child: Text(
          '${frameIndex + 1}',
          style: TextStyle(
            color: outsidePlaybackRange
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                : colorScheme.onSurface,
          ),
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
    required this.currentFrameIndex,
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
    this.commaDrag,
    this.sectionStart = false,
  });

  final Layer layer;
  final bool active;

  /// Whether this column opens a new timesheet section; draws a heavier
  /// divider along the column's left edge.
  final bool sectionStart;
  final int currentFrameIndex;
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
  final TimelineCommaDragCallbacks? commaDrag;

  @override
  Widget build(BuildContext context) {
    final selectedExposureDisplayRange = resolveSelectedExposureDisplayRange(
      active: active,
      currentFrameIndex: currentFrameIndex,
      frameStartIndex: frameStartIndex,
      frameEndIndexExclusive: frameEndIndexExclusive,
      exposureStateAt: (frameIndex) => exposureStateForLayer(layer, frameIndex),
    );
    final selectedExposureRange = selectedExposureDisplayRange.resolvedRange;
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
                  selected: active && frameIndex == currentFrameIndex,
                  outsidePlaybackRange: frameIndex >= playbackFrameCount,
                  exposureState: exposureStateForLayer(layer, frameIndex),
                  selectedExposureRangeSegment:
                      frameIndex >= selectedExposureRange.startFrameIndex &&
                      frameIndex < selectedExposureRange.endFrameIndexExclusive,
                  exposureBlockSegment:
                      calculateTimelineExposureBlockVisualSegment(
                        previous: frameIndex == 0
                            ? null
                            : exposureStateForLayer(layer, frameIndex - 1),
                        current: exposureStateForLayer(layer, frameIndex),
                        next: exposureStateForLayer(layer, frameIndex + 1),
                      ),
                  frameName: frameNameForLayer?.call(layer, frameIndex),
                  onSelectLayer: onSelectLayer,
                  onSelectFrame: onSelectFrame,
                  axis: Axis.vertical,
                  width: metrics.layerRowHeight,
                  height: metrics.frameCellWidth,
                  cellKeyPrefix: 'xsheet-cell',
                  selectedSemanticsKey: const ValueKey<String>(
                    'xsheet-selected-cell',
                  ),
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
          TimelineSelectedExposureOutline(
            axis: Axis.vertical,
            layerId: layer.id,
            displayRange: selectedExposureDisplayRange,
            frameStartIndex: frameStartIndex,
            leadingFrameSpacerWidth: leadingFrameSpacerHeight,
            frameCellWidth: metrics.frameCellWidth,
            rowHeight: metrics.layerRowHeight,
            borderColor: timelineSelectedFrameBorderColor,
            borderRadius: const BorderRadius.all(Radius.circular(6)),
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
          if (commaDrag != null && layer.kind != LayerKind.camera)
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
        ],
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
    this.sectionStart = false,
  });

  final Layer layer;
  final bool active;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  /// Whether this column opens a new timesheet section; draws a heavier
  /// divider along the header's left edge.
  final bool sectionStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final header = InkWell(
      key: ValueKey<String>('xsheet-layer-header-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        width: XSheetTimelineGrid._metrics.layerRowHeight,
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
              InkWell(
                key: ValueKey<String>('xsheet-layer-name-${layer.id}'),
                onTap: () => onSelectLayer(layer.id),
                child: SizedBox(
                  width: double.infinity,
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
              Row(
                children: [
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
                  // The camera track has no compositing opacity; hide the
                  // slider rather than offering a dead control.
                  if (layer.kind != LayerKind.camera) ...[
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
