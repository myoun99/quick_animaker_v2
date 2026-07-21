import '../core/floor_math.dart';
import 'canvas_size.dart';

/// The pasteboard: the finite drawable rectangle AROUND the canvas
/// (Flash's gray stage surround). It extends exactly one canvas size
/// beyond every canvas edge — a 3×3 canvas footprint — so strokes,
/// fills and selection drops are bounded, storage worst cases stay
/// finite, and the "fill outside the canvas" option has a hard wall.
///
/// The canvas keeps its [0, width) × [0, height) pixel space; the
/// pasteboard adds negative space to the left/top and overflow to the
/// right/bottom. Composite/export raster at canvas size, which crops
/// pasteboard content for free.
extension PasteboardBounds on CanvasSize {
  int get pasteboardLeft => -width;

  int get pasteboardTop => -height;

  int get pasteboardRightExclusive => 2 * width;

  int get pasteboardBottomExclusive => 2 * height;

  bool containsPasteboardPixel({required int x, required int y}) {
    return x >= pasteboardLeft &&
        x < pasteboardRightExclusive &&
        y >= pasteboardTop &&
        y < pasteboardBottomExclusive;
  }

  /// First tile column that intersects the pasteboard.
  int pasteboardTileXMin(int tileSize) => floorDiv(pasteboardLeft, tileSize);

  /// First tile row that intersects the pasteboard.
  int pasteboardTileYMin(int tileSize) => floorDiv(pasteboardTop, tileSize);

  /// One past the last tile column that intersects the pasteboard.
  int pasteboardTileXEndExclusive(int tileSize) =>
      ceilDiv(pasteboardRightExclusive, tileSize);

  /// One past the last tile row that intersects the pasteboard.
  int pasteboardTileYEndExclusive(int tileSize) =>
      ceilDiv(pasteboardBottomExclusive, tileSize);
}
