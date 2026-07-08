import 'package:flutter/material.dart';

import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';

/// The section-bracket gutter beside the timeline rail: one enclosing
/// bracket cell per section run — the paper timesheet's ACTION/SE/CAMERA
/// group heading wrapping its columns, laid along the layer axis. Labels
/// read bottom-to-top (tilt your head to the RIGHT, like the sheet turned
/// on its side); collapsible sections carry the fold chevron, and a
/// collapsed section's segment shrinks to the slim reopen strip.
class TimelineSectionBracketRail extends StatelessWidget {
  const TimelineSectionBracketRail({
    super.key,
    required this.rows,
    required this.metrics,
    this.onToggleSection,
  });

  final List<TimelineDisplayRow> rows;
  final TimelineGridMetrics metrics;
  final ValueChanged<TimelineSection>? onToggleSection;

  @override
  Widget build(BuildContext context) {
    if (metrics.sectionLabelGutterWidth <= 0) {
      return const SizedBox.shrink();
    }
    final runs = timelineSectionRuns(rows);
    return SizedBox(
      width: metrics.sectionLabelGutterWidth,
      child: Column(
        children: [
          for (final run in runs)
            _BracketSegment(
              run: run,
              extent: timelineSectionRunExtent(run, rows, metrics),
              metrics: metrics,
              onToggleSection:
                  onToggleSection == null ||
                      !timelineSectionCollapsible(run.section)
                  ? null
                  : () => onToggleSection!(run.section),
            ),
        ],
      ),
    );
  }
}

class _BracketSegment extends StatelessWidget {
  const _BracketSegment({
    required this.run,
    required this.extent,
    required this.metrics,
    required this.onToggleSection,
  });

  final TimelineSectionRun run;
  final double extent;
  final TimelineGridMetrics metrics;
  final VoidCallback? onToggleSection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final collapsible = onToggleSection != null;

    final content = run.collapsed
        ? Center(
            child: Icon(
              Icons.chevron_right,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          )
        : Column(
            children: [
              if (collapsible)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.expand_more,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              Expanded(
                child: Center(
                  // quarterTurns 3: the label runs bottom-to-top so it reads
                  // from the RIGHT side of the strip — the sheet's heading
                  // once the paper is laid time-axis-horizontal.
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      timelineSectionLabel(run.section),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );

    final box = Container(
      width: metrics.sectionLabelGutterWidth,
      height: extent,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outline, width: 1),
      ),
      child: content,
    );

    if (!collapsible) {
      return ExcludeSemantics(child: box);
    }
    return InkWell(
      key: ValueKey<String>('timeline-section-collapse-${run.section.name}'),
      onTap: onToggleSection,
      child: Semantics(
        label:
            '${run.collapsed ? 'Expand' : 'Collapse'} '
            '${timelineSectionLabel(run.section)} section',
        button: true,
        child: box,
      ),
    );
  }
}

/// A collapsed section on the rail: a slim reopen strip (no layer rows, no
/// frame cells — the section is folded flat).
class TimelineSectionStubRailRow extends StatelessWidget {
  const TimelineSectionStubRailRow({
    super.key,
    required this.section,
    required this.layerCount,
    required this.metrics,
    required this.onToggleSection,
  });

  final TimelineSection section;
  final int layerCount;
  final TimelineGridMetrics metrics;
  final VoidCallback? onToggleSection;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey<String>('timeline-section-stub-rail-${section.name}'),
      onTap: onToggleSection,
      child: Container(
        width: metrics.layerControlsWidth - metrics.sectionLabelGutterWidth,
        height: metrics.collapsedSectionExtent,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              Icons.chevron_right,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${timelineSectionLabel(section)} · $layerCount',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A collapsed section's slot in the frame-cells area: a slim empty band —
/// no cells, no fill (expanding happens on the rail strip or the bracket).
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
    return SizedBox(
      key: ValueKey<String>('$keyPrefix-section-stub-row-${section.name}'),
      width: axis == Axis.horizontal
          ? mainAxisExtent
          : metrics.collapsedSectionExtent,
      height: axis == Axis.horizontal
          ? metrics.collapsedSectionExtent
          : mainAxisExtent,
    );
  }
}
