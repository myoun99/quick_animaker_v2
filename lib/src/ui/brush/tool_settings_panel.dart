import 'package:flutter/material.dart';

import '../../models/app_language.dart';
import '../../services/canvas_flood_fill.dart';
import '../../services/canvas_selection.dart';
import '../../services/canvas_selection_region.dart';
import '../widgets/drag_value_label.dart';
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
    this.language = AppLanguage.en,
  });

  /// The program language (BB-2): the brush blend labels localize
  /// (ja = CSP terms); everything else keeps incremental coverage.
  final AppLanguage language;

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
        return BrushSettingsPanel(
          state: state,
          onChanged: onChanged,
          language: language,
        );
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
          selectionCommands: selectionCommands,
          language: language,
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
    required this.selectionCommands,
    required this.language,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;
  final SelectionMaskOptions maskOptions;
  final ValueChanged<SelectionMaskOptions>? onMaskOptionsChanged;
  final CanvasSelectionCommands? selectionCommands;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onMask = onMaskOptionsChanged;
    final commands = selectionCommands;
    return ListView(
      key: const ValueKey<String>('tool-settings-selection'),
      padding: const EdgeInsets.all(12),
      children: [
        // R26 #12: the rectangle/lasso CHOICE lives in the tool library
        // (two tools there), so the settings panel no longer duplicates
        // it — only the mask knobs remain.
        Text('Select', style: theme.textTheme.titleSmall),
        // R26 #16: 갱신 / 추가 / 삭제 / 선택중 — how the next drag folds
        // into the region already selected. Default 추가 (유저 원문).
        if (commands != null) ...[
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: commands,
            builder: (context, _) => _SelectionModeRow(
              mode: commands.combineMode,
              language: language,
              onChanged: (mode) => commands.combineMode = mode,
            ),
          ),
        ],
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

/// R26 #16: the four selection modes as one segmented row — the same
/// "selection shows in COLOR only" rule the rest of the app follows
/// ([[ui-selection-style]]: no check marks).
class _SelectionModeRow extends StatelessWidget {
  const _SelectionModeRow({
    required this.mode,
    required this.language,
    required this.onChanged,
  });

  final SelectionCombineMode mode;
  final AppLanguage language;
  final ValueChanged<SelectionCombineMode> onChanged;

  static const Map<SelectionCombineMode, IconData> _icons = {
    SelectionCombineMode.replace: Icons.crop_square,
    SelectionCombineMode.add: Icons.add_box_outlined,
    SelectionCombineMode.subtract: Icons.indeterminate_check_box_outlined,
    SelectionCombineMode.intersect: Icons.join_inner,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      key: const ValueKey<String>('selection-mode-row'),
      children: [
        for (final candidate in SelectionCombineMode.values)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              key: ValueKey<String>('selection-mode-${candidate.name}'),
              tooltip: candidate.labelFor(language),
              onPressed: () => onChanged(candidate),
              icon: Icon(_icons[candidate]),
              iconSize: 20,
              isSelected: candidate == mode,
              style: IconButton.styleFrom(
                foregroundColor: candidate == mode
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                backgroundColor: candidate == mode
                    ? colorScheme.surfaceContainerHigh
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
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
  // The live channel values, synced from the session at rest and owned
  // locally during a label drag (R26 #14: the deferred session ping must
  // not eat drag steps).
  double _tx = 0;
  double _ty = 0;
  double _angleDeg = 0;
  double _scalePct = 100;

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
      _tx = values?.tx ?? 0;
      _ty = values?.ty ?? 0;
      _angleDeg = values?.rotationDegrees ?? 0;
      _scalePct = (values?.scale ?? 1) * 100;
    });
  }

  /// Writes the four channels through the selection channel — with no
  /// session open this OPENS one (Ctrl+T semantics; R26 #13: with no
  /// selection the box opens on the whole picture).
  void _apply() {
    widget.selectionCommands?.setTransformValues(
      tx: _tx,
      ty: _ty,
      rotationDegrees: _angleDeg,
      scale: _scalePct.clamp(1.0, 3200.0) / 100,
    );
  }

  /// One transform channel as the shared DRAG VALUE READOUT (R26 #14 —
  /// the canvas bar's zoom/angle vocabulary: drag = a unit per pixel,
  /// double-tap = type).
  Widget _channel({
    required String keyValue,
    required String label,
    required String text,
    required void Function(double units) onDrag,
    required void Function(double parsed) onSubmit,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
        DragValueLabel(
          keyValue: keyValue,
          text: text,
          tooltip: 'Drag / double-tap',
          width: 72,
          textStyle: const TextStyle(fontSize: 12),
          onDragDelta: onDrag,
          onEditSubmit: (raw) {
            final parsed = double.tryParse(
              raw.replaceAll('%', '').replaceAll('°', '').trim(),
            );
            if (parsed != null) {
              onSubmit(parsed);
            }
          },
        ),
      ],
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
              : 'No selection: the box opens on the WHOLE picture '
                    '(Enter confirms, Esc reverts).',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        _channel(
          keyValue: 'move-x-field',
          label: 'X',
          text: _trim(_tx),
          onDrag: (units) {
            setState(() => _tx += units);
            _apply();
          },
          onSubmit: (value) {
            setState(() => _tx = value);
            _apply();
          },
        ),
        const SizedBox(height: 4),
        _channel(
          keyValue: 'move-y-field',
          label: 'Y',
          text: _trim(_ty),
          onDrag: (units) {
            setState(() => _ty += units);
            _apply();
          },
          onSubmit: (value) {
            setState(() => _ty = value);
            _apply();
          },
        ),
        const SizedBox(height: 4),
        _channel(
          keyValue: 'move-angle-field',
          label: 'Angle',
          text: '${_trim(_angleDeg)}°',
          onDrag: (units) {
            setState(() => _angleDeg += units);
            _apply();
          },
          onSubmit: (value) {
            setState(() => _angleDeg = value);
            _apply();
          },
        ),
        const SizedBox(height: 4),
        _channel(
          keyValue: 'move-scale-field',
          label: 'Scale',
          text: '${_trim(_scalePct)}%',
          onDrag: (units) {
            setState(() => _scalePct = (_scalePct + units).clamp(1.0, 3200.0));
            _apply();
          },
          onSubmit: (value) {
            setState(() => _scalePct = value.clamp(1.0, 3200.0));
            _apply();
          },
        ),
        const SizedBox(height: 12),
        // R20-D3 mesh warp: opens the control grid on the selection —
        // or, with none, on the whole picture (R26 #13). Enter commits
        // the triangulated warp; Esc reverts. Perspective rides the
        // Ctrl+corner gesture on the box itself (R20-D2).
        OutlinedButton.icon(
          key: const ValueKey<String>('move-mesh-warp-button'),
          onPressed: () => widget.selectionCommands?.beginMeshTransform(),
          icon: const Icon(Icons.grid_4x4, size: 16),
          label: const Text('Mesh Warp'),
        ),
      ],
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
