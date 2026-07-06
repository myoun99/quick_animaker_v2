import '../../models/brush_frame_cache_invalidation.dart';
import '../../models/frame_composite_cache_key.dart';
import '../../models/layer_tile_cache_key.dart';
import '../../models/playback_preview_cache_key.dart';
import '../cache_invalidation_executor.dart';

/// The production [CacheInvalidationSink]: fans invalidation events out to
/// registered listeners (playback caches, prerender scheduler).
///
/// This is the first real consumer of the events the brush editing
/// coordinator has been emitting on commit/undo/redo. Listeners use them for
/// early eviction and prerender re-queuing; cache CORRECTNESS never depends
/// on them (composites self-validate via [CutFrameCompositeSignature]).
class EditorCacheInvalidationHub implements CacheInvalidationSink {
  final List<void Function(BrushFrameCacheInvalidation)> _brushFrameListeners =
      [];

  void addBrushFrameListener(
    void Function(BrushFrameCacheInvalidation) listener,
  ) {
    _brushFrameListeners.add(listener);
  }

  void removeBrushFrameListener(
    void Function(BrushFrameCacheInvalidation) listener,
  ) {
    _brushFrameListeners.remove(listener);
  }

  @override
  void invalidateBrushFrame(BrushFrameCacheInvalidation invalidation) {
    for (final listener in List.of(_brushFrameListeners)) {
      listener(invalidation);
    }
  }

  // The remaining event kinds have no emitters yet; they stay no-ops until a
  // producer exists.
  @override
  void invalidateLayerTile(LayerTileCacheKey key) {}

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) {}

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) {}
}
