import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_body_cut_end_boundary.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_frame_cells_row.dart';
import 'timeline_frame_coordinate_policy.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_frame_ruler.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_horizontal_offset_policy.dart';
import 'timeline_horizontal_scrollbar_rail.dart';
import 'timeline_layer_controls_header.dart';
import 'timeline_layer_controls_row.dart';
import 'timeline_panel_virtualization_adapter.dart';
import 'timeline_playhead.dart';
import 'timeline_vertical_scrollbar_rail.dart';

class LayerTimelineGrid extends StatefulWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.exposureStateForLayer,
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    required this.onAddLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  static const TimelineGridMetrics _metrics = TimelineGridMetrics.defaults;

  @override
  State<LayerTimelineGrid> createState() => _LayerTimelineGridState();
}

class _LayerTimelineGridState extends State<LayerTimelineGrid> {
  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;
  double _horizontalScrollOffset = 0;
  double _lastEffectiveHorizontalScrollOffset = 0;
  double? _scheduledHorizontalOffsetCorrection;
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
    setState(() {
      _horizontalScrollOffset = offset;
    });
  }

  TimelineFrameRange get _frameRangePolicy =>
      TimelineFrameRange.fromPlaybackDuration(
        playbackFrameCount: widget.playbackFrameCount,
        minimumVisibleFrameCells:
            LayerTimelineGrid._metrics.minimumVisibleFrameCells,
      );

  int get _visibleFrameCount => _frameRangePolicy.visibleFrameCount;

  double _effectiveHorizontalScrollOffset({
    required double requestedOffset,
    required double viewportWidth,
  }) {
    final totalFrameContentWidth =
        _visibleFrameCount * LayerTimelineGrid._metrics.frameCellWidth;

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
      frameCellWidth: LayerTimelineGrid._metrics.frameCellWidth,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const bottomScrollbarRailHeight = 16.0;

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
                    final headerHeight =
                        LayerTimelineGrid._metrics.layerRowHeight;
                    final bodyViewportHeight = constraints.hasBoundedHeight
                        ? (constraints.maxHeight - headerHeight)
                              .clamp(0.0, double.infinity)
                              .toDouble()
                        : viewportHeight;
                    final verticalContentHeight =
                        LayerTimelineGrid._metrics.layerRowHeight *
                        math.max(widget.layers.length, 1);

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
                                metrics: LayerTimelineGrid._metrics,
                                onAddLayer: widget.onAddLayer,
                              ),
                              TimelineVerticalScrollbarSlot(
                                width: LayerTimelineGrid
                                    ._metrics
                                    .verticalScrollbarWidth,
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
                                          visibleFrameCount: _visibleFrameCount,
                                          layerCount: widget.layers.length,
                                          metrics: LayerTimelineGrid._metrics,
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
                                                    metrics: LayerTimelineGrid
                                                        ._metrics,
                                                    onSelectFrame:
                                                        _selectClampedFrameFromRuler,
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
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      KeyedSubtree(
                                        key: const ValueKey<String>(
                                          'timeline-layer-controls-rail',
                                        ),
                                        child: KeyedSubtree(
                                          key: const ValueKey<String>(
                                            'timeline-layer-rows-scroll-body',
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              for (final layer in widget.layers)
                                                TimelineLayerControlsRow(
                                                  layer: layer,
                                                  active:
                                                      layer.id ==
                                                      widget.activeLayerId,
                                                  metrics: LayerTimelineGrid
                                                      ._metrics,
                                                  onSelectLayer:
                                                      widget.onSelectLayer,
                                                  onToggleLayerVisibility: widget
                                                      .onToggleLayerVisibility,
                                                  onLayerOpacityChanged: widget
                                                      .onLayerOpacityChanged,
                                                ),
                                              if (widget.layers.isEmpty)
                                                SizedBox(
                                                  width: LayerTimelineGrid
                                                      ._metrics
                                                      .layerControlsWidth,
                                                  height: LayerTimelineGrid
                                                      ._metrics
                                                      .layerRowHeight,
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.all(8),
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
                                        ),
                                      ),
                                      SizedBox(
                                        width: LayerTimelineGrid
                                            ._metrics
                                            .verticalScrollbarWidth,
                                        height: verticalContentHeight,
                                      ),
                                      Expanded(
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
                                                    viewportWidth:
                                                        viewportWidth,
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
                                                    viewportWidth:
                                                        viewportWidth,
                                                    viewportHeight:
                                                        viewportHeight,
                                                    visibleFrameCount:
                                                        _visibleFrameCount,
                                                    layerCount:
                                                        widget.layers.length,
                                                    metrics: LayerTimelineGrid
                                                        ._metrics,
                                                  );
                                              final frameRange =
                                                  plan.frameRange;

                                              return KeyedSubtree(
                                                key: const ValueKey<String>(
                                                  'timeline-horizontal-scrollbar-viewport',
                                                ),
                                                child: SingleChildScrollView(
                                                  key: const ValueKey<String>(
                                                    'timeline-frame-scroll-viewport',
                                                  ),
                                                  controller:
                                                      _horizontalScrollController,
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: KeyedSubtree(
                                                    key: const ValueKey<String>(
                                                      'timeline-frame-scroll-content',
                                                    ),
                                                    child: SizedBox(
                                                      width: plan
                                                          .totalFrameContentWidth,
                                                      height:
                                                          verticalContentHeight,
                                                      child: Stack(
                                                        children: [
                                                          KeyedSubtree(
                                                            key:
                                                                const ValueKey<
                                                                  String
                                                                >(
                                                                  'timeline-frame-rows-scroll-body',
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                for (final layer
                                                                    in widget
                                                                        .layers)
                                                                  TimelineFrameCellsRow(
                                                                    layer:
                                                                        layer,
                                                                    active:
                                                                        layer
                                                                            .id ==
                                                                        widget
                                                                            .activeLayerId,
                                                                    currentFrameIndex:
                                                                        widget
                                                                            .currentFrameIndex,
                                                                    playbackFrameCount:
                                                                        widget
                                                                            .playbackFrameCount,
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
                                                                        LayerTimelineGrid
                                                                            ._metrics,
                                                                    exposureStateForLayer:
                                                                        widget
                                                                            .exposureStateForLayer,
                                                                    hasMarkForLayer:
                                                                        widget
                                                                            .hasMarkForLayer,
                                                                    frameNameForLayer:
                                                                        widget
                                                                            .frameNameForLayer,
                                                                    onSelectLayer:
                                                                        widget
                                                                            .onSelectLayer,
                                                                    onSelectFrame:
                                                                        widget
                                                                            .onSelectFrame,
                                                                  ),
                                                                if (widget
                                                                    .layers
                                                                    .isEmpty)
                                                                  SizedBox(
                                                                    width: plan
                                                                        .totalFrameContentWidth,
                                                                    height: LayerTimelineGrid
                                                                        ._metrics
                                                                        .layerRowHeight,
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                          TimelineBodyCutEndBoundary(
                                                            left: timelineCutEndBoundaryX(
                                                              playbackFrameCount:
                                                                  widget
                                                                      .playbackFrameCount,
                                                              metrics:
                                                                  LayerTimelineGrid
                                                                      ._metrics,
                                                            ),
                                                          ),
                                                          if (widget.currentFrameIndex >=
                                                                  frameRange
                                                                      .startIndex &&
                                                              widget.currentFrameIndex <
                                                                  frameRange
                                                                      .endIndexExclusive)
                                                            Positioned(
                                                              left: 0,
                                                              top: 0,
                                                              width: plan
                                                                  .totalFrameContentWidth,
                                                              child: TimelinePlayhead(
                                                                currentFrameIndex:
                                                                    widget
                                                                        .currentFrameIndex,
                                                                frameStartIndex:
                                                                    frameRange
                                                                        .startIndex,
                                                                frameEndIndexExclusive:
                                                                    frameRange
                                                                        .endIndexExclusive,
                                                                leadingFrameSpacerWidth:
                                                                    plan.leadingFrameSpacerWidth,
                                                                metrics:
                                                                    LayerTimelineGrid
                                                                        ._metrics,
                                                                layerCount:
                                                                    widget
                                                                        .layers
                                                                        .length,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: LayerTimelineGrid
                                    ._metrics
                                    .layerControlsWidth,
                                top: 0,
                                bottom: 0,
                                width: LayerTimelineGrid
                                    ._metrics
                                    .verticalScrollbarWidth,
                                child: TimelineVerticalScrollbarRail(
                                  controller: _verticalScrollController,
                                  viewportHeight: bodyViewportHeight,
                                  contentHeight: verticalContentHeight,
                                  width: LayerTimelineGrid
                                      ._metrics
                                      .verticalScrollbarWidth,
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
                    width: LayerTimelineGrid._metrics.layerControlsWidth,
                    height: bottomScrollbarRailHeight,
                  ),
                  SizedBox(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-bottom-spacer',
                    ),
                    width: LayerTimelineGrid._metrics.verticalScrollbarWidth,
                    height: bottomScrollbarRailHeight,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : 0.0;
                        final effectiveFrameCount = _visibleFrameCount;
                        final contentWidth =
                            effectiveFrameCount *
                            LayerTimelineGrid._metrics.frameCellWidth;

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
