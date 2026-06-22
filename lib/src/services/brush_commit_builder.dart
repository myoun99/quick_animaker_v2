import '../models/bitmap_surface.dart';
import '../models/brush_commit_result.dart';
import '../models/brush_dab_sequence.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import '../models/tile_delta_command.dart';
import 'bitmap_surface_brush_commit.dart';
import 'brush_commit_cache_invalidation.dart';

BrushCommitResult brushCommitResultForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  final TileDeltaCommand? command =
      tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: sequence,
      );
  final cacheInvalidationPlan = cacheInvalidationPlanForTileDeltaCommand(
    layerId: layerId,
    frameId: frameId,
    command: command,
  );

  if (command == null) return BrushCommitResult.noOp();

  return BrushCommitResult.changed(
    command: command,
    cacheInvalidationPlan: cacheInvalidationPlan,
  );
}
