import 'package:flutter/material.dart';

import '../../services/canvas_flood_fill.dart';
import 'brush_settings_panel.dart';
import 'brush_tool_state.dart';

/// The TOOL SETTINGS panel (R11-④, CSP's tool property palette): detailed
/// knobs for the ACTIVE tool. Painting tools show the brush settings,
/// the fill shows its flood options; the selection tools gain their
/// add/subtract modes with the R11-⑧ selection rework.
class ToolSettingsPanel extends StatelessWidget {
  const ToolSettingsPanel({
    super.key,
    required this.state,
    required this.onChanged,
    required this.fillOptions,
    required this.onFillOptionsChanged,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;
  final FloodFillOptions fillOptions;
  final ValueChanged<FloodFillOptions> onFillOptionsChanged;

  @override
  Widget build(BuildContext context) {
    switch (state.tool) {
      case CanvasTool.brush:
      case CanvasTool.eraser:
        return BrushSettingsPanel(state: state, onChanged: onChanged);
      case CanvasTool.fill:
        return _FillSettings(
          options: fillOptions,
          onChanged: onFillOptionsChanged,
        );
      case CanvasTool.eyedropper:
        return const _SettingsNote(
          keyValue: 'tool-settings-eyedropper',
          note: 'Eyedropper has no settings — it picks the visible color.',
        );
      case CanvasTool.selectRect:
      case CanvasTool.lasso:
        return const _SettingsNote(
          keyValue: 'tool-settings-selection',
          note:
              'Selection modes (add / subtract) arrive with the selection '
              'tool rework.',
        );
      case CanvasTool.move:
        return const _SettingsNote(
          keyValue: 'tool-settings-move',
          note: 'Move drags the selected content; arrows nudge it.',
        );
    }
  }
}

class _FillSettings extends StatelessWidget {
  const _FillSettings({required this.options, required this.onChanged});

  final FloodFillOptions options;
  final ValueChanged<FloodFillOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey<String>('tool-settings-fill'),
      padding: const EdgeInsets.all(12),
      children: [
        Text('Fill', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Tolerance ${options.tolerance}',
          style: theme.textTheme.labelMedium,
        ),
        Slider(
          key: const ValueKey<String>('fill-tolerance-slider'),
          min: 0,
          max: 128,
          divisions: 128,
          value: options.tolerance.toDouble().clamp(0, 128),
          onChanged: (value) =>
              onChanged(options.copyWith(tolerance: value.round())),
        ),
        Text(
          'Expand ${options.expandPx}px',
          style: theme.textTheme.labelMedium,
        ),
        Slider(
          key: const ValueKey<String>('fill-expand-slider'),
          min: 0,
          max: 4,
          divisions: 4,
          value: options.expandPx.toDouble().clamp(0, 4),
          onChanged: (value) =>
              onChanged(options.copyWith(expandPx: value.round())),
        ),
        SwitchListTile(
          key: const ValueKey<String>('fill-anti-alias-switch'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Anti-alias'),
          value: options.antiAlias,
          onChanged: (value) => onChanged(options.copyWith(antiAlias: value)),
        ),
      ],
    );
  }
}

class _SettingsNote extends StatelessWidget {
  const _SettingsNote({required this.keyValue, required this.note});

  final String keyValue;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: ValueKey<String>(keyValue),
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
