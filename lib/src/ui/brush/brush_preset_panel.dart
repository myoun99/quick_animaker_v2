import 'package:flutter/material.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../panels/editor_panel_frame.dart';
import '../panels/panel_scrollbar.dart';
import 'brush_stroke_preview.dart';

/// The brush library panel: one row per preset with a stroke preview.
///
/// Split out of [BrushSettingsPanel] so the dock reads Clip-Studio-like —
/// brush list on top, tool properties below — while staying icon-first.
/// Tapping a row applies the preset. Destructive actions live behind the
/// header options menu (Photoshop-style) so a stray click cannot delete a
/// brush; the menu acts on the selected preset.
class BrushPresetPanel extends StatefulWidget {
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

  /// The last-applied preset; its row is highlighted and the options menu
  /// targets it. Tweaking settings afterwards keeps the highlight (the row
  /// is a starting point, not a live equality check).
  final BrushPresetId? selectedPresetId;

  final ValueChanged<BrushPreset>? onPresetApplied;
  final VoidCallback? onPresetSaveRequested;
  final ValueChanged<BrushPresetId>? onPresetDeleted;
  final VoidCallback? onPresetImportRequested;

  /// Caps the list; beyond this the list scrolls inside the panel instead
  /// of growing the dock.
  static const double _maxListHeight = 312;

  @override
  State<BrushPresetPanel> createState() => _BrushPresetPanelState();
}

class _BrushPresetPanelState extends State<BrushPresetPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return EditorPanelFrame(
      title: 'Brushes',
      bodyPadding: const EdgeInsets.all(5),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onPresetImportRequested != null)
            IconButton(
              key: const ValueKey<String>('brush-preset-import-button'),
              icon: const Icon(Icons.file_open_outlined, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Import brushes (.abr, .sut, .sutg)',
              onPressed: widget.onPresetImportRequested,
            ),
          if (widget.onPresetSaveRequested != null)
            IconButton(
              key: const ValueKey<String>('brush-preset-save-button'),
              icon: const Icon(Icons.add, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: 'Save current settings as preset',
              onPressed: widget.onPresetSaveRequested,
            ),
          if (widget.onPresetDeleted != null)
            PopupMenuButton<String>(
              key: const ValueKey<String>('brush-preset-menu-button'),
              tooltip: 'Brush options',
              icon: const Icon(Icons.more_vert, size: 16),
              padding: EdgeInsets.zero,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onSelected: (value) {
                final selectedId = widget.selectedPresetId;
                if (value == 'delete' && selectedId != null) {
                  widget.onPresetDeleted!(selectedId);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  key: const ValueKey<String>('brush-preset-menu-delete'),
                  value: 'delete',
                  height: 34,
                  enabled: widget.selectedPresetId != null,
                  child: const Text('Delete selected brush'),
                ),
              ],
            ),
        ],
      ),
      child: widget.presets.isEmpty
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
              constraints: const BoxConstraints(
                maxHeight: BrushPresetPanel._maxListHeight,
              ),
              child: PanelScrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  key: const ValueKey<String>('brush-preset-list'),
                  controller: _scrollController,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: panelScrollbarGutter),
                  itemCount: widget.presets.length,
                  itemBuilder: (context, index) {
                    final preset = widget.presets[index];
                    return _BrushPresetRow(
                      preset: preset,
                      selected: preset.id == widget.selectedPresetId,
                      onApplied: widget.onPresetApplied,
                    );
                  },
                ),
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
  });

  final BrushPreset preset;
  final bool selected;
  final ValueChanged<BrushPreset>? onApplied;

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
            height: 34,
            child: Row(
              children: [
                SizedBox(
                  width: 5,
                  child: selected
                      ? Center(
                          child: Container(
                            width: 2,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: BrushStrokePreview(settings: preset.settings),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 132),
                          margin: const EdgeInsets.only(right: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (selected
                                        ? colorScheme.surfaceContainerHigh
                                        : colorScheme.surface)
                                    .withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
