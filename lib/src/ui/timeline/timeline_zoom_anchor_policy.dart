import 'dart:math' as math;

/// Where the frame axis should sit after a zoom step (Premiere-style
/// zoom-around-playhead), shared by every frame-axis surface — the
/// horizontal timeline, the X-sheet (transposed) and the storyboard.
///
/// The playhead frame anchors when it is inside the viewport: its on-screen
/// position stays put while the cells stretch around it. When the playhead
/// is off screen (or the surface has none) the viewport's leading-edge
/// content anchors instead — the previous behavior — so zooming far away
/// from the playhead never yanks the view across the track.
double zoomAnchoredScrollOffset({
  required double oldOffset,
  required double oldPixelsPerFrame,
  required double newPixelsPerFrame,
  required double viewportExtent,
  int? anchorFrame,
}) {
  if (anchorFrame != null && viewportExtent > 0) {
    // Anchor on the frame CELL's center, matching the playhead tint.
    final anchorOnScreen = (anchorFrame + 0.5) * oldPixelsPerFrame - oldOffset;
    if (anchorOnScreen >= 0 && anchorOnScreen <= viewportExtent) {
      return math.max(
        0,
        (anchorFrame + 0.5) * newPixelsPerFrame - anchorOnScreen,
      );
    }
  }
  return math.max(0, oldOffset * (newPixelsPerFrame / oldPixelsPerFrame));
}
