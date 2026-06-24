import '../models/bitmap_surface.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_surface_edit.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_commit_builder.dart';
import 'brush_commit_result_apply.dart';

BrushSurfaceEdit brushSurfaceEditForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
}) {
  final commitResult = brushCommitResultForBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
  );
  final afterSurface = applyBrushCommitResultToBitmapSurface(
    surface: surface,
    result: commitResult,
  );

  return BrushSurfaceEdit(
    beforeSurface: surface,
    afterSurface: afterSurface,
    commitResult: commitResult,
  );
}
