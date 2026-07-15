/// Shared dimensions for the layer timeline grid.
///
/// These values mirror the current [LayerTimelineGrid] layout so calculation-
/// only virtualization helpers can use the same geometry as the rendered UI.
class TimelineGridMetrics {
  static const int defaultMinimumVisibleFrameCells = 24;

  const TimelineGridMetrics({
    this.minimumVisibleFrameCells = defaultMinimumVisibleFrameCells,
    // 288 → 312 when the layer rows gained the fx switch (R3 ⑪); the row
    // controls need the width, cramming them under 288 overflowed.
    this.layerControlsWidth = 312,
    // 48×52 → 24×28 (R-toolbar slim round, CSP/TVPaint density): the frame
    // shell reads twice as many cells and rows in the same viewport.
    this.frameCellWidth = 24,
    this.layerRowHeight = 28,
    this.verticalScrollbarWidth = 14,
    this.sectionLabelGutterWidth = 24,
  }) : assert(minimumVisibleFrameCells >= 0),
       assert(layerControlsWidth >= 0),
       assert(frameCellWidth > 0),
       assert(layerRowHeight > 0),
       assert(verticalScrollbarWidth >= 0),
       assert(sectionLabelGutterWidth >= 0);

  /// Default metrics matching the current [LayerTimelineGrid] behavior.
  static const TimelineGridMetrics defaults = TimelineGridMetrics();

  /// Same geometry with a different frame-axis cell extent (zoom).
  TimelineGridMetrics copyWith({double? frameCellWidth}) {
    return TimelineGridMetrics(
      minimumVisibleFrameCells: minimumVisibleFrameCells,
      layerControlsWidth: layerControlsWidth,
      frameCellWidth: frameCellWidth ?? this.frameCellWidth,
      layerRowHeight: layerRowHeight,
      verticalScrollbarWidth: verticalScrollbarWidth,
      sectionLabelGutterWidth: sectionLabelGutterWidth,
    );
  }

  /// Frame-number label cadence for the header/rail: every frame when cells
  /// are wide enough, then the paper-timesheet ladder anchored at frame 1
  /// (user rule): 3f (1,4,7,…) → 6f (1,7,13,…) → 12f (1,13,25) → 24f
  /// (1,25) → doubling on. Labels never crowd or overflow.
  int get frameLabelEveryFrames {
    if (frameCellWidth >= 20) {
      return 1;
    }
    const strideLadder = [3, 6, 12, 24, 48, 96];
    for (final stride in strideLadder) {
      if (frameCellWidth * stride >= 40) {
        return stride;
      }
    }
    return strideLadder.last;
  }

  /// Minimum frame cells kept visible even when the cut has fewer frames.
  final int minimumVisibleFrameCells;

  /// Width of the fixed layer controls column.
  final double layerControlsWidth;

  /// Width of each frame cell and frame header.
  final double frameCellWidth;

  /// Height of each layer row and the frame header row.
  final double layerRowHeight;

  /// Width reserved for the visible vertical scrollbar between the layer rail
  /// and frame grid area.
  final double verticalScrollbarWidth;

  /// The section-bracket gutter leading the layer rail (the timesheet's
  /// ACTION/SE/CAMERA group headings wrapping their rows); included in
  /// [layerControlsWidth].
  final double sectionLabelGutterWidth;

  @override
  bool operator ==(Object other) {
    return other is TimelineGridMetrics &&
        other.minimumVisibleFrameCells == minimumVisibleFrameCells &&
        other.layerControlsWidth == layerControlsWidth &&
        other.frameCellWidth == frameCellWidth &&
        other.layerRowHeight == layerRowHeight &&
        other.verticalScrollbarWidth == verticalScrollbarWidth &&
        other.sectionLabelGutterWidth == sectionLabelGutterWidth;
  }

  @override
  int get hashCode => Object.hash(
    minimumVisibleFrameCells,
    layerControlsWidth,
    frameCellWidth,
    layerRowHeight,
    verticalScrollbarWidth,
    sectionLabelGutterWidth,
  );

  @override
  String toString() {
    return 'TimelineGridMetrics('
        'minimumVisibleFrameCells: $minimumVisibleFrameCells, '
        'layerControlsWidth: $layerControlsWidth, '
        'frameCellWidth: $frameCellWidth, '
        'layerRowHeight: $layerRowHeight, '
        'verticalScrollbarWidth: $verticalScrollbarWidth)';
  }
}
