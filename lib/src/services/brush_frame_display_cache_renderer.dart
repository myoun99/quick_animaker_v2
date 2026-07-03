import '../models/bitmap_surface.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_frame_drawing_state.dart';
import '../models/canvas_size.dart';
import 'bitmap_surface_brush_commit.dart';

/// Rebuilds a derived brush-frame preview from source commands.
///
/// This renderer is intentionally small and explicit so later phases can swap
/// the full-frame rebuild for dirty-region or dirty-tile rebuilds without
/// moving source data or cache payloads into Frame.
class BrushFrameDisplayCacheRenderer {
  const BrushFrameDisplayCacheRenderer({
    required this.canvasSize,
    this.tileSize = 256,
  });

  final CanvasSize canvasSize;
  final int tileSize;

  BitmapSurface rebuildPreview(BrushFrameDrawingState drawing) {
    var surface = BitmapSurface(canvasSize: canvasSize, tileSize: tileSize);
    for (final command in drawing.allPaintCommandsInDisplayOrder) {
      if (command.sourceDabs.isEmpty) {
        continue;
      }
      surface = materializeBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: BrushDabSequence(command.sourceDabs),
      ).surface;
    }
    return surface;
  }
}
