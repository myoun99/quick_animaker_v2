import 'package:flutter/material.dart';

import '../../services/canvas_flood_fill.dart';
import '../../services/canvas_selection.dart';
import '../widgets/field_slider.dart';
import 'brush_settings_panel.dart';
import 'brush_tool_state.dart';
import 'canvas_selection_commands.dart';

/// The TOOL SETTINGS panel (R11-④, CSP's tool property palette): detailed
/// knobs for the ACTIVE tool. Painting tools show the brush settings, the
/// fill shows its flood options, the selection tool picks its variant
/// (rectangle/lasso — R17-U: one toolbar tool), and Move shows the live
/// transform's numeric inputs.
class ToolSettingsPanel extends StatelessWidget {
  const ToolSettingsPanel({
    super.key,
    required this.state,
    required this.onChanged,
    required this.fillOptions,
    required this.onFillOptionsChanged,
    this.selectionMaskOptions = SelectionMaskOptions.none,
    this.onSelectionMaskOptionsChanged,
    this.selectionCommands,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;
  final FloodFillOptions fillOptions;
  final ValueChanged<FloodFillOptions> onFillOptionsChanged;

  /// R26 (C2): the Select tool's lift-time mask knobs (grow/shrink,
  /// inward feather, edge AA).
  final SelectionMaskOptions selectionMaskOptions;
  final ValueChanged<SelectionMaskOptions>? onSelectionMaskOptionsChanged;

  /// The mounted selection layer's imperative channel — the Move tool's
  /// numeric inputs read and write the live transform through it.
  final CanvasSelectionCommands? selectionCommands;

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
        return _SelectionSettings(
          state: state,
          onChanged: onChanged,
          maskOptions: selectionMaskOptions,
          onMaskOptionsChanged: onSelectionMaskOptionsChanged,
        );
      case CanvasTool.move:
        return _MoveSettings(selectionCommands: selectionCommands);
    }
  }
}

