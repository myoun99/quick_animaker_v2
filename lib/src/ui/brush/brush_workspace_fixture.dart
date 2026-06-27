import '../../models/brush_frame_key.dart';
import '../../models/brush_history_policy.dart';
import '../../models/canvas_size.dart';
import '../../models/cut_id.dart';
import '../../models/frame_id.dart';
import '../../models/project_id.dart';
import '../../models/layer_id.dart';
import '../../models/track_id.dart';
import '../../services/brush_frame_edit_session_store.dart';
import '../../services/brush_frame_store.dart';
import '../../services/brush_workspace_coordinator.dart';

/// Temporary Brush workspace fixture used until the real editor selection
/// supplies Project / Track / Cut / Layer / Frame identity.
///
/// This intentionally does not store drawing payload in Frame models. Drawing
/// state remains in [BrushFrameStore] and [BrushFrameEditSessionStore].
class BrushWorkspaceFixture {
  const BrushWorkspaceFixture._();

  static const projectId = ProjectId('brush-workspace-project');
  static const trackId = TrackId('brush-workspace-track');
  static const cutId = CutId('brush-workspace-cut');
  static const layerId = LayerId('brush-workspace-layer');
  static const canvasSize = CanvasSize(width: 320, height: 240);

  static const frameIds = [
    FrameId('frame-1'),
    FrameId('frame-2'),
    FrameId('frame-3'),
  ];

  static List<BrushFrameKey> createFrameKeys() => frameIds
      .map(
        (frameId) => BrushFrameKey(
          projectId: projectId,
          trackId: trackId,
          cutId: cutId,
          layerId: layerId,
          frameId: frameId,
        ),
      )
      .toList(growable: false);

  static BrushWorkspaceCoordinator createCoordinator({
    List<BrushFrameKey>? frameKeys,
    BrushHistoryPolicy historyPolicy = const BrushHistoryPolicy(
      userUndoLimit: 24,
      deferredBakeRatio: 0,
    ),
  }) {
    final keys = frameKeys ?? createFrameKeys();
    return BrushWorkspaceCoordinator(
      initialFrameKey: keys.first,
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(canvasSize: canvasSize),
      historyPolicy: historyPolicy,
    );
  }
}
