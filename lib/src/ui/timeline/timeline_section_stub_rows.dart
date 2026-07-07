import 'package:flutter/material.dart';

import 'timeline_grid_metrics.dart';
import 'timeline_layer_controls_row.dart';
import 'timeline_section_policy.dart';

/// A collapsed section folded to one row: the rail shows the gutter label
/// with the fold chevron plus a quiet summary, the frame area an empty
/// muted strip. Uniform [TimelineGridMetrics.layerRowHeight] keeps every
/// virtualization/playhead calculation untouched.
class TimelineSectionStubRailRow extends StatelessWidget {
  const TimelineSectionStubRailRow({
    super.key,
    required this.section,
    required this.layerCount,
    required this.metrics,
    required this.onToggleSection,
    this.sectionStart = false,
  });

  final TimelineSection section;
  final int layerCount;
  final TimelineGridMetrics metrics;
  final VoidCallback? onToggleSection;

  /// Mirrors the layer rows' heavier top divider on section boundaries.
  final bool sectionStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final row = InkWell(
      key: ValueKey<String>('timeline-section-stub-rail-${section.name}'),
      onTap: onToggleSection,
      child: Container(
        width: metrics.layerControlsWidth,
        height: metrics.layerRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            TimelineSectionGutterSlot(
              metrics: metrics,
              section: section,
              onToggleSection: onToggleSection,
              collapsed: true,
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.unfold_more,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${timelineSectionLabel(section)} · $layerCount',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!sectionStart) {
      return row;
    }
    return Stack(
      children: [
        row,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 2,
          child: IgnorePointer(child: Container(color: colorScheme.outline)),
        ),
      ],
    );
  }
}

/// The collapsed section's strip in the frame-cells area (display only —
/// expanding happens on the rail).
class TimelineSectionStubCellsRow extends StatelessWidget {
  const TimelineSectionStubCellsRow({
    super.key,
    required this.section,
    required this.mainAxisExtent,
    required this.metrics,
    this.axis = Axis.horizontal,
    this.keyPrefix = 'timeline',
  });

  final TimelineSection section;

  /// The frame-axis content extent (row width horizontally, column height
  /// in the X-sheet).
  final double mainAxisExtent;
  final TimelineGridMetrics metrics;
  final Axis axis;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey<String>('$keyPrefix-section-stub-row-${section.name}'),
      width: axis == Axis.horizontal ? mainAxisExtent : metrics.layerRowHeight,
      height: axis == Axis.horizontal ? metrics.layerRowHeight : mainAxisExtent,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
    );
  }
}
