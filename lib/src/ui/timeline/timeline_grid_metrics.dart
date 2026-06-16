/// Shared dimensions for the layer timeline grid.
///
/// These values mirror the current [LayerTimelineGrid] layout so calculation-
/// only virtualization helpers can use the same geometry as the rendered UI.
class TimelineGridMetrics {
  static const int defaultMinimumVisibleFrameCells = 24;

  const TimelineGridMetrics({
    this.minimumVisibleFrameCells = defaultMinimumVisibleFrameCells,
    this.layerControlsWidth = 220,
    this.frameCellWidth = 48,
    this.layerRowHeight = 52,
    this.verticalScrollbarWidth = 14,
  }) : assert(minimumVisibleFrameCells >= 0),
       assert(layerControlsWidth >= 0),
       assert(frameCellWidth > 0),
       assert(layerRowHeight > 0),
       assert(verticalScrollbarWidth >= 0);

  /// Default metrics matching the current [LayerTimelineGrid] behavior.
  static const TimelineGridMetrics defaults = TimelineGridMetrics();

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

  @override
  bool operator ==(Object other) {
    return other is TimelineGridMetrics &&
        other.minimumVisibleFrameCells == minimumVisibleFrameCells &&
        other.layerControlsWidth == layerControlsWidth &&
        other.frameCellWidth == frameCellWidth &&
        other.layerRowHeight == layerRowHeight &&
        other.verticalScrollbarWidth == verticalScrollbarWidth;
  }

  @override
  int get hashCode => Object.hash(
    minimumVisibleFrameCells,
    layerControlsWidth,
    frameCellWidth,
    layerRowHeight,
    verticalScrollbarWidth,
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
