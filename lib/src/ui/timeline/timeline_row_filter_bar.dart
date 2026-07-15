import 'package:flutter/material.dart';

import '../../models/layer_mark.dart';
import '../theme/app_theme.dart';
import 'layer_label_controls.dart';
import 'timeline_row_filter.dart';

/// The active-filter chip bar shown above the rail while a row filter is on
/// (R2): one dismissible chip per active facet, plus a clear-all. Hidden
/// entirely when the filter is empty, so it costs nothing in the common
/// case. Both orientations mount it; [onSetRowFilter] applies edits.
class TimelineRowFilterBar extends StatelessWidget {
  const TimelineRowFilterBar({
    super.key,
    required this.rowFilter,
    required this.onSetRowFilter,
  });

  final TimelineRowFilter rowFilter;
  final ValueChanged<TimelineRowFilter> onSetRowFilter;

  @override
  Widget build(BuildContext context) {
    if (!rowFilter.isActive) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;

    Widget chip({
      required String keyValue,
      required String label,
      Color? swatch,
      required VoidCallback onRemove,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>(keyValue),
            borderRadius: BorderRadius.circular(3),
            onTap: onRemove,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (swatch != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: swatch,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.close, size: 10, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 12, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final mark in LayerMark.values)
                  if (rowFilter.markColors.contains(mark))
                    chip(
                      keyValue: 'row-filter-chip-mark-${mark.name}',
                      label: layerMarkDisplayName(mark),
                      swatch: layerMarkColor(mark),
                      onRemove: () =>
                          onSetRowFilter(rowFilter.toggledMark(mark)),
                    ),
                if (rowFilter.onTimesheetOnly)
                  chip(
                    keyValue: 'row-filter-chip-sheet',
                    label: 'sheet',
                    onRemove: () => onSetRowFilter(
                      rowFilter.copyWith(onTimesheetOnly: false),
                    ),
                  ),
                if (rowFilter.fxOnly)
                  chip(
                    keyValue: 'row-filter-chip-fx',
                    label: 'fx',
                    onRemove: () =>
                        onSetRowFilter(rowFilter.copyWith(fxOnly: false)),
                  ),
                if (rowFilter.fillReferenceOnly)
                  chip(
                    keyValue: 'row-filter-chip-fill-ref',
                    label: 'fill ref',
                    onRemove: () => onSetRowFilter(
                      rowFilter.copyWith(fillReferenceOnly: false),
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            key: const ValueKey<String>('row-filter-clear-all'),
            onTap: () => onSetRowFilter(TimelineRowFilter.none),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Clear',
                style: TextStyle(fontSize: 10, color: AppColors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
