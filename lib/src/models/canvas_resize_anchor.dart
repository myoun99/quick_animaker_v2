import 'canvas_size.dart';

/// Where existing artwork stays pinned when the canvas is resized, matching
/// the 9-way anchor grid of Photoshop/Clip Studio canvas-size dialogs.
///
/// [horizontalFactor]/[verticalFactor] are 0 at the left/top edge, 0.5 at the
/// center and 1 at the right/bottom edge.
enum CanvasResizeAnchor {
  topLeft(0, 0),
  topCenter(0.5, 0),
  topRight(1, 0),
  centerLeft(0, 0.5),
  center(0.5, 0.5),
  centerRight(1, 0.5),
  bottomLeft(0, 1),
  bottomCenter(0.5, 1),
  bottomRight(1, 1);

  const CanvasResizeAnchor(this.horizontalFactor, this.verticalFactor);

  final double horizontalFactor;
  final double verticalFactor;

  /// The canvas-space translation applied to artwork when the canvas resizes
  /// [from] → [to] with this anchor. Top-left is always (0, 0); the inverse
  /// resize produces the exact inverse offset, so a resize round-trips.
  ({double dx, double dy}) contentOffset({
    required CanvasSize from,
    required CanvasSize to,
  }) {
    return (
      dx: horizontalFactor * (to.width - from.width),
      dy: verticalFactor * (to.height - from.height),
    );
  }
}
