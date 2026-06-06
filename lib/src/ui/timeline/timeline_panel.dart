import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';
import 'layer_timeline_grid.dart';
import 'timeline_cell_exposure_state.dart';
import 'timeline_orientation.dart';
import 'xsheet_timeline_grid.dart';

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({
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
    required this.orientation,
    required this.onOrientationChanged,
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
  final TimelineOrientation orientation;
  final ValueChanged<TimelineOrientation> onOrientationChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextOrientation = orientation == TimelineOrientation.horizontal
        ? TimelineOrientation.vertical
        : TimelineOrientation.horizontal;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Timeline • Current frame: ${currentFrameIndex + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey<String>(
                      'timeline-toolbar-add-layer-button',
                    ),
                    onPressed: onAddLayer,
                    icon: const Icon(Icons.add),
                    label: const Text('Layer'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: const ValueKey<String>(
                      'timeline-orientation-toggle-button',
                    ),
                    onPressed: () => onOrientationChanged(nextOrientation),
                    child: Text(
                      orientation == TimelineOrientation.horizontal
                          ? 'Show X-sheet'
                          : 'Show Timeline',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: orientation == TimelineOrientation.horizontal
                  ? LayerTimelineGrid(
                      layers: layers,
                      activeLayerId: activeLayerId,
                      currentFrameIndex: currentFrameIndex,
                      frameCount: frameCount,
                      exposureStateForLayer: exposureStateForLayer,
                      hasMarkForLayer: hasMarkForLayer,
                      frameNameForLayer: frameNameForLayer,
                      onSelectLayer: onSelectLayer,
                      onSelectFrame: onSelectFrame,
                      onAddLayer: onAddLayer,
                      onToggleLayerVisibility: onToggleLayerVisibility,
                      onLayerOpacityChanged: onLayerOpacityChanged,
                    )
                  : XSheetTimelineGrid(
                      layers: layers,
                      activeLayerId: activeLayerId,
                      currentFrameIndex: currentFrameIndex,
                      frameCount: frameCount,
                      exposureStateForLayer: exposureStateForLayer,
                      hasMarkForLayer: hasMarkForLayer,
                      frameNameForLayer: frameNameForLayer,
                      onSelectLayer: onSelectLayer,
                      onSelectFrame: onSelectFrame,
                      onAddLayer: onAddLayer,
                      onToggleLayerVisibility: onToggleLayerVisibility,
                      onLayerOpacityChanged: onLayerOpacityChanged,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
