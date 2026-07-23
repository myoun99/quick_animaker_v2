import 'package:flutter/material.dart';

import '../../models/app_language.dart' show AppLanguage;
import '../../models/folder_id.dart';
import '../../models/layer_blend_mode.dart';
import '../../models/layer_folder.dart';
import '../theme/app_theme.dart';
import '../widgets/field_slider.dart';
import '../widgets/panel_flyout.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';

/// The rail row of a folder HEADER (L5).
///
/// R27 #23/#25/#29: the folder row is a LAYER ROW that happens to hold a
/// folder — same surface, same border, same reserved column slots in the
/// same order, so the eye / fx / opacity / blend columns line up under
/// the legend header exactly like every other row. Only the leading
/// slots differ in content (fold twirl + folder glyph as the type
/// button), and columns a folder has no meaning for stay
/// reserved-but-empty, the rail's standing rule.
class TimelineFolderControlsRow extends StatelessWidget {
  const TimelineFolderControlsRow({
    super.key,
    required this.folder,
    required this.depth,
    required this.metrics,
    this.active = false,
    this.onSelect,
    this.onToggleCollapsed,
    this.onToggleVisibility,
    this.onRename,
    this.onDissolve,
    this.lanesExpanded = false,
    this.onToggleLanes,
    this.onOpacityChanged,
    this.onOpacityChangeEnd,
    this.onBlendModeSelected,
    this.blendLanguage = AppLanguage.en,
  });

  final LayerFolder folder;
  final int depth;
  final TimelineGridMetrics metrics;

  /// R27 #24: folders select like layers — the row wears the selection
  /// background, the one selection language this rail speaks.
  final bool active;
  final ValueChanged<FolderId>? onSelect;

  final ValueChanged<FolderId>? onToggleCollapsed;
  final ValueChanged<FolderId>? onToggleVisibility;
  final ValueChanged<FolderId>? onRename;
  final ValueChanged<FolderId>? onDissolve;

  /// The folder FX lane twirl (L5c) — null hides the button.
  final bool lanesExpanded;
  final ValueChanged<FolderId>? onToggleLanes;

