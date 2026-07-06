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
