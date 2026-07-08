import 'property_lane_model.dart';
import 'timeline_grid_metrics.dart';
import 'timeline_section_policy.dart';

/// A consecutive run of display rows belonging to one timesheet section —
/// the geometry the section BRACKET wraps (the paper sheet's ACTION heading
/// enclosing its cel columns, laid along the layer axis).
///
/// Shared by both orientations (Axis rule): the horizontal timeline draws
/// runs as gutter segments beside the rail rows, the X-sheet as header
/// bands above the column headers.
class TimelineSectionRun {
  const TimelineSectionRun({
    required this.section,
    required this.startRowIndex,
    required this.rowCount,
  });

  final TimelineSection section;

  /// First display-row index of the run.
  final int startRowIndex;

  /// Number of consecutive display rows (layer + lane rows).
  final int rowCount;

  @override
  bool operator ==(Object other) =>
      other is TimelineSectionRun &&
      other.section == section &&
      other.startRowIndex == startRowIndex &&
      other.rowCount == rowCount;

  @override
  int get hashCode => Object.hash(section, startRowIndex, rowCount);

  @override
  String toString() =>
      'TimelineSectionRun(section: $section, startRowIndex: $startRowIndex, '
      'rowCount: $rowCount)';
}

/// Groups [rows] into consecutive section runs (lane rows belong to their
/// layer's section).
List<TimelineSectionRun> timelineSectionRuns(List<TimelineDisplayRow> rows) {
  final runs = <TimelineSectionRun>[];
  for (var index = 0; index < rows.length; index += 1) {
    final section = timelineSectionForLayerKind(rows[index].layer.kind);
    if (runs.isNotEmpty &&
        runs.last.section == section &&
        runs.last.startRowIndex + runs.last.rowCount == index) {
      final last = runs.removeLast();
      runs.add(
        TimelineSectionRun(
          section: last.section,
          startRowIndex: last.startRowIndex,
          rowCount: last.rowCount + 1,
        ),
      );
    } else {
      runs.add(
        TimelineSectionRun(section: section, startRowIndex: index, rowCount: 1),
      );
    }
  }
  return List.unmodifiable(runs);
}

/// Layer-axis extent of one display row.
double timelineDisplayRowExtent(
  TimelineDisplayRow row,
  TimelineGridMetrics metrics,
) {
  return metrics.layerRowHeight;
}

/// Total layer-axis extent of [rows].
double timelineDisplayRowsExtent(
  List<TimelineDisplayRow> rows,
  TimelineGridMetrics metrics,
) {
  var extent = 0.0;
  for (final row in rows) {
    extent += timelineDisplayRowExtent(row, metrics);
  }
  return extent;
}

/// Layer-axis extent of one section run.
double timelineSectionRunExtent(
  TimelineSectionRun run,
  List<TimelineDisplayRow> rows,
  TimelineGridMetrics metrics,
) {
  var extent = 0.0;
  for (
    var index = run.startRowIndex;
    index < run.startRowIndex + run.rowCount;
    index += 1
  ) {
    extent += timelineDisplayRowExtent(rows[index], metrics);
  }
  return extent;
}
