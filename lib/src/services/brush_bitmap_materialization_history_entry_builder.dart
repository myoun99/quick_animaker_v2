import '../models/brush_bitmap_materialization_history_entry.dart';
import '../models/brush_surface_edit.dart';
import '../models/frame_id.dart';
import '../models/layer_id.dart';

BrushBitmapMaterializationHistoryEntry?
brushBitmapMaterializationHistoryEntryFromBrushSurfaceEdit({
  required BrushSurfaceEdit edit,
  required LayerId layerId,
  required FrameId frameId,
}) {
  if (edit.isNoOp) return null;

  return BrushBitmapMaterializationHistoryEntry(
    layerId: layerId,
    frameId: frameId,
    commitResult: edit.commitResult,
  );
}
