import 'package:flutter/material.dart';

import '../../controllers/cut_list_helpers.dart';
import '../../models/cut_id.dart';
import '../../models/track_id.dart';

typedef CutReorderedCallback =
    void Function({
      required CutId draggedCutId,
      required TrackId targetTrackId,
      required int targetCutIndex,
    });

class CutListBar extends StatelessWidget {
  const CutListBar({
    super.key,
    required this.entries,
    this.onCutSelected,
    this.onNewCut,
    this.onRenameActiveCut,
    this.onEditActiveCutNote,
    this.onDuplicateActiveCut,
    this.onMoveActiveCutLeft,
    this.onMoveActiveCutRight,
    this.onDeleteActiveCut,
    this.onCutReordered,
  });

  final List<CutListEntry> entries;
  final ValueChanged<CutId>? onCutSelected;
  final VoidCallback? onNewCut;
  final VoidCallback? onRenameActiveCut;
  final VoidCallback? onEditActiveCutNote;
  final VoidCallback? onDuplicateActiveCut;
  final VoidCallback? onMoveActiveCutLeft;
  final VoidCallback? onMoveActiveCutRight;
  final VoidCallback? onDeleteActiveCut;
  final CutReorderedCallback? onCutReordered;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink(key: ValueKey<String>('cut-list-bar-empty'));
    }

    final theme = Theme.of(context);

    return DecoratedBox(
      key: const ValueKey<String>('cut-list-bar'),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cuts:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            for (var index = 0; index < entries.length; index += 1) ...[
              _ReorderableCutListChip(
                entry: entries[index],
                canReorder: onCutReordered != null && entries.length > 1,
                onSelected: onCutSelected,
                onCutReordered: onCutReordered,
              ),
              if (index < entries.length - 1) const SizedBox(width: 4),
            ],
            if (_hasCommandActions) ...[
              const SizedBox(width: 6),
              _CutCommandIconButton(
                key: const ValueKey<String>('new-cut-button'),
                tooltip: 'New Cut',
                icon: Icons.add,
                onPressed: onNewCut,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('rename-cut-button'),
                tooltip: 'Rename Cut',
                icon: Icons.edit_outlined,
                onPressed: onRenameActiveCut,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('edit-cut-note-button'),
                tooltip: 'Edit Cut Note',
                icon: Icons.note_alt_outlined,
                onPressed: onEditActiveCutNote,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('duplicate-cut-button'),
                tooltip: 'Duplicate Cut',
                icon: Icons.content_copy,
                onPressed: onDuplicateActiveCut,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('move-cut-left-button'),
                tooltip: 'Move Cut Left',
                icon: Icons.chevron_left,
                onPressed: onMoveActiveCutLeft,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('move-cut-right-button'),
                tooltip: 'Move Cut Right',
                icon: Icons.chevron_right,
                onPressed: onMoveActiveCutRight,
              ),
              _CutCommandIconButton(
                key: const ValueKey<String>('delete-cut-button'),
                tooltip: 'Delete Cut',
                icon: Icons.delete_outline,
                onPressed: onDeleteActiveCut,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasCommandActions =>
      onNewCut != null ||
      onRenameActiveCut != null ||
      onEditActiveCutNote != null ||
      onDuplicateActiveCut != null ||
      onMoveActiveCutLeft != null ||
      onMoveActiveCutRight != null ||
      onDeleteActiveCut != null;
}

class _ReorderableCutListChip extends StatelessWidget {
  const _ReorderableCutListChip({
    required this.entry,
    required this.canReorder,
    required this.onSelected,
    required this.onCutReordered,
  });

  final CutListEntry entry;
  final bool canReorder;
  final ValueChanged<CutId>? onSelected;
  final CutReorderedCallback? onCutReordered;

  @override
  Widget build(BuildContext context) {
    final chip = _CutListChip(entry: entry, onSelected: onSelected);
    if (!canReorder) {
      return chip;
    }

    return DragTarget<CutId>(
      onWillAcceptWithDetails: (details) => details.data != entry.cutId,
      onAcceptWithDetails: (details) {
        if (details.data == entry.cutId) {
          return;
        }

        onCutReordered?.call(
          draggedCutId: details.data,
          targetTrackId: entry.trackId,
          targetCutIndex: entry.cutIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Draggable<CutId>(
          data: entry.cutId,
          axis: Axis.horizontal,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: _CutListChip(entry: entry, onSelected: null),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.45, child: chip),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: isDropTarget
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
              borderRadius: BorderRadius.circular(999),
            ),
            child: chip,
          ),
        );
      },
    );
  }
}

class _CutCommandIconButton extends StatelessWidget {
  const _CutCommandIconButton({
    required super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 18,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _CutListChip extends StatelessWidget {
  const _CutListChip({required this.entry, required this.onSelected});

  final CutListEntry entry;
  final ValueChanged<CutId>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = entry.isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = entry.isActive
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final borderColor = entry.isActive
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final borderRadius = BorderRadius.circular(999);
    final tooltipMessage = _tooltipMessage;
    final semanticsLabel = _semanticsLabel;

    final chip = Container(
      key: ValueKey<String>('cut-list-entry-${entry.cutId.value}'),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: entry.isActive ? 1.5 : 1),
        borderRadius: borderRadius,
      ),
      padding: EdgeInsets.only(
        left: entry.isActive ? 6 : 8,
        top: 3,
        right: 8,
        bottom: 3,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.isActive) ...[
            Container(
              key: ValueKey<String>(
                'cut-list-entry-active-dot-${entry.cutId.value}',
              ),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foregroundColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              entry.cutName,
              key: ValueKey<String>(
                'cut-list-entry-label-${entry.cutId.value}',
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: theme.textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: entry.isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );

    final child = onSelected == null
        ? chip
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              mouseCursor: SystemMouseCursors.click,
              onTap: () => onSelected!(entry.cutId),
              child: chip,
            ),
          );

    return Tooltip(
      message: tooltipMessage,
      child: Semantics(
        button: onSelected != null,
        excludeSemantics: true,
        label: semanticsLabel,
        selected: entry.isActive,
        child: child,
      ),
    );
  }

  String get _tooltipMessage {
    if (entry.isActive) {
      return 'Active: ${entry.cutName}';
    }
    if (onSelected == null) {
      return 'Cut: ${entry.cutName}';
    }
    return 'Switch to ${entry.cutName}';
  }

  String get _semanticsLabel {
    if (entry.isActive) {
      return 'Active cut ${entry.cutName}';
    }
    if (onSelected == null) {
      return 'Cut ${entry.cutName}';
    }
    return 'Switch to cut ${entry.cutName}';
  }
}
