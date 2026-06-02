import 'package:flutter/material.dart';

import '../../models/frame.dart';
import '../../models/layer.dart';
import '../../models/layer_id.dart';

class XSheetTimelineGrid extends StatelessWidget {
  const XSheetTimelineGrid({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.currentFrameIndex,
    required this.frameCount,
    required this.resolveFrameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int currentFrameIndex;
  final int frameCount;
  final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  static const int _minimumVisibleFrames = 24;
  static const double _frameColumnWidth = 72;
  static const double _layerColumnWidth = 96;
  static const double _rowHeight = 36;

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
                  height: _rowHeight,
                  child: const Text('Frame'),
                ),
                for (final layer in layers)
                  _LayerHeader(
                    layer: layer,
                    active: layer.id == activeLayerId,
                    onSelectLayer: onSelectLayer,
                  ),
              ],
            ),
            for (var frameIndex = 0;
                frameIndex < visibleFrameCount;
                frameIndex += 1)
              _XSheetFrameRow(
                layers: layers,
                activeLayerId: activeLayerId,
                frameIndex: frameIndex,
                current: frameIndex == currentFrameIndex,
                resolveFrameForLayer: resolveFrameForLayer,
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
  });

  final Layer layer;
  final bool active;
  final ValueChanged<LayerId> onSelectLayer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey<String>('xsheet-layer-header-${layer.id}'),
      onTap: () => onSelectLayer(layer.id),
      child: Container(
        width: XSheetTimelineGrid._layerColumnWidth,
        height: XSheetTimelineGrid._rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          layer.name,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: active ? FontWeight.bold : null),
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
    required this.resolveFrameForLayer,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final int frameIndex;
  final bool current;
  final Frame? Function(Layer layer, int frameIndex) resolveFrameForLayer;
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
              color: current ? colorScheme.primaryContainer : colorScheme.surface,
              border: Border.all(
                color: current ? colorScheme.primary : colorScheme.outlineVariant,
                width: current ? 2 : 1,
              ),
            ),
            child: Text(current ? '▶ $frameIndex' : '$frameIndex'),
          ),
        ),
        for (final layer in layers)
          _XSheetCell(
            layer: layer,
            frameIndex: frameIndex,
            active: layer.id == activeLayerId,
            current: current,
            hasResolvedFrame: resolveFrameForLayer(layer, frameIndex) != null,
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
    required this.current,
    required this.hasResolvedFrame,
    required this.onSelectLayer,
    required this.onSelectFrame,
  });

  final Layer layer;
  final int frameIndex;
  final bool active;
  final bool current;
  final bool hasResolvedFrame;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<int> onSelectFrame;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = active
        ? colorScheme.secondaryContainer.withValues(alpha: 0.35)
        : colorScheme.surface;

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
          color: current ? colorScheme.primaryContainer : baseColor,
          border: Border.all(
            color: current ? colorScheme.primary : colorScheme.outlineVariant,
            width: current ? 2 : 1,
          ),
        ),
        child: Text(
          hasResolvedFrame ? '●' : '',
          semanticsLabel: hasResolvedFrame ? 'drawing exposure' : null,
          style: TextStyle(
            color: current
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
            fontWeight: hasResolvedFrame ? FontWeight.bold : null,
          ),
        ),
      ),
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
