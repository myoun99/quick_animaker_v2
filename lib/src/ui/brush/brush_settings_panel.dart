import 'package:flutter/material.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../../models/brush_tip_shape.dart';
import '../panels/editor_panel_frame.dart';
import 'brush_tool_color_swatch.dart';
import 'brush_tool_state.dart';

class BrushSettingsPanel extends StatelessWidget {
  const BrushSettingsPanel({
    super.key,
    required this.state,
    required this.onChanged,
    this.presets = const <BrushPreset>[],
    this.onPresetApplied,
    this.onPresetSaveRequested,
    this.onPresetDeleted,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;

  /// Saved brush presets shown as chips; tapping one applies its settings.
  final List<BrushPreset> presets;

  /// Called with the preset whose chip was tapped.
  final ValueChanged<BrushPreset>? onPresetApplied;

  /// Called when the user asks to save the current settings as a preset.
  final VoidCallback? onPresetSaveRequested;

  /// Called with the id of the preset whose delete affordance was tapped.
  final ValueChanged<BrushPresetId>? onPresetDeleted;

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
    final hardnessLabel = '${(state.hardness * 100).round()}%';
    final flowLabel = '${(state.flow * 100).round()}%';
    final roundnessLabel = '${(state.roundness * 100).round()}%';
    final angleLabel = '${state.angleDegrees.round()}°';
    return EditorPanelFrame(
      title: 'Brush Settings',
      child: Column(
        key: const ValueKey<String>('brush-settings-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (presets.isNotEmpty || onPresetSaveRequested != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Presets',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (onPresetSaveRequested != null)
                  IconButton(
                    key: const ValueKey<String>('brush-preset-save-button'),
                    icon: const Icon(Icons.add, size: 16),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Save current settings as preset',
                    onPressed: onPresetSaveRequested,
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final preset in presets)
                  InputChip(
                    key: ValueKey<String>(
                      'brush-preset-chip-${preset.id.value}',
                    ),
                    label: Text(preset.name),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onPressed: onPresetApplied == null
                        ? null
                        : () => onPresetApplied!(preset),
                    onDeleted: onPresetDeleted == null
                        ? null
                        : () => onPresetDeleted!(preset.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
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
            label: 'Hardness',
            valueLabel: hardnessLabel,
            value: BrushToolState.clampUnit(state.hardness),
            min: 0,
            max: 1,
            keyValue: 'brush-tool-hardness-slider',
            onChanged: (value) => onChanged(state.copyWith(hardness: value)),
          ),
          _PanelSlider(
            label: 'Flow',
            valueLabel: flowLabel,
            value: BrushToolState.clampUnit(state.flow),
            min: 0,
            max: 1,
            keyValue: 'brush-tool-flow-slider',
            onChanged: (value) => onChanged(state.copyWith(flow: value)),
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
          Text('Tip Shape', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          SegmentedButton<BrushTipShape>(
            key: const ValueKey<String>('brush-tool-tip-shape-toggle'),
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: const [
              ButtonSegment(
                value: BrushTipShape.round,
                icon: Icon(Icons.circle, size: 14),
                label: Text('Round'),
              ),
              ButtonSegment(
                value: BrushTipShape.square,
                icon: Icon(Icons.square, size: 14),
                label: Text('Square'),
              ),
            ],
            selected: {state.tipShape},
            onSelectionChanged: (selection) =>
                onChanged(state.copyWith(tipShape: selection.single)),
          ),
          const SizedBox(height: 4),
          _PanelSlider(
            label: 'Roundness',
            valueLabel: roundnessLabel,
            value: BrushToolState.clampRoundness(state.roundness),
            min: BrushToolState.minRoundness,
            max: 1,
            keyValue: 'brush-tool-roundness-slider',
            onChanged: (value) => onChanged(state.copyWith(roundness: value)),
          ),
          _PanelSlider(
            label: 'Angle',
            valueLabel: angleLabel,
            value: BrushToolState.clampAngleDegrees(state.angleDegrees),
            min: BrushToolState.minAngleDegrees,
            max: BrushToolState.maxAngleDegrees,
            keyValue: 'brush-tool-angle-slider',
            onChanged: (value) =>
                onChanged(state.copyWith(angleDegrees: value)),
          ),
          const SizedBox(height: 8),
          Text('Pen Pressure', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          _PanelSwitch(
            label: 'Size',
            value: state.pressureSize,
            keyValue: 'brush-tool-pressure-size-toggle',
            onChanged: (value) =>
                onChanged(state.copyWith(pressureSize: value)),
          ),
          _PanelSwitch(
            label: 'Opacity',
            value: state.pressureOpacity,
            keyValue: 'brush-tool-pressure-opacity-toggle',
            onChanged: (value) =>
                onChanged(state.copyWith(pressureOpacity: value)),
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
              child: Text(label, style: Theme.of(context).textTheme.labelSmall),
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

class _PanelSwitch extends StatelessWidget {
  const _PanelSwitch({
    required this.label,
    required this.value,
    required this.keyValue,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final String keyValue;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.labelSmall),
        ),
        Switch(
          key: ValueKey<String>(keyValue),
          value: value,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
