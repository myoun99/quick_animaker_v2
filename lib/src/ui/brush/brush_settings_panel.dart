import 'package:flutter/material.dart';

import '../../models/app_language.dart';
import '../../models/brush_blend_mode.dart';
import '../panels/editor_panel_frame.dart';
import '../widgets/field_slider.dart';
import '../widgets/panel_flyout.dart';
import 'brush_tool_state.dart';

/// Editable brush tool properties — the CSP-style GROUPED layout (BB-2,
/// user-picked candidate B, 07-22): 브러시 크기 / 잉크 / 브러시 끝 /
/// 보정, with the BRUSH BLEND dropdown living in the ink group exactly
/// where Clip Studio keeps its 합성 모드. The color swatches and the tip
/// shape segment are GONE (R26 #11): color belongs to the color wheel
/// panel, the tip belongs to brush presets.
///
/// The brush library lives in the separate [BrushPresetPanel]; this panel
/// only mutates the live [BrushToolState].
class BrushSettingsPanel extends StatelessWidget {
  const BrushSettingsPanel({
    super.key,
    required this.state,
    required this.onChanged,
    this.language = AppLanguage.en,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;

  /// The program language — the blend mode labels localize (ja = CSP
  /// terms); the rest of the panel keeps the incremental-coverage rule.
  final AppLanguage language;

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
          _GroupHeader('Brush size', first: true),
          _PanelSlider(
            label: 'Size',
            valueLabel: sizeLabel,
            value: BrushToolState.clampSize(state.size),
            min: BrushToolState.minSize,
            max: BrushToolState.maxSize,
            // Log mapping: the track's left half covers the small sizes
            // where precision matters (CSP-style 1..2000 px range).
            scale: FieldSliderScale.exponential,
            keyValue: 'brush-tool-size-slider',
            onChanged: (value) => onChanged(state.copyWith(size: value)),
          ),
          _GroupHeader('Ink'),
          _BlendModeRow(state: state, onChanged: onChanged, language: language),
          _PanelSlider(
            label: 'Opacity',
            valueLabel: opacityLabel,
            value: BrushToolState.clampOpacity(state.opacity),
            min: 0,
            max: 1,
            displayFactor: 100,
            keyValue: 'brush-tool-opacity-slider',
            onChanged: (value) => onChanged(state.copyWith(opacity: value)),
          ),
          _PanelSlider(
            label: 'Flow',
            valueLabel: flowLabel,
            value: BrushToolState.clampUnit(state.flow),
            min: 0,
            max: 1,
            displayFactor: 100,
            keyValue: 'brush-tool-flow-slider',
            onChanged: (value) => onChanged(state.copyWith(flow: value)),
          ),
          _GroupHeader('Brush tip'),
          _PanelSlider(
            label: 'Hardness',
            valueLabel: hardnessLabel,
            value: BrushToolState.clampUnit(state.hardness),
            min: 0,
            max: 1,
            displayFactor: 100,
            keyValue: 'brush-tool-hardness-slider',
            onChanged: (value) => onChanged(state.copyWith(hardness: value)),
          ),
          _PanelSlider(
            label: 'Roundness',
            valueLabel: roundnessLabel,
            value: BrushToolState.clampRoundness(state.roundness),
            min: BrushToolState.minRoundness,
            max: 1,
            displayFactor: 100,
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
          _PanelSlider(
            label: 'Spacing',
            valueLabel: spacingLabel,
            value: BrushToolState.clampSpacing(state.spacing),
            min: BrushToolState.minSpacing,
            max: BrushToolState.maxSpacing,
            scale: FieldSliderScale.exponential,
            displayFactor: 100,
            keyValue: 'brush-tool-spacing-slider',
            onChanged: (value) => onChanged(state.copyWith(spacing: value)),
          ),
          _GroupHeader('Correction'),
          // Pull-string stabilization (P7): a hand-feel setting, kept OUT
          // of brush presets on purpose.
          _PanelSlider(
            label: 'Stabilizer',
            valueLabel: '${state.stabilizerStrength.round()}',
            value: BrushToolState.clampStabilizerStrength(
              state.stabilizerStrength,
            ),
            min: 0,
            max: 100,
            keyValue: 'brush-tool-stabilizer-slider',
            onChanged: (value) =>
                onChanged(state.copyWith(stabilizerStrength: value)),
          ),
          // Pressure toggles survive until BB-3 lands the per-setting
          // pressure CURVES (the popup editor replaces both switches).
          _GroupHeader('Pen pressure'),
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
        ],
      ),
    );
  }
}

/// The CSP category rule: a small header over each settings group, a
/// hairline separating it from the group above.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label, {this.first = false});

  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Divider(
                height: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The BRUSH BLEND dropdown (BB-2): the ink group's first row, the
/// PS/CSP dropdown vocabulary — the label IS the current mode. The
/// ERASER tool locks it to 消去/Erase (the eraser IS the erase blend);
/// the flyout stands down there.
class _BlendModeRow extends StatelessWidget {
  const _BlendModeRow({
    required this.state,
    required this.onChanged,
    required this.language,
  });

  final BrushToolState state;
  final ValueChanged<BrushToolState> onChanged;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = state.tool == CanvasTool.eraser;
    final mode = locked ? BrushBlendMode.erase : state.brushBlendMode;
    if (locked) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          key: const ValueKey<String>('brush-tool-blend-locked'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  mode.labelFor(language),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('Blend', style: theme.textTheme.labelSmall),
          ),
          PanelFlyoutButton(
            key: const ValueKey<String>('brush-tool-blend-menu-button'),
            label: mode.labelFor(language),
            tooltip: 'Brush blend mode',
            entriesBuilder: () => [
              for (final candidate in BrushBlendMode.values)
                PanelFlyoutItem(
                  keyValue: 'brush-tool-blend-${candidate.name}',
                  label: candidate.labelFor(language),
                  checked: candidate == mode,
                  onSelected: () =>
                      onChanged(state.copyWith(brushBlendMode: candidate)),
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
    this.scale = FieldSliderScale.linear,
    this.displayFactor = 1,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final String keyValue;
  final ValueChanged<double> onChanged;
  final FieldSliderScale scale;
  final double displayFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FieldSlider(
        key: ValueKey<String>(keyValue),
        value: value,
        min: min,
        max: max,
        label: label,
        valueText: valueLabel,
        scale: scale,
        displayFactor: displayFactor,
        onChanged: onChanged,
      ),
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

