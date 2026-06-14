/// Converts timeline frame positions and durations into visual pixel sizes.
///
/// This is a UI helper only. It does not know about or mutate project models.
class TimelineScale {
  const TimelineScale({
    this.pixelsPerFrame = 8.0,
    this.minBlockWidth = 96.0,
  });

  final double pixelsPerFrame;
  final double minBlockWidth;

  double leftForFrame(int frame) => frame * pixelsPerFrame;

  double widthForDuration(int duration) {
    final width = duration * pixelsPerFrame;
    return width < minBlockWidth ? minBlockWidth : width;
  }
}
