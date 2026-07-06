import 'package:flutter/material.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../panels/editor_panel_frame.dart';
import 'brush_tip_preview.dart';

/// The brush library panel: one row per preset with a tip preview.
///
/// Split out of [BrushSettingsPanel] so the dock reads Clip-Studio-like —
/// brush list on top, tool properties below — while staying icon-first.
/// Tapping a row applies the preset; the row's close affordance deletes it.
/// The header hosts the import and save-as-preset actions.
class BrushPresetPanel extends StatelessWidget {
  const BrushPresetPanel({
    super.key,
    required this.presets,
    this.selectedPresetId,
    this.onPresetApplied,
    this.onPresetSaveRequested,
    this.onPresetDeleted,
    this.onPresetImportRequested,
  });

  final List<BrushPreset> presets;

  /// The last-applied preset; its row is highlighted. Tweaking settings
  /// afterwards keeps the highlight (the row is a starting point, not a
  /// live equality check).
  final BrushPresetId? selectedPresetId;

  final ValueChanged<BrushPreset>? onPresetApplied;
  final VoidCallback? onPresetSaveRequested;
  final ValueChanged<BrushPresetId>? onPresetDeleted;
  final VoidCallback? onPresetImportRequested;

  /// Caps the list; beyond this the list scrolls inside the panel instead
  /// of growing the dock.
  static const double _maxListHeight = 312;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return EditorPanelFrame(
      title: 'Brushes',
      bodyPadding: const EdgeInsets.all(5),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPresetImportRequested != null)
            IconButton(
              key: const ValueKey<String>('brush-preset-import-button'),
              icon: const Icon(Icons.file_open_outlined, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Import brushes (.abr, .sut, .sutg)',
              onPressed: onPresetImportRequested,
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
      child: presets.isEmpty
          ? SizedBox(
              height: 56,
              child: Center(
                child: Icon(
                  Icons.brush_outlined,
                  size: 18,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxListHeight),
              child: ListView.builder(
                key: const ValueKey<String>('brush-preset-list'),
                shrinkWrap: true,
                itemCount: presets.length,
                itemBuilder: (context, index) {
                  final preset = presets[index];
                  return _BrushPresetRow(
                    preset: preset,
                    selected: preset.id == selectedPresetId,
                    onApplied: onPresetApplied,
                    onDeleted: onPresetDeleted,
                  );
                },
              ),
            ),
    );
  }
}

class _BrushPresetRow extends StatelessWidget {
  const _BrushPresetRow({
    required this.preset,
    required this.selected,
    required this.onApplied,
    required this.onDeleted,
  });

  final BrushPreset preset;
  final bool selected;
  final ValueChanged<BrushPreset>? onApplied;
  final ValueChanged<BrushPresetId>? onDeleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? colorScheme.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          // Key kept from the former chip UI so existing flows/tests hold.
          key: ValueKey<String>('brush-preset-chip-${preset.id.value}'),
          borderRadius: BorderRadius.circular(6),
          onTap: onApplied == null ? null : () => onApplied!(preset),
          child: SizedBox(
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 5,
                  child: selected
                      ? Center(
                          child: Container(
                            width: 2,
                            height: 20,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        )
                      : null,
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: BrushTipPreview(settings: preset.settings),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (onDeleted != null)
                  IconButton(
                    key: ValueKey<String>(
                      'brush-preset-delete-${preset.id.value}',
                    ),
                    icon: const Icon(Icons.close, size: 14),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    padding: EdgeInsets.zero,
                    color: colorScheme.onSurfaceVariant,
                    tooltip: 'Delete preset',
                    onPressed: () => onDeleted!(preset.id),
                  ),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
