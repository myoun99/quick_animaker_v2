import 'bitmap_surface.dart';
import 'brush_frame_key.dart';
import 'dirty_tile_set.dart';

/// Derived active-edit composite used by the active canvas display.
class BrushFrameEditComposite {
  const BrushFrameEditComposite({
    required this.frameKey,
    required this.compositeSurface,
    required this.dirtyTiles,
    required this.sourceRevision,
  });

  final BrushFrameKey frameKey;
  final BitmapSurface compositeSurface;
  final DirtyTileSet dirtyTiles;
  final int sourceRevision;

  bool isValidForRevision(int revision) => sourceRevision == revision;
}
