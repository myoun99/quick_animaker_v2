import '../models/cache_invalidation_execution_result.dart';
import '../models/cache_invalidation_plan.dart';
import '../models/frame_composite_cache_key.dart';
import '../models/layer_tile_cache_key.dart';
import '../models/playback_preview_cache_key.dart';

abstract class CacheInvalidationSink {
  void invalidateLayerTile(LayerTileCacheKey key);
  void invalidateFrameComposite(FrameCompositeCacheKey key);
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key);
}

CacheInvalidationExecutionResult executeCacheInvalidationPlan({
  required CacheInvalidationPlan plan,
  required CacheInvalidationSink sink,
}) {
  for (final key in plan.layerTiles) {
    sink.invalidateLayerTile(key);
  }
  for (final key in plan.frameComposites) {
    sink.invalidateFrameComposite(key);
  }
  for (final key in plan.playbackPreviews) {
    sink.invalidatePlaybackPreview(key);
  }

  return CacheInvalidationExecutionResult(
    layerTileCount: plan.layerTiles.length,
    frameCompositeCount: plan.frameComposites.length,
    playbackPreviewCount: plan.playbackPreviews.length,
  );
}
