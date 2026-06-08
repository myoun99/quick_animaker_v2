import 'package:flutter/material.dart';

import '../../controllers/cut_list_helpers.dart';
import '../../models/cut_id.dart';

class CutListBar extends StatelessWidget {
  const CutListBar({
    super.key,
    required this.entries,
    this.onCutSelected,
    this.onNewCut,
    this.onRenameActiveCut,
    this.onDuplicateActiveCut,
    this.onDeleteActiveCut,
  });

  final List<CutListEntry> entries;
  final ValueChanged<CutId>? onCutSelected;
  final VoidCallback? onNewCut;
  final VoidCallback? onRenameActiveCut;
  final VoidCallback? onDuplicateActiveCut;
  final VoidCallback? onDeleteActiveCut;

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
              _CutListChip(entry: entries[index], onSelected: onCutSelected),
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
                key: const ValueKey<String>('duplicate-cut-button'),
                tooltip: 'Duplicate Cut',
                icon: Icons.content_copy,
                onPressed: onDuplicateActiveCut,
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
      onDuplicateActiveCut != null ||
      onDeleteActiveCut != null;
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
