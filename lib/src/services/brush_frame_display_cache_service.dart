import '../models/brush_frame_display_cache.dart';
import '../models/brush_frame_key.dart';
import 'brush_frame_display_cache_renderer.dart';
import 'brush_frame_store.dart';

/// Coordinates explicit, non-pointer-move preview cache rebuilds.
class BrushFrameDisplayCacheService {
  const BrushFrameDisplayCacheService({
    required this.frameStore,
    required this.renderer,
  });

  final BrushFrameStore frameStore;
  final BrushFrameDisplayCacheRenderer renderer;

  BrushFrameDisplayCache prepareFramePreview(BrushFrameKey key) {
    final drawing = frameStore.getOrCreateFrame(key);
    final existing = frameStore.displayCacheOrNull(key);
    if (existing != null &&
        existing.isValid &&
        existing.previewSurface.canvasSize == renderer.canvasSize) {
      return existing;
    }

    // R19 bake-only: the baked raster serves directly when no commands
    // could have diverged from it — an OPENED cel has no commands at all,
    // and the command replay below would wrongly rebuild it BLANK.
    final baked = frameStore.currentSurfaceWithoutReplay(
      key,
      canvasSize: renderer.canvasSize,
    );
    if (baked != null) {
      return frameStore.storeRebuiltDisplayCache(
        key: key,
        previewSurface: baked,
      );
    }

    final preview = renderer.rebuildPreview(drawing);
    return frameStore.storeRebuiltDisplayCache(
      key: key,
      previewSurface: preview,
    );
  }
}
