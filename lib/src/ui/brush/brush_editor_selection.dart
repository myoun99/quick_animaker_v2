import '../../models/brush_frame_key.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/layer_id.dart';
import '../../models/project_id.dart';
import '../../models/track_id.dart';

/// Small bridge from the editor's active Project / Track / Cut / Layer / Frame
/// selection into the Brush frame identity used by the brush session stores.
///
/// This intentionally owns no app state. HomePage builds it from existing
/// editor controllers, then converts it to [BrushFrameKey] for the main canvas
/// brush preview path.
class BrushEditorSelection {
  const BrushEditorSelection({
    required this.projectId,
    required this.trackId,
    required this.cutId,
    required this.layerId,
    required this.frameId,
  });

  final ProjectId projectId;
  final TrackId trackId;
  final CutId cutId;
  final LayerId layerId;
  final FrameId frameId;

  BrushFrameKey toBrushFrameKey() => BrushFrameKey(
    projectId: projectId,
    trackId: trackId,
    cutId: cutId,
    layerId: layerId,
    frameId: frameId,
  );
}
