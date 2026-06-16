import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_panel_virtualization_adapter.dart';
import 'timeline_block.dart';

class LayerTimelineGrid extends StatefulWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
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
  final int frameCount;
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
  double _horizontalScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void dispose() {
    _horizontalScrollController
      ..removeListener(_handleHorizontalScroll)
      ..dispose();
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
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeyedSubtree(
                        key: const ValueKey<String>(
                          'timeline-layer-controls-rail',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HeaderCell(
                              width:
                                  LayerTimelineGrid._metrics.layerControlsWidth,
                              height: LayerTimelineGrid._metrics.layerRowHeight,
                              child: TextButton.icon(
                                key: const ValueKey<String>(
                                  'timeline-add-layer-button',
                                ),
                                onPressed: widget.onAddLayer,
                                icon: const Icon(Icons.add),
                                label: const Text('Layer'),
                              ),
                            ),
                            for (final layer in widget.layers)
                              _LayerControlsRow(
                                layer: layer,
                                active: layer.id == widget.activeLayerId,
                                onSelectLayer: widget.onSelectLayer,
                                onToggleLayerVisibility:
                                    widget.onToggleLayerVisibility,
                                onLayerOpacityChanged:
                                    widget.onLayerOpacityChanged,
                              ),
                            if (widget.layers.isEmpty)
                              SizedBox(
                                width: LayerTimelineGrid
                                    ._metrics
                                    .layerControlsWidth,
                                height:
                                    LayerTimelineGrid._metrics.layerRowHeight,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'No layers',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: KeyedSubtree(
                          key: const ValueKey<String>(
                            'timeline-frame-grid-area',
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final viewportWidth = constraints.hasBoundedWidth
                                  ? constraints.maxWidth
                                  : 0.0;
                              final plan =
                                  calculateLayerTimelineGridVirtualizationPlan(
                                    horizontalScrollOffset:
                                        _horizontalScrollOffset,
                                    verticalScrollOffset: 0,
                                    viewportWidth: viewportWidth,
                                    viewportHeight: viewportHeight,
                                    frameCount: widget.frameCount,
                                    layerCount: widget.layers.length,
                                    metrics: LayerTimelineGrid._metrics,
                                  );
                              final frameRange = plan.frameRange;

                              return KeyedSubtree(
                                key: const ValueKey<String>(
                                  'timeline-horizontal-scrollbar-viewport',
                                ),
                                child: SingleChildScrollView(
                                  key: const ValueKey<String>(
                                    'timeline-frame-scroll-viewport',
                                  ),
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: KeyedSubtree(
                                    key: const ValueKey<String>(
                                      'timeline-frame-scroll-content',
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          key: const ValueKey<String>(
                                            'timeline-frame-header-row',
                                          ),
                                          children: [
                                            SizedBox(
                                              key: const ValueKey<String>(
                                                'timeline-frame-header-leading-spacer',
                                              ),
                                              width:
                                                  plan.leadingFrameSpacerWidth,
                                              height: LayerTimelineGrid
                                                  ._metrics
                                                  .layerRowHeight,
                                            ),
                                            for (
                                              var frameIndex =
                                                  frameRange.startIndex;
                                              frameIndex <
                                                  frameRange.endIndexExclusive;
                                              frameIndex += 1
                                            )
                                              _FrameHeader(
                                                frameIndex: frameIndex,
                                                selected:
                                                    frameIndex ==
                                                    widget.currentFrameIndex,
                                                onSelectFrame:
                                                    widget.onSelectFrame,
                                              ),
                                            SizedBox(
                                              key: const ValueKey<String>(
                                                'timeline-frame-header-trailing-spacer',
                                              ),
                                              width:
                                                  plan.trailingFrameSpacerWidth,
                                              height: LayerTimelineGrid
                                                  ._metrics
                                                  .layerRowHeight,
                                            ),
                                          ],
                                        ),
                                        for (final layer in widget.layers)
                                          _FrameCellsRow(
                                            layer: layer,
                                            active:
                                                layer.id ==
                                                widget.activeLayerId,
                                            currentFrameIndex:
                                                widget.currentFrameIndex,
                                            frameStartIndex:
                                                frameRange.startIndex,
                                            frameEndIndexExclusive:
                                                frameRange.endIndexExclusive,
                                            leadingFrameSpacerWidth:
                                                plan.leadingFrameSpacerWidth,
                                            trailingFrameSpacerWidth:
                                                plan.trailingFrameSpacerWidth,
                                            exposureStateForLayer:
                                                widget.exposureStateForLayer,
                                            hasMarkForLayer:
                                                widget.hasMarkForLayer,
                                            frameNameForLayer:
                                                widget.frameNameForLayer,
                                            onSelectLayer: widget.onSelectLayer,
                                            onSelectFrame: widget.onSelectFrame,
                                          ),
                                        if (widget.layers.isEmpty)
                                          SizedBox(
                                            width: plan.totalFrameContentWidth,
                                            height: LayerTimelineGrid
                                                ._metrics
                                                .layerRowHeight,
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
              Row(
                children: [
                  SizedBox(
                    key: const ValueKey<String>(
                      'timeline-bottom-scrollbar-left-spacer',
                    ),
                    width: LayerTimelineGrid._metrics.layerControlsWidth,
                    height: bottomScrollbarRailHeight,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final viewportWidth = constraints.hasBoundedWidth
                            ? constraints.maxWidth
                            : 0.0;
                        final effectiveFrameCount = math.max(
                          widget.frameCount,
                          LayerTimelineGrid._metrics.minimumVisibleFrameCells,
                        );
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
    if (widget.controller.hasClients) {
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

class _FrameHeader extends StatelessWidget {
  const _FrameHeader({
    required this.frameIndex,
    required this.selected,
    required this.onSelectFrame,
  });

  final int frameIndex;
  final bool selected;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey<String>('timeline-frame-header-$frameIndex'),
      onTap: () => onSelectFrame(frameIndex),
      child: Container(
        width: LayerTimelineGrid._metrics.frameCellWidth,
        height: LayerTimelineGrid._metrics.layerRowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : colorScheme.surface,
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text('${frameIndex + 1}'),
      ),
    );
  }
}

class _TimelineCell extends StatelessWidget {
  const _TimelineCell({
    required this.layer,
    required this.frameIndex,
    required this.active,
    required this.selected,
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
          backgroundColor: styleColors.background,
          borderColor: styleColors.border,
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
              color: selected
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
