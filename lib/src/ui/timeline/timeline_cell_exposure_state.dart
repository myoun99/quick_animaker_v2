/// What one timeline cell shows under the unified timeline model.
///
/// `uncovered` cells are empty timesheet cells (rendered with the "X"
/// glyph on cel layers); marks keep the visual of the space they sit in
/// (block body or empty cell) plus the ● glyph, and never form blocks.
enum TimelineCellExposureState {
  uncovered,
  drawingStart,
  held,
  markHeld,
  markUncovered;

  /// Part of a drawing block's covered run (start, hold, or a mark inside
  /// the hold).
  bool get isCovered =>
      this == TimelineCellExposureState.drawingStart ||
      this == TimelineCellExposureState.held ||
      this == TimelineCellExposureState.markHeld;

  bool get isMark =>
      this == TimelineCellExposureState.markHeld ||
      this == TimelineCellExposureState.markUncovered;
}

/// Whether an empty run STARTS at a cell in [current] state, given the
/// [previous] cell's state (null at frame 0). Japanese timesheets mark only
/// the first cell of each empty run with the X glyph; a mark inside the run
/// continues it rather than starting a new one.
bool timelineEmptyRunStartsAt({
  required TimelineCellExposureState current,
  TimelineCellExposureState? previous,
}) {
  if (current != TimelineCellExposureState.uncovered) {
    return false;
  }
  return previous == null || previous.isCovered;
}
