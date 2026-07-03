import 'bitmap_surface.dart';
import 'brush_paint_command_id.dart';
import 'dirty_tile_set.dart';

class BrushCommandRasterEntry {
  const BrushCommandRasterEntry({
    required this.commandId,
    required this.surface,
    required this.dirtyTiles,
    required this.sourceRevision,
  });

  final BrushPaintCommandId commandId;
  final BitmapSurface surface;
  final DirtyTileSet dirtyTiles;
  final int sourceRevision;
}

/// Derived command-id keyed raster cache. It is never source of truth.
class BrushCommandRasterCache {
  const BrushCommandRasterCache({
    Map<BrushPaintCommandId, BrushCommandRasterEntry> entries = const {},
  }) : _entries = entries;

  final Map<BrushPaintCommandId, BrushCommandRasterEntry> _entries;

  BrushCommandRasterEntry? entryFor(BrushPaintCommandId id) => _entries[id];

  BrushCommandRasterCache put(BrushCommandRasterEntry entry) {
    return BrushCommandRasterCache(
      entries: {..._entries, entry.commandId: entry},
    );
  }

  BrushCommandRasterCache remove(BrushPaintCommandId id) {
    final next = Map<BrushPaintCommandId, BrushCommandRasterEntry>.of(_entries)
      ..remove(id);
    return BrushCommandRasterCache(entries: next);
  }
}