  /// R27 #29: the folder's own opacity and blend, on the layer controls'
  /// contract (preview per move, one write on release).
  final void Function(FolderId folderId, double opacity)? onOpacityChanged;
  final void Function(FolderId folderId, double opacity)? onOpacityChangeEnd;
  final void Function(FolderId folderId, LayerBlendMode mode)?
  onBlendModeSelected;
  final AppLanguage blendLanguage;

  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject();
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & (overlay as RenderBox).size,
      ),
      items: [
        if (onRename != null)
          PopupMenuItem<String>(
            key: ValueKey<String>('timeline-folder-rename-${folder.id}'),
            value: 'rename',
            child: const Text('Rename Folder…'),
          ),
        if (onDissolve != null)
          PopupMenuItem<String>(
            key: ValueKey<String>('timeline-folder-dissolve-${folder.id}'),
            value: 'dissolve',
            child: const Text('Dissolve Folder'),
          ),
      ],
    );
    switch (selected) {
      case 'rename':
        onRename?.call(folder.id);
      case 'dissolve':
        onDissolve?.call(folder.id);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.outlineVariant;
    // R27 #25: the SAME surface and selection colours as a layer row —
    // the old private tint made folders read as a foreign kind of row.
    final activeColor = colorScheme.secondaryContainer.withValues(alpha: 0.55);
    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: InkWell(
        key: ValueKey<String>('timeline-folder-row-${folder.id}'),
        onTap: onSelect == null ? null : () => onSelect!(folder.id),
        hoverColor: Colors.transparent,
        child: Container(
          width: metrics.layerControlsWidth - metrics.sectionLabelGutterWidth,
          height: metrics.layerRowHeight,
          padding: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: active ? activeColor : colorScheme.surface,
            border: Border(
              left: BorderSide(color: borderColor),
              right: BorderSide(color: borderColor),
              bottom: BorderSide(color: borderColor),
            ),
          ),
          child: Row(
            children: [
              const LayerSectionBandCell(),
              SizedBox(width: 8.0 + depth * 12.0),
              // The lane-twirl column carries the FOLD twirl.
              InkWell(
                key: ValueKey<String>('timeline-folder-twirl-${folder.id}'),
                onTap: onToggleCollapsed == null
                    ? null
                    : () => onToggleCollapsed!(folder.id),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: layerLaneToggleSlotWidth,
                  height: 24,
                  child: Icon(
                    folder.collapsed
                        ? Icons.arrow_right
                        : Icons.arrow_drop_down,
                    size: 16,
                  ),
                ),
              ),
              // Folders carry no timesheet column and no mark chip — the
              // slots stay reserved so every later column stays aligned.
              const SizedBox(width: layerTimesheetSlotWidth),
              const SizedBox(width: layerControlChipGap),
              const SizedBox(width: layerMarkSlotWidth),
              const SizedBox(width: layerControlChipGap),
              // The TYPE button's column: the folder glyph.
              SizedBox(
                width: 22,
                height: 24,
                child: Center(
                  child: Icon(
                    folder.collapsed ? Icons.folder : Icons.folder_open,
                    key: ValueKey<String>('timeline-folder-icon-${folder.id}'),
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    folder.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: layerFillReferenceSlotWidth),
              // R27 #26: the folder's fx column IS the layer's fx button —
              // same glyph, same slot, same meaning (it opens the row's
              // Transform group). The old `Icons.animation` chip read as a
              // different feature entirely.
              if (onToggleLanes != null)
                SizedBox(
                  width: layerFxSlotWidth,
                  height: 26,
                  child: IconButton(
                    key: ValueKey<String>('timeline-folder-lanes-${folder.id}'),
                    tooltip: 'Folder FX',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: layerFxSlotWidth,
                      height: 26,
                    ),
                    icon: Text(
                      'fx',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        color: lanesExpanded
                            ? AppColors.accent
                            : colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    onPressed: () => onToggleLanes!(folder.id),
                  ),
                )
              else
                const SizedBox(width: layerFxSlotWidth),
              const SizedBox(width: layerOnionSlotWidth),
              SizedBox(
                width: layerVisibilitySlotWidth,
                height: 26,
                child: onToggleVisibility == null
                    ? null
                    : IconButton(
                        key: ValueKey<String>(
                          'timeline-folder-visibility-${folder.id}',
                        ),
                        tooltip: folder.isVisible
                            ? 'Hide folder'
                            : 'Show folder',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: layerVisibilitySlotWidth,
                          height: 26,
                        ),
                        icon: Icon(
                          folder.isVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 18,
                        ),
                        onPressed: () => onToggleVisibility!(folder.id),
                      ),
              ),
              const SizedBox(width: layerMuteSlotWidth),
              // R27 #29: the folder's own opacity — its composed buffer's,
              // not each member's (LayerFolder.opacity, L3).
              SizedBox(
                width: layerOpacitySlotWidth,
                child: onOpacityChanged == null
                    ? null
                    : FieldSlider(
                        key: ValueKey<String>(
                          'timeline-folder-opacity-${folder.id}',
                        ),
                        min: 0,
                        max: 1,
                        value: folder.opacity.clamp(0.0, 1.0).toDouble(),
                        valueText: '${(folder.opacity * 100).round()}%',
                        valueTextBuilder: (next) => '${(next * 100).round()}%',
                        displayFactor: 100,
                        height: 18,
                        onChanged: (opacity) =>
                            onOpacityChanged!(folder.id, opacity),
                        onChangeEnd: onOpacityChangeEnd == null
                            ? null
                            : (opacity) =>
                                  onOpacityChangeEnd!(folder.id, opacity),
                      ),
              ),
              // ...and its blend, in the layer rows' blend column.
              if (onBlendModeSelected != null)
                _FolderBlendChip(
                  folder: folder,
                  language: blendLanguage,
                  onSelected: onBlendModeSelected!,
                )
              else
                const SizedBox(width: layerBlendSlotWidth),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderBlendChip extends StatelessWidget {
  const _FolderBlendChip({
    required this.folder,
    required this.language,
    required this.onSelected,
  });

  final LayerFolder folder;
  final AppLanguage language;
  final void Function(FolderId folderId, LayerBlendMode mode) onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nonNormal = folder.blendMode != LayerBlendMode.normal;
    // R28 #2: the same shared blend BUTTON the layer rows and the tool
    // settings use — caret dropped, centered in the rail's blend slot.
    return SizedBox(
      width: layerBlendSlotWidth,
      height: 20,
      child: Center(
        child: PanelFlyoutButton(
          key: ValueKey<String>('timeline-folder-blend-${folder.id}'),
          label: folder.blendMode.labelFor(language),
          tooltip: 'Folder blend mode',
          showCaret: false,
          expand: true,
          fontSize: 9.5,
          fontWeight: nonNormal ? FontWeight.w700 : FontWeight.w400,
          labelColor: nonNormal
              ? AppColors.accent
              : colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          entriesBuilder: () => [
            for (final mode in LayerBlendMode.values)
              PanelFlyoutItem(
                keyValue: 'timeline-folder-blend-option-${mode.name}',
                label: mode.labelFor(language),
                checked: mode == folder.blendMode,
                onSelected: () => onSelected(folder.id, mode),
              ),
          ],
        ),
      ),
    );
  }
}
