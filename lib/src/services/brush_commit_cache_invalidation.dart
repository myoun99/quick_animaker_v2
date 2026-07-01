import '../models/cache_invalidation_plan.dart';
import '../models/dirty_tile_set.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';

CacheInvalidationPlan cacheInvalidationPlanForDirtyTiles({
  required LayerId layerId,
  required FrameId frameId,
  required DirtyTileSet dirtyTiles,
}) {
  if (dirtyTiles.isEmpty) return CacheInvalidationPlan.empty();
  return CacheInvalidationPlan.fromDirtyTiles(
    layerId: layerId,
    frameId: frameId,
    dirtyTiles: dirtyTiles,
  );
}
