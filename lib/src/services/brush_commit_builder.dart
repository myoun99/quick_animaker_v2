import '../models/bitmap_surface.dart';
import '../models/brush_commit_result.dart';
import '../models/brush_dab_sequence.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'bitmap_surface_brush_commit.dart';
import 'brush_commit_cache_invalidation.dart';

BrushCommitResult brushCommitResultForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  final materialization = materializeBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: sequence,
  );
  final cacheInvalidationPlan = cacheInvalidationPlanForDirtyTiles(
    layerId: layerId,
    frameId: frameId,
    dirtyTiles: materialization.dirtyTiles,
  );

  if (!materialization.hasChanges) {
    return BrushCommitResult.noOp(surface: surface);
  }

  return BrushCommitResult.changed(
    beforeSurface: surface,
    afterSurface: materialization.surface,
    dirtyTiles: materialization.dirtyTiles,
    cacheInvalidationPlan: cacheInvalidationPlan,
  );
}
