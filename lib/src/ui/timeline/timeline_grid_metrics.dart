/// Shared dimensions for the layer timeline grid.
///
/// These values mirror the current [LayerTimelineGrid] layout so calculation-
/// only virtualization helpers can use the same geometry as the rendered UI.
class TimelineGridMetrics {
  static const int defaultMinimumVisibleFrameCells = 24;

  const TimelineGridMetrics({
    this.minimumVisibleFrameCells = defaultMinimumVisibleFrameCells,
    this.layerControlsWidth = 288,
    this.frameCellWidth = 48,
    this.layerRowHeight = 52,
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
  /// are wide, every Nth (nice animation steps) when they are narrow, so
  /// labels never crowd or overflow.
  int get frameLabelEveryFrames {
    if (frameCellWidth >= 28) {
      return 1;
    }
    const niceSteps = [2, 3, 4, 6, 12, 24, 48, 96];
    for (final step in niceSteps) {
      if (frameCellWidth * step >= 40) {
        return step;
      }
    }
    return niceSteps.last;
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

  /// The section-label gutter leading the layer rail (the timesheet's
  /// ACTION/SE/CAMERA group headings laid on their side); included in
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
