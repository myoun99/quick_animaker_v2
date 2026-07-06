import 'package:flutter/material.dart';

import '../../models/brush_preset.dart';
import '../../models/brush_preset_id.dart';
import '../panels/editor_panel_frame.dart';
import '../panels/panel_scrollbar.dart';
import 'brush_stroke_preview.dart';
import 'brush_tip_preview.dart';

/// Which row elements the brush list shows; every combination except
/// all-hidden is allowed (the options menu disables the last visible one).
enum _BrushPresetMenuAction { toggleIcon, toggleStroke, toggleName, delete }

/// The brush library panel: one row per preset with a tip icon, a stroke
/// preview, and the preset name — each hideable from the options menu.
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

  // View options are editor-session UI state local to the panel; they are
  // deliberately not persisted or project data.
  bool _showTipIcon = true;
  bool _showStrokePreview = true;
  bool _showName = true;

  int get _visibleElementCount =>
      (_showTipIcon ? 1 : 0) +
      (_showStrokePreview ? 1 : 0) +
      (_showName ? 1 : 0);

  /// A checked view toggle can be unchecked only while another element
  /// stays visible; rows must never go completely blank.
  bool _canToggleOff(bool currentlyVisible) {
    return !currentlyVisible || _visibleElementCount > 1;
  }

  void _onMenuSelected(_BrushPresetMenuAction action) {
    switch (action) {
      case _BrushPresetMenuAction.toggleIcon:
        setState(() => _showTipIcon = !_showTipIcon);
      case _BrushPresetMenuAction.toggleStroke:
        setState(() => _showStrokePreview = !_showStrokePreview);
      case _BrushPresetMenuAction.toggleName:
        setState(() => _showName = !_showName);
      case _BrushPresetMenuAction.delete:
        final selectedId = widget.selectedPresetId;
        if (selectedId != null) {
          widget.onPresetDeleted!(selectedId);
        }
    }
  }

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
          PopupMenuButton<_BrushPresetMenuAction>(
            key: const ValueKey<String>('brush-preset-menu-button'),
            tooltip: 'Brush options',
            icon: const Icon(Icons.more_vert, size: 16),
            padding: EdgeInsets.zero,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<_BrushPresetMenuAction>(
                key: const ValueKey<String>('brush-preset-view-icon-toggle'),
                value: _BrushPresetMenuAction.toggleIcon,
                height: 34,
                checked: _showTipIcon,
                enabled: _canToggleOff(_showTipIcon),
                child: const Text('Tip icon'),
              ),
              CheckedPopupMenuItem<_BrushPresetMenuAction>(
                key: const ValueKey<String>('brush-preset-view-stroke-toggle'),
                value: _BrushPresetMenuAction.toggleStroke,
                height: 34,
                checked: _showStrokePreview,
                enabled: _canToggleOff(_showStrokePreview),
                child: const Text('Stroke preview'),
              ),
              CheckedPopupMenuItem<_BrushPresetMenuAction>(
                key: const ValueKey<String>('brush-preset-view-name-toggle'),
                value: _BrushPresetMenuAction.toggleName,
                height: 34,
                checked: _showName,
                enabled: _canToggleOff(_showName),
                child: const Text('Name'),
              ),
              if (widget.onPresetDeleted != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem<_BrushPresetMenuAction>(
                  key: const ValueKey<String>('brush-preset-menu-delete'),
                  value: _BrushPresetMenuAction.delete,
                  height: 34,
                  enabled: widget.selectedPresetId != null,
                  child: const Text('Delete selected brush'),
                ),
              ],
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
                      showTipIcon: _showTipIcon,
                      showStrokePreview: _showStrokePreview,
                      showName: _showName,
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
    required this.showTipIcon,
    required this.showStrokePreview,
    required this.showName,
  });

  final BrushPreset preset;
  final bool selected;
  final ValueChanged<BrushPreset>? onApplied;
  final bool showTipIcon;
  final bool showStrokePreview;
  final bool showName;

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
                if (showTipIcon) ...[
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
                  const SizedBox(width: 6),
                ],
                Expanded(child: _rowBody(colorScheme)),
                const SizedBox(width: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rowBody(ColorScheme colorScheme) {
    final nameColor = selected
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;
    if (!showStrokePreview) {
      if (!showName) {
        return const SizedBox.shrink();
      }
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            preset.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: nameColor),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: BrushStrokePreview(settings: preset.settings),
        ),
        if (showName)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 132),
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                style: TextStyle(fontSize: 11, color: nameColor),
              ),
            ),
          ),
      ],
    );
  }
}
