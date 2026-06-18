import 'package:flutter/material.dart';

import 'timeline_grid_metrics.dart';

class TimelineLayerControlsHeader extends StatelessWidget {
  const TimelineLayerControlsHeader({
    super.key,
    required this.metrics,
    required this.onAddLayer,
  });

  final TimelineGridMetrics metrics;
  final VoidCallback onAddLayer;

  @override
  Widget build(BuildContext context) {
    return _HeaderCell(
      width: metrics.layerControlsWidth,
      height: metrics.layerRowHeight,
      child: TextButton.icon(
        key: const ValueKey<String>('timeline-add-layer-button'),
        onPressed: onAddLayer,
        icon: const Icon(Icons.add),
        label: const Text('Layer'),
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
