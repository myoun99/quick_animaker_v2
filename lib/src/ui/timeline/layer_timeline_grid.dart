import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';

class LayerTimelineGrid extends StatelessWidget {
  const LayerTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.exposureStateForLayer,
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
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  static const int _minimumVisibleCells = 24;
  static const double _layerControlsWidth = 220;
  static const double _cellWidth = 48;
  static const double _rowHeight = 52;

  @override
  Widget build(BuildContext context) {
    final visibleFrameCount = frameCount < _minimumVisibleCells
        ? _minimumVisibleCells
        : frameCount;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _HeaderCell(
                  width: _layerControlsWidth,
                  height: _rowHeight,
                  child: TextButton.icon(
                    key: const ValueKey<String>('timeline-add-layer-button'),
                    onPressed: onAddLayer,
                    icon: const Icon(Icons.add),
                    label: const Text('Layer'),
                  ),
                ),
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
              _LayerRow(
                layer: layer,
                active: layer.id == activeLayerId,
                currentFrameIndex: currentFrameIndex,
                visibleFrameCount: visibleFrameCount,
                exposureStateForLayer: exposureStateForLayer,
                onSelectLayer: onSelectLayer,
                onSelectFrame: onSelectFrame,
                onToggleLayerVisibility: onToggleLayerVisibility,
                onLayerOpacityChanged: onLayerOpacityChanged,
              ),
            if (layers.isEmpty)
              SizedBox(
                height: _rowHeight,
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
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({
    required this.layer,
    required this.active,
    required this.currentFrameIndex,
    required this.visibleFrameCount,
    required this.exposureStateForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
    required this.onToggleLayerVisibility,
    required this.onLayerOpacityChanged,
  });

  final Layer layer;
  final bool active;
  final int currentFrameIndex;
  final int visibleFrameCount;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;
  final ValueChanged<LayerId> onToggleLayerVisibility;
  final void Function(LayerId layerId, double opacity) onLayerOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.secondaryContainer.withValues(alpha: 0.55);

    return Row(
      children: [
        InkWell(
          key: ValueKey<String>('timeline-layer-row-${layer.id}'),
          onTap: () => onSelectLayer(layer.id),
          child: Container(
            width: LayerTimelineGrid._layerControlsWidth,
            height: LayerTimelineGrid._rowHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: active ? activeColor : colorScheme.surface,
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    key: ValueKey<String>('timeline-layer-name-${layer.id}'),
                    onTap: () => onSelectLayer(layer.id),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        layer.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: active ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey<String>(
                    'timeline-layer-visibility-${layer.id}',
                  ),
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
        for (
          var frameIndex = 0;
          frameIndex < visibleFrameCount;
          frameIndex += 1
        )
          _TimelineCell(
            layer: layer,
            frameIndex: frameIndex,
            active: active,
            current: frameIndex == currentFrameIndex,
            exposureState: exposureStateForLayer(layer, frameIndex),
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
        width: LayerTimelineGrid._cellWidth,
        height: LayerTimelineGrid._rowHeight,
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
    required this.current,
    required this.exposureState,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final int frameIndex;
  final bool active;
  final bool current;
  final TimelineCellExposureState exposureState;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = active
        ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
        : colorScheme.surface;
    final exposureColor = switch (exposureState) {
      TimelineCellExposureState.empty => baseColor,
      TimelineCellExposureState.drawingStart => colorScheme.tertiaryContainer,
      TimelineCellExposureState.heldExposure =>
        colorScheme.tertiaryContainer.withValues(alpha: 0.62),
      TimelineCellExposureState.blankStart => colorScheme.errorContainer,
      TimelineCellExposureState.blankHeld =>
        colorScheme.errorContainer.withValues(alpha: 0.35),
    };
    final exposureBorderColor = switch (exposureState) {
      TimelineCellExposureState.empty => colorScheme.outlineVariant,
      TimelineCellExposureState.drawingStart => colorScheme.tertiary,
      TimelineCellExposureState.heldExposure => colorScheme.tertiary.withValues(
        alpha: 0.55,
      ),
      TimelineCellExposureState.blankStart => colorScheme.error,
      TimelineCellExposureState.blankHeld => colorScheme.error.withValues(
        alpha: 0.45,
      ),
    };

    return InkWell(
      key: ValueKey<String>('timeline-cell-${layer.id}-$frameIndex'),
      onTap: () {
        onSelectLayer(layer.id);
        onSelectFrame(frameIndex);
      },
      child: Container(
        width: LayerTimelineGrid._cellWidth,
        height: LayerTimelineGrid._rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: current ? colorScheme.primaryContainer : exposureColor,
          border: Border.all(
            color: current ? colorScheme.primary : exposureBorderColor,
            width: current ? 2 : 1,
          ),
        ),
        child: Text(
          _markerForState(exposureState),
          semanticsLabel: _semanticsLabelForState(exposureState),
          style: TextStyle(
            color: current
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
            fontWeight: exposureState == TimelineCellExposureState.empty
                ? null
                : FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

String _markerForState(TimelineCellExposureState state) {
  return switch (state) {
    TimelineCellExposureState.empty => '',
    TimelineCellExposureState.drawingStart => '○',
    TimelineCellExposureState.heldExposure => '',
    TimelineCellExposureState.blankStart => 'X',
    TimelineCellExposureState.blankHeld => '',
  };
}

String? _semanticsLabelForState(TimelineCellExposureState state) {
  return switch (state) {
    TimelineCellExposureState.empty => null,
    TimelineCellExposureState.drawingStart => 'drawing start',
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
