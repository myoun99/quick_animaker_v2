import '../models/bitmap_surface.dart';
import '../models/brush_command_raster_cache.dart';
import '../models/brush_frame_drawing_state.dart';
import '../models/brush_frame_edit_composite.dart';
import '../models/brush_frame_key.dart';
import '../models/brush_paint_command.dart';
import '../models/canvas_size.dart';
import '../models/dirty_tile_set.dart';
import 'brush_frame_store.dart';
import 'brush_pixel_grid_rasterizer.dart';

/// Builds and updates the active frame edit composite from source commands plus
/// command raster cache entries. Inactive preview caches are deliberately not
/// read here.
class BrushFrameEditCompositeService {
  const BrushFrameEditCompositeService({
    required this.frameStore,
    required this.canvasSize,
    this.tileSize = 256,
    this.rasterizer = const BrushPixelGridRasterizer(),
  });

  final BrushFrameStore frameStore;
  final CanvasSize canvasSize;
  final int tileSize;
  final BrushPixelGridRasterizer rasterizer;

  BrushFrameEditComposite ensureComposite(BrushFrameKey key) {
    final drawing = frameStore.getOrCreateFrame(key);
    final existing = frameStore.editCompositeOrNull(key);
    if (existing != null && existing.isValidForRevision(drawing.sourceRevision)) {
      return existing;
    }
    return rebuildComposite(key, drawing: drawing);
  }

  BrushFrameEditComposite rebuildComposite(
    BrushFrameKey key, {
    BrushFrameDrawingState? drawing,
  }) {
    final source = drawing ?? frameStore.getOrCreateFrame(key);
    var surface = BitmapSurface(canvasSize: canvasSize, tileSize: tileSize);
    var dirtyTiles = DirtyTileSet.empty();
    var cache = frameStore.commandRasterCacheOrNull(key) ?? const BrushCommandRasterCache();

    for (final command in source.allPaintCommandsInDisplayOrder) {
      final entry = _entryFor(command, source.sourceRevision, cache);
      cache = cache.put(entry);
      final materialized = rasterizer.rasterizeCommand(
        baseSurface: surface,
        command: command,
      );
      surface = materialized.surface;
      dirtyTiles = dirtyTiles.union(materialized.dirtyTiles);
    }

    frameStore.storeCommandRasterCache(key: key, cache: cache);
    final composite = BrushFrameEditComposite(
      frameKey: key,
      compositeSurface: surface,
      dirtyTiles: dirtyTiles,
      sourceRevision: source.sourceRevision,
    );
    return frameStore.storeEditComposite(composite);
  }

  BrushFrameEditComposite updateAfterCommandCommit({
    required BrushFrameKey key,
    required BrushPaintCommand command,
  }) {
    final drawing = frameStore.getOrCreateFrame(key);
    final existingComposite = frameStore.editCompositeOrNull(key);
    if (existingComposite == null) {
      return rebuildComposite(key, drawing: drawing);
    }
    final materialized = rasterizer.rasterizeCommand(
      baseSurface: existingComposite.compositeSurface,
      command: command,
    );
    final commandEntry = rasterizer.rasterizeCommand(
      baseSurface: BitmapSurface(canvasSize: canvasSize, tileSize: tileSize),
      command: command,
    );
    final cache = (frameStore.commandRasterCacheOrNull(key) ?? const BrushCommandRasterCache()).put(
      BrushCommandRasterEntry(
        commandId: command.id,
        surface: commandEntry.surface,
        dirtyTiles: commandEntry.dirtyTiles,
        sourceRevision: drawing.sourceRevision,
      ),
    );
    frameStore.storeCommandRasterCache(key: key, cache: cache);
    final composite = BrushFrameEditComposite(
      frameKey: key,
      compositeSurface: materialized.surface,
      dirtyTiles: materialized.dirtyTiles,
      sourceRevision: drawing.sourceRevision,
    );
    return frameStore.storeEditComposite(composite);
  }

  BrushCommandRasterEntry _entryFor(
    BrushPaintCommand command,
    int sourceRevision,
    BrushCommandRasterCache cache,
  ) {
    final existing = cache.entryFor(command.id);
    if (existing != null) return existing;
    final raster = rasterizer.rasterizeCommand(
      baseSurface: BitmapSurface(canvasSize: canvasSize, tileSize: tileSize),
      command: command,
    );
    return BrushCommandRasterEntry(
      commandId: command.id,
      surface: raster.surface,
      dirtyTiles: raster.dirtyTiles,
      sourceRevision: sourceRevision,
    );
  }
}
