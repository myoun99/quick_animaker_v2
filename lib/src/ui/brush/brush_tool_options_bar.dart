import 'package:flutter/material.dart';

import 'brush_tool_color_swatch.dart';
import 'brush_tool_state.dart';

class BrushToolOptionsBar extends StatelessWidget {
  const BrushToolOptionsBar({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;

  static const _swatches = <_BrushSwatch>[
    _BrushSwatch('Black', 0xFF000000),
    _BrushSwatch('Red', 0xFFE53935),
    _BrushSwatch('Blue', 0xFF1E88E5),
    _BrushSwatch('White', 0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sizeLabel = '${state.size.round()}px';
    final opacityLabel = '${(state.opacity * 100).round()}%';
    return Material(
      key: const ValueKey<String>('brush-tool-options-bar'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SizedBox(
        height: 44,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Text(
                'Brush $sizeLabel / $opacityLabel',
                key: const ValueKey<String>('brush-tool-current-display'),
                style: textTheme.labelMedium,
              ),
              const SizedBox(width: 16),
              Text('Size', style: textTheme.labelSmall),
              SizedBox(
                width: 160,
                child: Slider(
                  key: const ValueKey<String>('brush-tool-size-slider'),
                  min: BrushToolState.minSize,
                  max: BrushToolState.maxSize,
                  value: BrushToolState.clampSize(state.size),
                  onChanged: (value) => onChanged(state.copyWith(size: value)),
                ),
              ),
              Text(sizeLabel, style: textTheme.labelSmall),
              const SizedBox(width: 12),
              Text('Opacity', style: textTheme.labelSmall),
              SizedBox(
                width: 140,
                child: Slider(
                  key: const ValueKey<String>('brush-tool-opacity-slider'),
                  min: 0,
                  max: 1,
                  value: BrushToolState.clampOpacity(state.opacity),
                  onChanged: (value) =>
                      onChanged(state.copyWith(opacity: value)),
                ),
              ),
              Text(opacityLabel, style: textTheme.labelSmall),
              const SizedBox(width: 12),
              Text('Color', style: textTheme.labelSmall),
              for (final swatch in _swatches)
                BrushToolColorSwatch(
                  label: swatch.label,
                  color: swatch.color,
                  selected: state.color == swatch.color,
                  onSelected: (color) =>
                      onChanged(state.copyWith(color: color)),
                ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrushSwatch {
  const _BrushSwatch(this.label, this.color);
  final String label;
  final int color;
}
