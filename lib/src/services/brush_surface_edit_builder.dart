import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/dirty_region.dart';
import '../models/brush_dab_sequence.dart';
import '../models/brush_surface_edit.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';
import 'brush_commit_builder.dart';

BrushSurfaceEdit brushSurfaceEditForBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
  required LayerId layerId,
  required FrameId frameId,
  Uint8List? prerasterizedStrokePixels,
  DirtyRegion? prerasterizedStrokeBounds,
}) {
  final commitResult = brushCommitResultForBrushDabSequenceOnBitmapSurface(
    surface: surface,
    sequence: sequence,
    layerId: layerId,
    frameId: frameId,
    prerasterizedStrokePixels: prerasterizedStrokePixels,
    prerasterizedStrokeBounds: prerasterizedStrokeBounds,
  );

  return BrushSurfaceEdit(
    beforeSurface: surface,
    afterSurface: commitResult.afterSurface,
    commitResult: commitResult,
  );
}
