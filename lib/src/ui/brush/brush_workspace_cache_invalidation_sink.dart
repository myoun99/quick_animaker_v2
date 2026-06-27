import '../../models/cache_invalidation_execution_result.dart';
import '../../models/frame_composite_cache_key.dart';
import '../../models/layer_tile_cache_key.dart';
import '../../models/playback_preview_cache_key.dart';
import '../../services/cache_invalidation_executor.dart';

/// Debug/manual cache invalidation recorder for temporary Brush hosts.
class BrushWorkspaceCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  CacheInvalidationExecutionResult get latestResult =>
      CacheInvalidationExecutionResult(
        layerTileCount: layerTiles.length,
        frameCompositeCount: frameComposites.length,
        playbackPreviewCount: playbackPreviews.length,
      );

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) =>
      frameComposites.add(key);

  @override
  void invalidateLayerTile(LayerTileCacheKey key) => layerTiles.add(key);

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) =>
      playbackPreviews.add(key);
}
