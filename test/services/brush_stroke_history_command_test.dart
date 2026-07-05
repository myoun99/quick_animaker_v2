import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/brush_stroke_commit_data.dart';
import 'package:quick_animaker_v2/src/services/commands/brush_stroke_history_command.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';

void main() {
  test('app-level undo and redo hide and restore the latest brush stroke', () {
    final coordinator = _coordinator();
    final history = HistoryManager();

    history.execute(
      BrushStrokeHistoryCommand(
        coordinator: coordinator,
        strokeData: BrushStrokeCommitData(sourceDabs: [_dab(0), _dab(1)]),
      ),
    );

    var frame = coordinator.frameStore.getOrCreateFrame(
      coordinator.activeFrameKey,
    );
    expect(frame.visibleActivePaintCommands, hasLength(1));
    expect(history.canUndo, isTrue);

    history.undo();
    frame = coordinator.frameStore.getOrCreateFrame(coordinator.activeFrameKey);
    expect(frame.visibleActivePaintCommands, isEmpty);
    expect(history.canRedo, isTrue);

    history.redo();
    frame = coordinator.frameStore.getOrCreateFrame(coordinator.activeFrameKey);
    expect(frame.visibleActivePaintCommands, hasLength(1));
    expect(frame.visibleActivePaintCommands.single.sourceDabs, [
      _dab(0),
      _dab(1),
    ]);
  });
}

BrushFrameEditingCoordinator _coordinator() {
  final key = BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: const FrameId('frame'),
  );
  return BrushFrameEditingCoordinator(
    initialFrameKey: key,
    frameStore: BrushFrameStore(),
    sessionStore: BrushFrameEditSessionStore(
      canvasSize: const CanvasSize(width: 8, height: 8),
    ),
    historyPolicy: const BrushHistoryPolicy(
      userUndoLimit: 8,
      deferredBakeRatio: 0,
    ),
  );
}

BrushDab _dab(int sequence) {
  return BrushDab(
    // Pixel-center coordinates: the commit rasterizer samples pixel centers,
    // so a size-1 dab must sit on x.5 to paint (WYSIWYG semantics).
    center: CanvasPoint(x: sequence + 0.5, y: sequence + 0.5),
    color: 0xFF000000,
    size: 1,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: sequence,
  );
}