/// R17-U: the selection VARIANT is a setting of the single Select tool.
/// R26 (C2): plus the lift-time mask knobs — grow/shrink, inward
/// feather, edge AA. Defaults keep the lift byte-preserving.
class _SelectionSettings extends StatelessWidget {
  const _SelectionSettings({
    required this.state,
    required this.onChanged,
    required this.maskOptions,
    required this.onMaskOptionsChanged,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;
  final SelectionMaskOptions maskOptions;
  final ValueChanged<SelectionMaskOptions>? onMaskOptionsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onMask = onMaskOptionsChanged;
    return ListView(
      key: const ValueKey<String>('tool-settings-selection'),
      padding: const EdgeInsets.all(12),
      children: [
        // R26 #12: the rectangle/lasso CHOICE lives in the tool library
        // (two tools there), so the settings panel no longer duplicates
        // it — only the mask knobs remain.
        Text('Select', style: theme.textTheme.titleSmall),
        if (onMask != null) ...[
          const SizedBox(height: 8),
          FieldSlider(
            key: const ValueKey<String>('selection-grow-slider'),
            min: -20,
            max: 20,
            divisions: 40,
            value: maskOptions.growPx.toDouble().clamp(-20, 20),
            label: 'Grow/Shrink',
            valueText: maskOptions.growPx == 0
                ? 'off'
                : '${maskOptions.growPx > 0 ? '+' : ''}${maskOptions.growPx} px',
            onChanged: (value) =>
                onMask(maskOptions.copyWith(growPx: value.round())),
          ),
          const SizedBox(height: 8),
          FieldSlider(
            key: const ValueKey<String>('selection-feather-slider'),
            min: 0,
            max: 50,
            divisions: 50,
            value: maskOptions.featherPx.clamp(0, 50),
            label: 'Feather',
            valueText: maskOptions.featherPx <= 0
                ? 'off'
                : '${maskOptions.featherPx.round()} px',
            onChanged: (value) =>
                onMask(maskOptions.copyWith(featherPx: value.roundToDouble())),
          ),
          SwitchListTile(
            key: const ValueKey<String>('selection-anti-alias-switch'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Anti-alias edge'),
            value: maskOptions.antiAlias,
            onChanged: (value) =>
                onMask(maskOptions.copyWith(antiAlias: value)),
          ),
        ],
      ],
    );
  }
}

/// The Move/Transform tool's numeric inputs (R17-U 유저 채택 설계:
/// 좌표/각도 수치 입력): X/Y offset, angle and scale of the LIVE
/// transform box, applied on submit through the selection channel. The
/// channel notifies on session changes so the fields track handle drags.
class _MoveSettings extends StatefulWidget {
  const _MoveSettings({required this.selectionCommands});

  final CanvasSelectionCommands? selectionCommands;

  @override
  State<_MoveSettings> createState() => _MoveSettingsState();
}

class _MoveSettingsState extends State<_MoveSettings> {
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _angle = TextEditingController();
  final _scale = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.selectionCommands?.addListener(_syncFromSession);
    _syncFromSession();
  }

  @override
  void didUpdateWidget(covariant _MoveSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.selectionCommands, widget.selectionCommands)) {
      oldWidget.selectionCommands?.removeListener(_syncFromSession);
      widget.selectionCommands?.addListener(_syncFromSession);
      _syncFromSession();
    }
  }

  @override
  void dispose() {
    widget.selectionCommands?.removeListener(_syncFromSession);
    _x.dispose();
    _y.dispose();
    _angle.dispose();
    _scale.dispose();
    super.dispose();
  }

  String _trim(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    return rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toString();
  }

  void _syncFromSession() {
    if (!mounted) {
      return;
    }
    final values = widget.selectionCommands?.transformValues;
    setState(() {
      _x.text = _trim(values?.tx ?? 0);
      _y.text = _trim(values?.ty ?? 0);
      _angle.text = _trim(values?.rotationDegrees ?? 0);
      _scale.text = _trim((values?.scale ?? 1) * 100);
    });
  }

  void _apply() {
    final commands = widget.selectionCommands;
    if (commands == null || !commands.hasSelection) {
      return;
    }
    commands.setTransformValues(
      tx: double.tryParse(_x.text) ?? 0,
      ty: double.tryParse(_y.text) ?? 0,
      rotationDegrees: double.tryParse(_angle.text) ?? 0,
      scale: (double.tryParse(_scale.text) ?? 100) / 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSelection = widget.selectionCommands?.hasSelection ?? false;
    return ListView(
      key: const ValueKey<String>('tool-settings-move'),
      padding: const EdgeInsets.all(12),
      children: [
        Text('Move / Transform', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          hasSelection
              ? 'Values apply to the selection\'s transform box '
                    '(Enter confirms, Esc reverts).'
              : 'Select a region first — the box appears on it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                keyValue: 'move-x-field',
                label: 'X',
                controller: _x,
                enabled: hasSelection,
                onSubmitted: _apply,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                keyValue: 'move-y-field',
                label: 'Y',
                controller: _y,
                enabled: hasSelection,
                onSubmitted: _apply,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                keyValue: 'move-angle-field',
                label: 'Angle°',
                controller: _angle,
                enabled: hasSelection,
                onSubmitted: _apply,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumberField(
                keyValue: 'move-scale-field',
                label: 'Scale %',
                controller: _scale,
                enabled: hasSelection,
                onSubmitted: _apply,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // R20-D3 mesh warp: opens the control grid on the selection
        // (Enter commits the triangulated warp; Esc reverts). Perspective
        // rides the Ctrl+corner gesture on the box itself (R20-D2).
        OutlinedButton.icon(
          key: const ValueKey<String>('move-mesh-warp-button'),
          onPressed: hasSelection
              ? () => widget.selectionCommands?.beginMeshTransform()
              : null,
          icon: const Icon(Icons.grid_4x4, size: 16),
          label: const Text('Mesh Warp'),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.keyValue,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onSubmitted,
  });

  final String keyValue;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: ValueKey<String>(keyValue),
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => onSubmitted(),
    );
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
        FieldSlider(
          key: const ValueKey<String>('fill-tolerance-slider'),
          min: 0,
          max: 128,
          divisions: 128,
          value: options.tolerance.toDouble().clamp(0, 128),
          label: 'Tolerance',
          valueText: '${options.tolerance}',
          onChanged: (value) =>
              onChanged(options.copyWith(tolerance: value.round())),
        ),
        const SizedBox(height: 8),
        FieldSlider(
          key: const ValueKey<String>('fill-expand-slider'),
          min: 0,
          max: 4,
          divisions: 4,
          value: options.expandPx.toDouble().clamp(0, 4),
          label: 'Expand',
          valueText: '${options.expandPx} px',
          onChanged: (value) =>
              onChanged(options.copyWith(expandPx: value.round())),
        ),
        const SizedBox(height: 8),
        FieldSlider(
          key: const ValueKey<String>('fill-gap-close-slider'),
          min: 0,
          max: 8,
          divisions: 8,
          value: options.gapClosePx.toDouble().clamp(0, 8),
          label: 'Gap Close',
          valueText: options.gapClosePx == 0
              ? 'off'
              : '${options.gapClosePx} px',
          onChanged: (value) =>
              onChanged(options.copyWith(gapClosePx: value.round())),
        ),
        SwitchListTile(
          key: const ValueKey<String>('fill-anti-alias-switch'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Anti-alias'),
          value: options.antiAlias,
          onChanged: (value) => onChanged(options.copyWith(antiAlias: value)),
        ),
        SwitchListTile(
          key: const ValueKey<String>('fill-extend-beyond-canvas-switch'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Fill Beyond Canvas'),
          subtitle: const Text('Open regions refuse to fill'),
          value: options.extendBeyondCanvas,
          onChanged: (value) =>
              onChanged(options.copyWith(extendBeyondCanvas: value)),
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
