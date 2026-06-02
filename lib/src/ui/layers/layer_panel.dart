import 'package:flutter/material.dart';

import '../../models/layer.dart';
import '../../models/layer_id.dart';

class LayerPanel extends StatelessWidget {
  const LayerPanel({
    super.key,
    required this.layers,
    required this.activeLayerId,
    required this.onSelectLayer,
    required this.onAddLayer,
    required this.onToggleVisibility,
    required this.onOpacityChanged,
  });

  final List<Layer> layers;
  final LayerId? activeLayerId;
  final ValueChanged<LayerId> onSelectLayer;
  final VoidCallback onAddLayer;
  final ValueChanged<LayerId> onToggleVisibility;
  final void Function(LayerId layerId, double opacity) onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Layers',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onAddLayer,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Layer'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: layers.length,
                itemBuilder: (context, index) {
                  final layer = layers[index];
                  final selected = layer.id == activeLayerId;

                  return _LayerRow(
                    layer: layer,
                    selected: selected,
                    onSelectLayer: onSelectLayer,
                    onToggleVisibility: onToggleVisibility,
                    onOpacityChanged: onOpacityChanged,
                  );
                },
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
    required this.selected,
    required this.onSelectLayer,
    required this.onToggleVisibility,
    required this.onOpacityChanged,
  });

  final Layer layer;
  final bool selected;
  final ValueChanged<LayerId> onSelectLayer;
  final ValueChanged<LayerId> onToggleVisibility;
  final void Function(LayerId layerId, double opacity) onOpacityChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () => onSelectLayer(layer.id),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: layer.isVisible ? 'Hide layer' : 'Show layer',
                    onPressed: () => onToggleVisibility(layer.id),
                    icon: Icon(
                      layer.isVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  Expanded(child: Text(layer.name)),
                ],
              ),
              Row(
                children: [
                  const Text('Opacity'),
                  Expanded(
                    child: Slider(
                      value: layer.opacity.clamp(0.0, 1.0).toDouble(),
                      onChanged: (value) => onOpacityChanged(layer.id, value),
                    ),
                  ),
                  Text('${(layer.opacity * 100).round()}%'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
