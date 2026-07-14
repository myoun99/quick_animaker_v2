import '../models/bitmap_surface.dart';
import '../models/brush_frame_display_cache.dart';
import '../models/brush_frame_key.dart';
import '../models/canvas_size.dart';
import 'brush_frame_store.dart';

/// Coordinates explicit, non-pointer-move preview cache rebuilds.
///
/// R19 P3b: with the baked raster as the sole truth (no command replay),
/// a "rebuild" is a reference reseed — the valid cache, else the baked
/// surface, else a blank surface for an empty cel.
class BrushFrameDisplayCacheService {
  const BrushFrameDisplayCacheService({
    required this.frameStore,
    required this.canvasSize,
    this.tileSize = 256,
  });

  final BrushFrameStore frameStore;
  final CanvasSize canvasSize;
  final int tileSize;

  BrushFrameDisplayCache prepareFramePreview(BrushFrameKey key) {
    frameStore.getOrCreateFrame(key);
    final existing = frameStore.displayCacheOrNull(key);
    if (existing != null &&
        existing.isValid &&
        existing.previewSurface.canvasSize == canvasSize) {
      return existing;
    }

    final surface =
        frameStore.currentSurfaceWithoutReplay(key, canvasSize: canvasSize) ??
        BitmapSurface(canvasSize: canvasSize, tileSize: tileSize);
    return frameStore.storeRebuiltDisplayCache(
      key: key,
      previewSurface: surface,
    );
  }
}
