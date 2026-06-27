import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_cache_operation_result.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_state.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_cache_operations.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/brush_workspace_coordinator.dart';
import 'package:quick_animaker_v2/src/services/cache_invalidation_executor.dart';

void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);
  BrushFrameKey key(String frameId) => BrushFrameKey(
    projectId: const ProjectId('project'),
    trackId: const TrackId('track'),
    cutId: const CutId('cut'),
    layerId: const LayerId('layer'),
    frameId: FrameId(frameId),
  );

  BrushWorkspaceCoordinator coordinator({int userUndoLimit = 8}) {
    final initialKey = key('frame-a');
    return BrushWorkspaceCoordinator(
      initialFrameKey: initialKey,
      frameStore: BrushFrameStore(),
      sessionStore: BrushFrameEditSessionStore(
        canvasSize: canvasSize,
        tileSize: 4,
      ),
      historyPolicy: BrushHistoryPolicy(
        userUndoLimit: userUndoLimit,
        deferredBakeRatio: 0,
      ),
    );
  }

  test('records brush commit in frame store and unified undo history', () {
    final c = coordinator();

    c.applyBrushOperationResult(_commitResult(c));

    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(frame.livePaintCommands, hasLength(1));
    expect(c.undoHistory.undoStack, hasLength(1));
    expect(c.undoHistory.undoStack.single.isPaintPayload, isTrue);
    expect(c.activeSessionState.historyState.undoCount, 1);
  });

  test('userUndoLimit trim moves old paint command to deferredBake', () {
    final c = coordinator(userUndoLimit: 2);

    c.applyBrushOperationResult(_commitResult(c));
    c.applyBrushOperationResult(_commitResult(c));
    c.applyBrushOperationResult(_commitResult(c));

    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(c.undoHistory.undoStack, hasLength(2));
    expect(frame.deferredBakePaintCommands, hasLength(1));
    expect(
      frame.deferredBakePaintCommands.single.state,
      BrushPaintCommandState.deferredBake,
    );
    expect(frame.visibleActivePaintCommands, hasLength(3));
  });

  test('undo and redo update paint state without deferred baking', () {
    final c = coordinator();
    c.applyBrushOperationResult(_commitResult(c));
    final id = c.frameStore
        .getOrCreateFrame(c.activeFrameKey)
        .paintCommands
        .single
        .id;

    c.undo();
    var command = c.frameStore
        .getOrCreateFrame(c.activeFrameKey)
        .commandById(id)!;
    expect(command.state, BrushPaintCommandState.hiddenByUndo);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).deferredBakePaintCommands,
      isEmpty,
    );

    c.redo();
    command = c.frameStore.getOrCreateFrame(c.activeFrameKey).commandById(id)!;
    expect(command.state, BrushPaintCommandState.live);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).deferredBakePaintCommands,
      isEmpty,
    );
  });
}

BrushDab _dab() => BrushDab(
  center: CanvasPoint(x: 1, y: 1),
  color: 0xFF000000,
  size: 1,
  opacity: 1,
  flow: 1,
  hardness: 1,
  tipShape: BrushTipShape.round,
  pressure: 1,
  sequence: 0,
);

BrushEditSessionCacheOperationResult _commitResult(
  BrushWorkspaceCoordinator coordinator,
) {
  return commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
    sessionState: coordinator.activeSessionState,
    sequence: BrushDabSequence([_dab()]),
    layerId: coordinator.activeFrameKey.layerId,
    frameId: coordinator.activeFrameKey.frameId,
    cacheInvalidationSink: _NoopSink(),
  );
}

class _NoopSink implements CacheInvalidationSink {
  @override
  void invalidateFrameComposite(key) {}

  @override
  void invalidateLayerTile(key) {}

  @override
  void invalidatePlaybackPreview(key) {}
}
