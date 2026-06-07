import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'timeline_cell_exposure_state.dart';

class XSheetTimelineGrid extends StatelessWidget {
  const XSheetTimelineGrid({
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

  static const int _minimumVisibleFrames = 24;
  static const double _frameColumnWidth = 72;
  static const double _layerColumnWidth = 164;
  static const double _rowHeight = 36;
  static const double _headerHeight = 92;

  @override
  Widget build(BuildContext context) {
    final visibleFrameCount = frameCount < _minimumVisibleFrames
        ? _minimumVisibleFrames
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
                  width: _frameColumnWidth,
                  height: _headerHeight,
                  child: const Text('Frame'),
                ),
                for (final layer in layers)
                  _LayerHeader(
                    layer: layer,
                    active: layer.id == activeLayerId,
                    onSelectLayer: onSelectLayer,
                    onToggleLayerVisibility: onToggleLayerVisibility,
                    onLayerOpacityChanged: onLayerOpacityChanged,
                  ),
              ],
            ),
            for (
              var frameIndex = 0;
              frameIndex < visibleFrameCount;
              frameIndex += 1
            )
              _XSheetFrameRow(
                layers: layers,
                activeLayerId: activeLayerId,
                frameIndex: frameIndex,
                current: frameIndex == currentFrameIndex,
                exposureStateForLayer: exposureStateForLayer,
                hasMarkForLayer: hasMarkForLayer,
                frameNameForLayer: frameNameForLayer,
                onSelectLayer: onSelectLayer,
                onSelectFrame: onSelectFrame,
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

class _LayerHeader extends StatelessWidget {
  const _LayerHeader({
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

    return InkWell(
      key: ValueKey<String>('xsheet-layer-header-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        width: XSheetTimelineGrid._layerColumnWidth,
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
                  style: TextStyle(fontWeight: active ? FontWeight.bold : null),
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  key: ValueKey<String>('xsheet-layer-visibility-${layer.id}'),
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
                Expanded(
                  child: Slider(
                    key: ValueKey<String>('xsheet-layer-opacity-${layer.id}'),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _XSheetFrameRow extends StatelessWidget {
  const _XSheetFrameRow({
    required this.layers,
    required this.activeLayerId,
    required this.frameIndex,
    required this.current,
    required this.exposureStateForLayer,
    this.hasMarkForLayer,
    this.frameNameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int frameIndex;
  final bool current;
  final TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer;
  final bool Function(Layer layer, int frameIndex)? hasMarkForLayer;
  final String? Function(Layer layer, int frameIndex)? frameNameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      key: ValueKey<String>('xsheet-frame-row-$frameIndex'),
      children: [
        InkWell(
          onTap: () => onSelectFrame(frameIndex),
          child: Container(
            width: XSheetTimelineGrid._frameColumnWidth,
            height: XSheetTimelineGrid._rowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: current
                  ? colorScheme.primaryContainer
                  : colorScheme.surface,
              border: Border.all(
                color: current
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: current ? 2 : 1,
              ),
            ),
            child: Text('${frameIndex + 1}'),
          ),
        ),
        for (final layer in layers)
          _XSheetCell(
            layer: layer,
            frameIndex: frameIndex,
            active: layer.id == activeLayerId,
            selected: layer.id == activeLayerId && current,
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

class _XSheetCell extends StatelessWidget {
  const _XSheetCell({
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
    final baseColor = active
        ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
        : colorScheme.surface;
    final exposureColor = switch (exposureState) {
      TimelineCellExposureState.empty => baseColor,
      TimelineCellExposureState.drawingStart => colorScheme.tertiaryContainer,
      TimelineCellExposureState.heldExposure =>
        colorScheme.tertiaryContainer.withValues(alpha: 0.62),
      TimelineCellExposureState.blankStart =>
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
      TimelineCellExposureState.blankHeld =>
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
    };
    final exposureBorderColor = switch (exposureState) {
      TimelineCellExposureState.empty => colorScheme.outlineVariant,
      TimelineCellExposureState.drawingStart => colorScheme.tertiary,
      TimelineCellExposureState.heldExposure => colorScheme.tertiary.withValues(
        alpha: 0.55,
      ),
      TimelineCellExposureState.blankStart => colorScheme.outlineVariant,
      TimelineCellExposureState.blankHeld =>
        colorScheme.outlineVariant.withValues(alpha: 0.55),
    };

    return InkWell(
      key: ValueKey<String>('xsheet-cell-${layer.id}-$frameIndex'),
      onTap: () {
        onSelectLayer(layer.id);
        onSelectFrame(frameIndex);
      },
      child: Container(
        width: XSheetTimelineGrid._layerColumnWidth,
        height: XSheetTimelineGrid._rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  colorScheme.primary.withValues(alpha: 0.18),
                  exposureColor,
                )
              : exposureColor,
          border: Border.all(
            color: selected ? colorScheme.primary : exposureBorderColor,
            width: selected ? 3 : 1,
          ),
        ),
        child: Semantics(
          key: selected
              ? const ValueKey<String>('xsheet-selected-cell')
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
