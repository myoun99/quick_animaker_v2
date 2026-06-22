import '../models/cache_invalidation_plan.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import '../models/tile_delta_command.dart';

CacheInvalidationPlan cacheInvalidationPlanForTileDeltaCommand({
  required LayerId layerId,
  required FrameId frameId,
  required TileDeltaCommand? command,
}) {
  if (command == null) return CacheInvalidationPlan.empty();

  return CacheInvalidationPlan.fromTileDeltaCommand(
    layerId: layerId,
    frameId: frameId,
    command: command,
  );
}
