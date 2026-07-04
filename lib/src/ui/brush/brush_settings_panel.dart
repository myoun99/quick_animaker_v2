import 'package:flutter/material.dart';

import '../panels/editor_panel_frame.dart';
import 'brush_tool_color_swatch.dart';
import 'brush_tool_state.dart';

class BrushSettingsPanel extends StatelessWidget {
  const BrushSettingsPanel({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;

  static const swatches = <_BrushSwatch>[
    _BrushSwatch('Black', 0xFF000000),
    _BrushSwatch('Red', 0xFFE53935),
    _BrushSwatch('Blue', 0xFF1E88E5),
    _BrushSwatch('White', 0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final sizeLabel = '${state.size.round()} px';
    final opacityLabel = '${(state.opacity * 100).round()}%';
    final spacingLabel = '${(state.spacing * 100).round()}%';
    return EditorPanelFrame(
      title: 'Brush Settings',
      child: Column(
        key: const ValueKey<String>('brush-settings-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Size $sizeLabel · Opacity $opacityLabel · Spacing $spacingLabel',
            key: const ValueKey<String>('brush-tool-current-display'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          _PanelSlider(
            label: 'Size',
            valueLabel: sizeLabel,
            value: BrushToolState.clampSize(state.size),
            min: BrushToolState.minSize,
            max: BrushToolState.maxSize,
            keyValue: 'brush-tool-size-slider',
            onChanged: (value) => onChanged(state.copyWith(size: value)),
          ),
          _PanelSlider(
            label: 'Opacity',
            valueLabel: opacityLabel,
            value: BrushToolState.clampOpacity(state.opacity),
            min: 0,
            max: 1,
            keyValue: 'brush-tool-opacity-slider',
            onChanged: (value) => onChanged(state.copyWith(opacity: value)),
          ),
          _PanelSlider(
            label: 'Spacing',
            valueLabel: spacingLabel,
            value: BrushToolState.clampSpacing(state.spacing),
            min: BrushToolState.minSpacing,
            max: BrushToolState.maxSpacing,
            keyValue: 'brush-tool-spacing-slider',
            onChanged: (value) => onChanged(state.copyWith(spacing: value)),
          ),
          const SizedBox(height: 8),
          Text('Color', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final swatch in swatches)
                BrushToolColorSwatch(
                  label: swatch.label,
                  color: swatch.color,
                  selected: state.color == swatch.color,
                  onSelected: (color) =>
                      onChanged(state.copyWith(color: color)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelSlider extends StatelessWidget {
  const _PanelSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.keyValue,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final String keyValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
            Text(valueLabel, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        Slider(
          key: ValueKey<String>(keyValue),
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BrushSwatch {
  const _BrushSwatch(this.label, this.color);
  final String label;
  final int color;
}
