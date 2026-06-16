import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_kind.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_cell_style.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_block.dart';

class LayerTimelineGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final visibleFrameCount = frameCount < _metrics.minimumVisibleFrameCells
        ? _metrics.minimumVisibleFrameCells
        : frameCount;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: const ValueKey<String>('timeline-layer-controls-rail'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCell(
                  width: _metrics.layerControlsWidth,
                  height: _metrics.layerRowHeight,
                  child: TextButton.icon(
                    key: const ValueKey<String>('timeline-add-layer-button'),
                    onPressed: onAddLayer,
                    icon: const Icon(Icons.add),
                    label: const Text('Layer'),
                  ),
                ),
                for (final layer in layers)
                  _LayerControlsRow(
                    layer: layer,
                    active: layer.id == activeLayerId,
                    onSelectLayer: onSelectLayer,
                    onToggleLayerVisibility: onToggleLayerVisibility,
                    onLayerOpacityChanged: onLayerOpacityChanged,
                  ),
                if (layers.isEmpty)
                  SizedBox(
                    width: _metrics.layerControlsWidth,
                    height: _metrics.layerRowHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        'No layers',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey<String>('timeline-frame-scroll-viewport'),
              scrollDirection: Axis.horizontal,
              child: KeyedSubtree(
                key: const ValueKey<String>('timeline-frame-scroll-content'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      key: const ValueKey<String>('timeline-frame-header-row'),
                      children: [
                        for (
                          var frameIndex = 0;
                          frameIndex < visibleFrameCount;
                          frameIndex += 1
                        )
                          _FrameHeader(
                            frameIndex: frameIndex,
                            selected: frameIndex == currentFrameIndex,
                            onSelectFrame: onSelectFrame,
                          ),
                      ],
                    ),
                    for (final layer in layers)
                      _FrameCellsRow(
                        layer: layer,
                        active: layer.id == activeLayerId,
                        currentFrameIndex: currentFrameIndex,
                        visibleFrameCount: visibleFrameCount,
                        exposureStateForLayer: exposureStateForLayer,
                        hasMarkForLayer: hasMarkForLayer,
                        frameNameForLayer: frameNameForLayer,
                        onSelectLayer: onSelectLayer,
                        onSelectFrame: onSelectFrame,
                      ),
                    if (layers.isEmpty)
                      SizedBox(
                        width: visibleFrameCount * _metrics.frameCellWidth,
                        height: _metrics.layerRowHeight,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    required this.visibleFrameCount,
    required this.exposureStateForLayer,
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final bool active;
  final int currentFrameIndex;
  final int visibleFrameCount;
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
        for (
          var frameIndex = 0;
          frameIndex < visibleFrameCount;
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
