import 'package:flutter/material.dart';

import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';
import 'timeline_section_runs.dart';
import 'upright_vertical_text.dart';

/// The section-bracket gutter beside the timeline rail: one enclosing
/// bracket cell per section run — the paper timesheet's ACTION/SE/CAMERA
/// group heading wrapping its columns, laid along the layer axis. Labels
/// are written the paper way: upright glyphs stacked top-to-bottom (never
/// rotated). Display-only — section visibility lives on the toolbar
/// toggles.
class TimelineSectionBracketRail extends StatelessWidget {
  const TimelineSectionBracketRail({
    super.key,
    required this.rows,
    required this.metrics,
  });

  final List<TimelineDisplayRow> rows;
  final TimelineGridMetrics metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.sectionLabelGutterWidth <= 0) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final runs = timelineSectionRuns(rows);
    return SizedBox(
      width: metrics.sectionLabelGutterWidth,
      child: Column(
        children: [
          for (final run in runs)
            Container(
              width: metrics.sectionLabelGutterWidth,
              height: timelineSectionRunExtent(run, rows, metrics),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                border: Border.all(color: colorScheme.outline, width: 1),
              ),
              child: Center(
                child: ClipRect(
                  child: UprightVerticalText(
                    text: timelineSectionLabel(run.section),
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
