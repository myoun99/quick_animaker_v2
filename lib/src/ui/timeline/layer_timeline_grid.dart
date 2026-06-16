import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_frame_range_policy.dart';
import 'timeline_frame_ruler.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_panel_virtualization_adapter.dart';
import 'timeline_playhead.dart';
import 'timeline_block.dart';

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

  int? _clampedRulerFrameIndex(int frameIndex) {
    if (_visibleFrameCount <= 0) {
      return null;
    }

    return frameIndex.clamp(0, _visibleFrameCount - 1).toInt();
  }

  int? _frameIndexForRulerLocalX(double localX) {
    final frameIndex =
        ((localX + _horizontalScrollOffset) /
                LayerTimelineGrid._metrics.frameCellWidth)
            .floor();
    return _clampedRulerFrameIndex(frameIndex);
  }

  void _selectClampedFrameFromRuler(int frameIndex) {
    final clampedFrameIndex = _clampedRulerFrameIndex(frameIndex);
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
                              _HeaderCell(
                                width: LayerTimelineGrid
                                    ._metrics
                                    .layerControlsWidth,
                                height: headerHeight,
                                child: TextButton.icon(
                                  key: const ValueKey<String>(
                                    'timeline-add-layer-button',
                                  ),
                                  onPressed: widget.onAddLayer,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Layer'),
                                ),
                              ),
                              SizedBox(
                                key: const ValueKey<String>(
                                  'timeline-vertical-scrollbar-slot',
                                ),
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
                                    final plan =
                                        calculateLayerTimelineGridVirtualizationPlan(
                                          horizontalScrollOffset:
                                              _horizontalScrollOffset,
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
                                                  -_horizontalScrollOffset,
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
                                                _LayerControlsRow(
                                                  layer: layer,
                                                  active:
                                                      layer.id ==
                                                      widget.activeLayerId,
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
                                              final plan =
                                                  calculateLayerTimelineGridVirtualizationPlan(
                                                    horizontalScrollOffset:
                                                        _horizontalScrollOffset,
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
                                                                _FrameCellsRow(
                                                                  layer: layer,
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
                                                        Positioned(
                                                          key:
                                                              const ValueKey<
                                                                String
                                                              >(
                                                                'timeline-cut-end-boundary',
                                                              ),
                                                          left: timelineCutEndBoundaryX(
                                                            playbackFrameCount:
                                                                widget
                                                                    .playbackFrameCount,
                                                            metrics:
                                                                LayerTimelineGrid
                                                                    ._metrics,
                                                          ),
                                                          top: 0,
                                                          bottom: 0,
                                                          width: 2,
                                                          child: const IgnorePointer(
                                                            child: DecoratedBox(
                                                              decoration:
                                                                  BoxDecoration(
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                            ),
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
                                                              layerCount: widget
                                                                  .layers
                                                                  .length,
                                                            ),
                                                          ),
                                                      ],
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
                                child: _VerticalScrollbarRail(
                                  key: const ValueKey<String>(
                                    'timeline-vertical-scrollbar',
                                  ),
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

                        return _BottomHorizontalScrollbarRail(
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

class _VerticalScrollbarRail extends StatefulWidget {
  const _VerticalScrollbarRail({
    super.key,
    required this.controller,
    required this.viewportHeight,
    required this.contentHeight,
    required this.width,
  });

  final ScrollController controller;
  final double viewportHeight;
  final double contentHeight;
  final double width;

  @override
  State<_VerticalScrollbarRail> createState() => _VerticalScrollbarRailState();
}

class _VerticalScrollbarRailState extends State<_VerticalScrollbarRail> {
  static const double _minimumThumbHeight = 32;

  double get _maxScrollExtent {
    if (widget.controller.hasClients &&
        widget.controller.position.hasContentDimensions) {
      return widget.controller.position.maxScrollExtent;
    }
    return math.max(0, widget.contentHeight - widget.viewportHeight);
  }

  double get _scrollOffset {
    if (!widget.controller.hasClients) {
      return 0;
    }
    return widget.controller.offset.clamp(0.0, _maxScrollExtent).toDouble();
  }

  double get _thumbHeight {
    if (widget.viewportHeight <= 0 || widget.contentHeight <= 0) {
      return 0;
    }
    if (widget.contentHeight <= widget.viewportHeight) {
      return widget.viewportHeight;
    }
    return (widget.viewportHeight *
            widget.viewportHeight /
            widget.contentHeight)
        .clamp(_minimumThumbHeight, widget.viewportHeight)
        .toDouble();
  }

  double get _thumbTop {
    final maxThumbTop = math.max(0.0, widget.viewportHeight - _thumbHeight);
    final maxScrollExtent = _maxScrollExtent;
    if (maxScrollExtent <= 0 || maxThumbTop <= 0) {
      return 0;
    }
    return (_scrollOffset / maxScrollExtent * maxThumbTop)
        .clamp(0.0, maxThumbTop)
        .toDouble();
  }

  void _jumpToThumbTop(double thumbTop) {
    if (!widget.controller.hasClients) {
      return;
    }
    final maxThumbTop = math.max(0.0, widget.viewportHeight - _thumbHeight);
    final maxScrollExtent = _maxScrollExtent;
    if (maxThumbTop <= 0 || maxScrollExtent <= 0) {
      widget.controller.jumpTo(0);
      return;
    }
    final offset =
        (thumbTop.clamp(0.0, maxThumbTop) / maxThumbTop) * maxScrollExtent;
    widget.controller.jumpTo(offset.clamp(0.0, maxScrollExtent).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          final thumbHeight = _thumbHeight;
          final thumbTop = _thumbTop;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _jumpToThumbTop(details.localPosition.dy - thumbHeight / 2);
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-track',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      border: Border(
                        left: BorderSide(color: colorScheme.outlineVariant),
                        right: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                top: thumbTop,
                height: thumbHeight,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    _jumpToThumbTop(_thumbTop + (details.primaryDelta ?? 0));
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-thumb',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(widget.width),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomHorizontalScrollbarRail extends StatefulWidget {
  const _BottomHorizontalScrollbarRail({
    super.key,
    required this.controller,
    required this.viewportWidth,
    required this.contentWidth,
    required this.height,
  });

  final ScrollController controller;
  final double viewportWidth;
  final double contentWidth;
  final double height;

  @override
  State<_BottomHorizontalScrollbarRail> createState() =>
      _BottomHorizontalScrollbarRailState();
}

class _BottomHorizontalScrollbarRailState
    extends State<_BottomHorizontalScrollbarRail> {
  static const double _minimumThumbWidth = 32;

  double get _maxScrollExtent {
    if (widget.controller.hasClients &&
        widget.controller.position.hasContentDimensions) {
      return widget.controller.position.maxScrollExtent;
    }
    return math.max(0, widget.contentWidth - widget.viewportWidth);
  }

  double get _scrollOffset {
    if (!widget.controller.hasClients) {
      return 0;
    }
    return widget.controller.offset.clamp(0.0, _maxScrollExtent).toDouble();
  }

  double get _thumbWidth {
    if (widget.viewportWidth <= 0 || widget.contentWidth <= 0) {
      return 0;
    }
    if (widget.contentWidth <= widget.viewportWidth) {
      return widget.viewportWidth;
    }
    return (widget.viewportWidth * widget.viewportWidth / widget.contentWidth)
        .clamp(_minimumThumbWidth, widget.viewportWidth)
        .toDouble();
  }

  double get _thumbLeft {
    final maxThumbLeft = math.max(0.0, widget.viewportWidth - _thumbWidth);
    final maxScrollExtent = _maxScrollExtent;
    if (maxScrollExtent <= 0 || maxThumbLeft <= 0) {
      return 0;
    }
    return (_scrollOffset / maxScrollExtent * maxThumbLeft)
        .clamp(0.0, maxThumbLeft)
        .toDouble();
  }

  void _jumpToThumbLeft(double thumbLeft) {
    if (!widget.controller.hasClients) {
      return;
    }
    final maxThumbLeft = math.max(0.0, widget.viewportWidth - _thumbWidth);
    final maxScrollExtent = _maxScrollExtent;
    if (maxThumbLeft <= 0 || maxScrollExtent <= 0) {
      widget.controller.jumpTo(0);
      return;
    }
    final offset =
        (thumbLeft.clamp(0.0, maxThumbLeft) / maxThumbLeft) * maxScrollExtent;
    widget.controller.jumpTo(offset.clamp(0.0, maxScrollExtent).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey<String>('timeline-bottom-scrollbar-rail'),
      height: widget.height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, child) {
          final thumbWidth = _thumbWidth;
          final thumbLeft = _thumbLeft;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: (widget.height - math.max(4, widget.height / 3)) / 2,
                height: math.max(4, widget.height / 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _jumpToThumbLeft(details.localPosition.dx - thumbWidth / 2);
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-horizontal-scrollbar-track',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(widget.height),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                top: 2,
                bottom: 2,
                width: thumbWidth,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    _jumpToThumbLeft(_thumbLeft + (details.primaryDelta ?? 0));
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-horizontal-scrollbar-thumb',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(widget.height),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _iconForLayerKind(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => Icons.brush_outlined,
    LayerKind.storyboard => Icons.auto_stories_outlined,
  };
}

String _semanticLabelForLayerKind(LayerKind kind) {
  return switch (kind) {
    LayerKind.animation => 'Animation layer',
    LayerKind.storyboard => 'Storyboard layer',
  };
}

class _LayerControlsRow extends StatelessWidget {
  const _LayerControlsRow({
    required this.layer,
    required this.active,
    required this.onSelectLayer,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
  });

  final Layer layer;
  final bool active;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.secondaryContainer.withValues(alpha: 0.55);

    return InkWell(
      key: ValueKey<String>('timeline-layer-row-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        width: LayerTimelineGrid._metrics.layerControlsWidth,
        height: LayerTimelineGrid._metrics.layerRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : colorScheme.surface,
          border: Border.all(
            color: active ? colorScheme.secondary : colorScheme.outlineVariant,
            width: active ? 2 : 1,
          ),
        ),
        child: Semantics(
          key: active
              ? const ValueKey<String>('timeline-selected-layer')
              : null,
          label: active ? 'selected layer' : 'layer',
          container: true,
          explicitChildNodes: true,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  key: ValueKey<String>('timeline-layer-name-${layer.id}'),
                  onTap: () => onSelectLayer(layer.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Semantics(
                          label: _semanticLabelForLayerKind(layer.kind),
                          container: true,
                          child: ExcludeSemantics(
                            child: Icon(
                              _iconForLayerKind(layer.kind),
                              key: ValueKey<String>(
                                'timeline-layer-kind-icon-${layer.id}',
                              ),
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            layer.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: active ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('timeline-layer-visibility-${layer.id}'),
                tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(
                  layer.isVisible ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                onPressed: () => onToggleLayerVisibility(layer.id),
              ),
              SizedBox(
                width: 64,
                child: Slider(
                  key: ValueKey<String>('timeline-layer-opacity-${layer.id}'),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _FrameCellsRow extends StatelessWidget {
  const _FrameCellsRow({
    required this.layer,
    required this.active,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.leadingFrameSpacerWidth,
    required this.trailingFrameSpacerWidth,
    required this.exposureStateForLayer,
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final bool active;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final double leadingFrameSpacerWidth;
  final double trailingFrameSpacerWidth;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey<String>('timeline-frame-row-area-${layer.id}'),
      children: [
        SizedBox(
          key: ValueKey<String>(
            'timeline-frame-row-leading-spacer-${layer.id}',
          ),
          width: leadingFrameSpacerWidth,
          height: LayerTimelineGrid._metrics.layerRowHeight,
        ),
        for (
          var frameIndex = frameStartIndex;
          frameIndex < frameEndIndexExclusive;
          frameIndex += 1
        )
          _TimelineCell(
            layer: layer,
            frameIndex: frameIndex,
            active: active,
            selected: active && frameIndex == currentFrameIndex,
            outsidePlaybackRange: frameIndex >= playbackFrameCount,
            exposureState: exposureStateForLayer(layer, frameIndex),
            hasMark: hasMarkForLayer?.call(layer, frameIndex) ?? false,
            frameName: frameNameForLayer?.call(layer, frameIndex),
            onSelectLayer: onSelectLayer,
            onSelectFrame: onSelectFrame,
          ),
        SizedBox(
          key: ValueKey<String>(
            'timeline-frame-row-trailing-spacer-${layer.id}',
          ),
          width: trailingFrameSpacerWidth,
          height: LayerTimelineGrid._metrics.layerRowHeight,
        ),
      ],
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell({
    required this.layer,
    required this.frameIndex,
    required this.active,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.exposureState,
    required this.hasMark,
    this.frameName,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final int frameIndex;
  final bool active;
  final bool selected;
  final bool outsidePlaybackRange;
  final TimelineCellExposureState exposureState;
  final bool hasMark;
  final String? frameName;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final styleColors = timelineCellStyleColors(
      colorScheme: colorScheme,
      exposureState: exposureState,
      active: active,
      selected: selected,
    );

    return InkWell(
      key: ValueKey<String>('timeline-cell-${layer.id}-$frameIndex'),
      onTap: () {
        onSelectLayer(layer.id);
        onSelectFrame(frameIndex);
      },
      child: Container(
        width: LayerTimelineGrid._metrics.frameCellWidth,
        height: LayerTimelineGrid._metrics.layerRowHeight,
        alignment: Alignment.center,
        decoration: timelineBlockDecoration(
          backgroundColor: outsidePlaybackRange
              ? Color.alphaBlend(
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
                  styleColors.background,
                )
              : styleColors.background,
          borderColor: selected
              ? styleColors.border
              : outsidePlaybackRange
              ? Color.alphaBlend(
                  colorScheme.outlineVariant.withValues(alpha: 0.55),
                  styleColors.border,
                )
              : styleColors.border,
          borderWidth: selected ? 3 : 1,
        ),
        child: Semantics(
          key: selected
              ? const ValueKey<String>('timeline-selected-cell')
              : null,
          child: Text(
            _markerForCell(
              exposureState: exposureState,
              hasMark: hasMark,
              frameName: frameName,
            ),
            semanticsLabel: _semanticsLabelForCell(
              exposureState: exposureState,
              hasMark: hasMark,
              frameName: frameName,
            ),
            style: TextStyle(
              color: outsidePlaybackRange
                  ? colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                  : selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
              fontWeight:
                  hasMark || exposureState != TimelineCellExposureState.empty
                  ? FontWeight.bold
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

String _markerForCell({
  required TimelineCellExposureState exposureState,
  required bool hasMark,
  String? frameName,
}) {
  if (hasMark) {
    return '●';
  }

  return switch (exposureState) {
    TimelineCellExposureState.empty => '',
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty ? '○' : frameName,
    TimelineCellExposureState.heldExposure => '',
    TimelineCellExposureState.blankStart => 'X',
    TimelineCellExposureState.blankHeld => '',
  };
}

String? _semanticsLabelForCell({
  required TimelineCellExposureState exposureState,
  required bool hasMark,
  String? frameName,
}) {
  if (hasMark) {
    return 'inbetween mark';
  }

  return switch (exposureState) {
    TimelineCellExposureState.empty => null,
    TimelineCellExposureState.drawingStart =>
      frameName == null || frameName.isEmpty
          ? 'drawing start'
          : 'drawing start $frameName',
    TimelineCellExposureState.heldExposure => 'held exposure',
    TimelineCellExposureState.blankStart => 'blank exposure start',
    TimelineCellExposureState.blankHeld => 'blank held exposure',
  };
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
