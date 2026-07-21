import 'package:flutter/material.dart';

import '../../models/folder_id.dart';
import '../../models/layer_folder.dart';
import 'layer_label_controls.dart';
import 'timeline_grid_metrics.dart';

/// The rail row of a folder HEADER (L5): indent + collapse twirl + name +
/// eye. The name is display/right-click only — folders are never the
/// active editing target; their frame band is the aggregate block.
class TimelineFolderControlsRow extends StatelessWidget {
  const TimelineFolderControlsRow({
    super.key,
    required this.folder,
    required this.depth,
    required this.metrics,
    this.onToggleCollapsed,
    this.onToggleVisibility,
    this.onRename,
    this.onDissolve,
    this.lanesExpanded = false,
    this.onToggleLanes,
  });

  final LayerFolder folder;
  final int depth;
  final TimelineGridMetrics metrics;
  final ValueChanged<FolderId>? onToggleCollapsed;
  final ValueChanged<FolderId>? onToggleVisibility;
  final ValueChanged<FolderId>? onRename;
  final ValueChanged<FolderId>? onDissolve;

  /// The folder FX lane twirl (L5c) — null hides the button.
  final bool lanesExpanded;
  final ValueChanged<FolderId>? onToggleLanes;

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
    return GestureDetector(
      key: ValueKey<String>('timeline-folder-row-${folder.id}'),
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      onLongPressStart: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        width: metrics.layerControlsWidth - metrics.sectionLabelGutterWidth,
        height: metrics.layerRowHeight,
        padding: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          // A quiet tint tells folders apart from layer rows without
          // stealing the selection language (background = selection).
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
            InkWell(
              key: ValueKey<String>('timeline-folder-twirl-${folder.id}'),
              onTap: onToggleCollapsed == null
                  ? null
                  : () => onToggleCollapsed!(folder.id),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 20,
                height: 24,
                child: Icon(
                  folder.collapsed
                      ? Icons.arrow_right
                      : Icons.arrow_drop_down,
                  size: 16,
                ),
              ),
            ),
            Icon(
              folder.collapsed ? Icons.folder : Icons.folder_open,
              size: 15,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                folder.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            // The folder FX lane twirl (L5c): the fx glyph opens the
            // folder's own Transform lanes ("폴더째 배치" — the A-cel
            // instancing story's last step).
            if (onToggleLanes != null)
              InkWell(
                key: ValueKey<String>('timeline-folder-lanes-${folder.id}'),
                onTap: () => onToggleLanes!(folder.id),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 22,
                  height: 24,
                  child: Icon(
                    Icons.animation,
                    size: 14,
                    color: lanesExpanded
                        ? colorScheme.primary
                        : colorScheme.outline.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (onToggleVisibility != null)
              SizedBox(
                width: 26,
                height: 26,
                child: IconButton(
                  key: ValueKey<String>(
                    'timeline-folder-visibility-${folder.id}',
                  ),
                  tooltip: folder.isVisible
                      ? 'Hide folder'
                      : 'Show folder',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  icon: Icon(
                    folder.isVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 16,
                    color: folder.isVisible
                        ? null
                        : colorScheme.outline.withValues(alpha: 0.6),
                  ),
                  onPressed: () => onToggleVisibility!(folder.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
