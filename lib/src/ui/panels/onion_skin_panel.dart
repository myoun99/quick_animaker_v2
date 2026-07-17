import 'package:flutter/material.dart';

import '../../models/onion_skin_settings.dart';
import '../widgets/field_slider.dart';

/// The onion-skin dock panel (P2, Callipeg's light-table language): the
/// master toggle, the Colors/Images mode, and one peg strip per side —
/// pegs count OUTWARD from the current drawing, each chip toggles its
/// unique drawing, the side slider scales the ghost opacities and the
/// swatches pick the side tint.
class OnionSkinPanel extends StatelessWidget {
  const OnionSkinPanel({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final OnionSkinSettings settings;
  final ValueChanged<OnionSkinSettings> onChanged;

  static const List<int> _beforeTints = [0xFFE53935, 0xFFFB8C00, 0xFF8E24AA];
  static const List<int> _afterTints = [0xFF43A047, 0xFF1E88E5, 0xFF00897B];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NO master switch (UI-R17 #5): onion applies PER LAYER via the
          // timeline rows' toggles — this panel only shapes the ghosts.
          Text('Onion Skin', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          SegmentedButton<OnionSkinMode>(
            key: const ValueKey<String>('onion-skin-mode-toggle'),
            segments: const [
              ButtonSegment(value: OnionSkinMode.colors, label: Text('Colors')),
              ButtonSegment(value: OnionSkinMode.images, label: Text('Images')),
            ],
            selected: {settings.mode},
            onSelectionChanged: (selection) =>
                onChanged(settings.copyWith(mode: selection.first)),
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 12),
          _sideSection(
            context,
            title: 'Before',
            keyPrefix: 'before',
            pegs: settings.beforePegs,
            tint: settings.tintBefore,
            tints: _beforeTints,
            onPegsChanged: (pegs) =>
                onChanged(settings.copyWith(beforePegs: pegs)),
            onTintChanged: (tint) =>
                onChanged(settings.copyWith(tintBefore: tint)),
          ),
          const SizedBox(height: 12),
          _sideSection(
            context,
            title: 'After',
            keyPrefix: 'after',
            pegs: settings.afterPegs,
            tint: settings.tintAfter,
            tints: _afterTints,
            onPegsChanged: (pegs) =>
                onChanged(settings.copyWith(afterPegs: pegs)),
            onTintChanged: (tint) =>
                onChanged(settings.copyWith(tintAfter: tint)),
          ),
        ],
      ),
    );
  }

  Widget _sideSection(
    BuildContext context, {
    required String title,
    required String keyPrefix,
    required List<OnionPeg> pegs,
    required int tint,
    required List<int> tints,
    required ValueChanged<List<OnionPeg>> onPegsChanged,
    required ValueChanged<int> onTintChanged,
  }) {
    final theme = Theme.of(context);
    // The side slider = the NEAREST peg's opacity; the further pegs scale
    // proportionally so the falloff shape survives the drag.
    final baseOpacity = pegs.isEmpty ? 0.0 : pegs.first.opacity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            for (var index = 0; index < pegs.length; index += 1)
              FilterChip(
                key: ValueKey<String>('onion-peg-$keyPrefix-${index + 1}'),
                label: Text('${index + 1}'),
                selected: pegs[index].enabled,
                // Selection reads from the chip color alone — the M3
                // checkmark widens the chip and the strip jumps (R11-①).
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (enabled) => onPegsChanged([
                  for (var i = 0; i < pegs.length; i += 1)
                    i == index ? pegs[i].copyWith(enabled: enabled) : pegs[i],
                ]),
              ),
          ],
        ),
        Row(
          children: [
            const Icon(Icons.opacity, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: FieldSlider(
                key: ValueKey<String>('onion-opacity-$keyPrefix'),
                min: 0.05,
                max: 1,
                value: baseOpacity.clamp(0.05, 1.0),
                valueText: '${(baseOpacity.clamp(0.05, 1.0) * 100).round()}%',
                displayFactor: 100,
                height: 18,
                onChanged: (value) {
                  final scale = baseOpacity <= 0 ? 0.0 : value / baseOpacity;
                  onPegsChanged([
                    for (final peg in pegs)
                      peg.copyWith(
                        opacity: baseOpacity <= 0
                            ? value
                            : (peg.opacity * scale).clamp(0.0, 1.0),
                      ),
                  ]);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final candidate in tints)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  key: ValueKey<String>(
                    'onion-tint-$keyPrefix-'
                    '${candidate.toRadixString(16)}',
                  ),
                  onTap: () => onTintChanged(candidate),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Color(candidate),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tint == candidate
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outlineVariant,
                        width: tint == candidate ? 2 : 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
