import 'bitmap_surface.dart';
import 'dirty_tile_set.dart';

/// Temporary pixel-grid bitmap overlay for the in-progress stroke.
class ActiveStrokeRasterOverlay {
  const ActiveStrokeRasterOverlay({
    required this.tempSurface,
    required this.dirtyTiles,
  });

  final BitmapSurface tempSurface;
  final DirtyTileSet dirtyTiles;
}
