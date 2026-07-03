import 'bitmap_surface.dart';
import 'brush_frame_key.dart';
import 'dirty_tile_set.dart';

/// Derived bitmap preview for displaying a brush frame without replaying all
/// source paint commands in scrub/inactive display paths.
///
/// This cache is rebuildable from BrushFrameDrawingState source commands and is
/// never the source of truth for artwork.
class BrushFrameDisplayCache {
  BrushFrameDisplayCache({
    required this.frameKey,
    required this.previewSurface,
    required this.sourceRevision,
    this.dirty = false,
    DirtyTileSet? dirtyTiles,
  }) : dirtyTiles = dirtyTiles ?? DirtyTileSet.empty();

  final BrushFrameKey frameKey;
  final BitmapSurface previewSurface;
  final int sourceRevision;
  final bool dirty;
  final DirtyTileSet dirtyTiles;

  bool get isValid => !dirty;

  BrushFrameDisplayCache copyWith({
    BitmapSurface? previewSurface,
    int? sourceRevision,
    bool? dirty,
    DirtyTileSet? dirtyTiles,
  }) {
    return BrushFrameDisplayCache(
      frameKey: frameKey,
      previewSurface: previewSurface ?? this.previewSurface,
      sourceRevision: sourceRevision ?? this.sourceRevision,
      dirty: dirty ?? this.dirty,
      dirtyTiles: dirtyTiles ?? this.dirtyTiles,
    );
  }
}
