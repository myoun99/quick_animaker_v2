import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_cache_operation_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_operation_kind.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_cache_invalidation.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_history_policy.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_state.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_execution_result.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_cache_operations.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_session_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_editing_coordinator.dart';
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

  BrushFrameEditingCoordinator coordinator({int userUndoLimit = 8}) {
    final initialKey = key('frame-a');
    return BrushFrameEditingCoordinator(
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

  test('source stroke commit stores dabs and undo redo toggles visibility', () {
    final c = coordinator();
    final sourceDabs = [_dab(0), _dab(1).copyWith(sequence: 1)];

    final command = c.commitSourceStroke(sourceDabs: sourceDabs);

    var frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(frame.commandById(command.id), command);
    expect(frame.visibleActivePaintCommands, [command]);
    expect(frame.hiddenCommandIds, isEmpty);
    expect(command.sourceDabs, sourceDabs);

    c.undo();
    frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(frame.hiddenCommandIds, contains(command.id));
    expect(frame.visibleActivePaintCommands, isEmpty);

    c.redo();
    frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(frame.hiddenCommandIds, isEmpty);
    expect(frame.visibleActivePaintCommands, [command]);
  });

  test('records brush commit in frame store and unified undo history', () {
    final c = coordinator();

    final result = _commitResult(c);
    final affectedEntry = result.affectedEntry!;

    final command = c.applyBrushOperationResult(result);

    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(command, isNotNull);
    expect(command!.materializationRef, isNotNull);
    expect(
      command.materializationRef,
      contains(c.activeFrameKey.layerId.value),
    );
    expect(
      command.materializationRef,
      contains(c.activeFrameKey.frameId.value),
    );
    expect(command.materializationRef, contains(affectedEntry.layerId.value));
    expect(command.materializationRef, contains(affectedEntry.frameId.value));
    expect(
      command.materializationRef,
      contains('dirty-tiles-${affectedEntry.changedTileCount}'),
    );
    expect(frame.livePaintCommands, hasLength(1));
    expect(frame.commandById(command.id), command);
    expect(c.undoHistory.undoStack, hasLength(1));
    expect(c.undoHistory.undoStack.single.isPaintPayload, isTrue);
    expect(
      c.undoHistory.undoStack.single.payloadRef.paintCommandId,
      command.id,
    );
    expect(
      frame.commandById(
        c.undoHistory.undoStack.single.payloadRef.paintCommandId,
      ),
      command,
    );
    expect(c.activeSessionState.materializationHistoryState.undoCount, 1);
  });

  test(
    'commit marks active BrushFrameKey dirty and emits brush invalidation',
    () {
      final c = coordinator();
      final sink = _RecordingSink();

      c.applyBrushOperationResult(
        _commitResult(c),
        cacheInvalidationSink: sink,
      );

      final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
      expect(frame.inactivePreviewDirty, isTrue);
      expect(frame.cacheDirtyTiles.isNotEmpty, isTrue);
      expect(sink.brushFrames, hasLength(1));
      expect(sink.brushFrames.single.frameKey, c.activeFrameKey);
      expect(sink.brushFrames.single.hasDirtyTiles, isTrue);
      expect(sink.brushFrames.single.wholeFrame, isFalse);
    },
  );

  test('undo and redo emit BrushFrameKey dirty invalidations', () {
    final c = coordinator();
    c.applyBrushOperationResult(_commitResult(c));
    final sink = _RecordingSink();

    final undone = c.undo(cacheInvalidationSink: sink);
    final redone = c.redo(cacheInvalidationSink: sink);

    expect(undone!.payloadRef.targetKey, c.activeFrameKey);
    expect(redone!.payloadRef.targetKey, c.activeFrameKey);
    expect(sink.brushFrames, hasLength(2));
    expect(sink.brushFrames.map((event) => event.frameKey), [
      c.activeFrameKey,
      c.activeFrameKey,
    ]);
    expect(sink.brushFrames.every((event) => event.hasDirtyTiles), isTrue);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).inactivePreviewDirty,
      isTrue,
    );
  });

  test('userUndoLimit trim moves old paint command to deferredBake', () {
    final c = coordinator(userUndoLimit: 2);

    c.applyBrushOperationResult(_commitResult(c, index: 0));
    c.applyBrushOperationResult(_commitResult(c, index: 1));
    c.applyBrushOperationResult(_commitResult(c, index: 2));

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
    var frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    var command = frame.commandById(id)!;
    expect(command.state, BrushPaintCommandState.live);
    expect(frame.hiddenCommandIds, contains(id));
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).deferredBakePaintCommands,
      isEmpty,
    );

    c.redo();
    frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    command = frame.commandById(id)!;
    expect(command.state, BrushPaintCommandState.live);
    expect(frame.hiddenCommandIds, isEmpty);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).deferredBakePaintCommands,
      isEmpty,
    );
  });

  test(
    'active-frame public route displays commit, hides undo, and restores redo',
    () {
      final c = coordinator();

      final command = c.applyBrushOperationResult(_commitResult(c));
      expect(command, isNotNull);

      var frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
      expect(frame.visibleActivePaintCommands, [command]);
      expect(_alphaAtActivePixel(c), greaterThan(0));

      c.undo();
      frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
      expect(frame.livePaintCommands, isEmpty);
      expect(frame.hiddenByUndoPaintCommands.map((item) => item.id), [
        command!.id,
      ]);
      expect(frame.visibleActivePaintCommands, isEmpty);
      expect(_alphaAtActivePixel(c), 0);

      c.redo();
      frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
      expect(frame.visibleActivePaintCommands.map((item) => item.id), [
        command.id,
      ]);
      expect(frame.hiddenByUndoPaintCommands, isEmpty);
      expect(_alphaAtActivePixel(c), greaterThan(0));
    },
  );

  test('undo and redo follow global order across frames', () {
    final c = coordinator();
    final frameA = c.activeFrameKey;
    final frameB = key('frame-b');

    c.applyBrushOperationResult(_commitResult(c, index: 0));
    final commandA = c.frameStore
        .getOrCreateFrame(frameA)
        .paintCommands
        .single
        .id;
    c.selectFrame(frameB);
    c.applyBrushOperationResult(_commitResult(c, index: 1));
    final commandB = c.frameStore
        .getOrCreateFrame(frameB)
        .paintCommands
        .single
        .id;

    final firstUndo = c.undo();
    expect(firstUndo!.payloadRef.targetKey, frameB);
    expect(
      c.frameStore.getOrCreateFrame(frameB).hiddenCommandIds,
      contains(commandB),
    );
    expect(
      c.frameStore.getOrCreateFrame(frameA).commandById(commandA)!.state,
      BrushPaintCommandState.live,
    );

    final secondUndo = c.undo();
    expect(secondUndo!.payloadRef.targetKey, frameA);
    expect(
      c.frameStore.getOrCreateFrame(frameA).hiddenCommandIds,
      contains(commandA),
    );

    final firstRedo = c.redo();
    expect(firstRedo!.payloadRef.targetKey, frameA);
    expect(
      c.frameStore.getOrCreateFrame(frameA).commandById(commandA)!.state,
      BrushPaintCommandState.live,
    );
    expect(
      c.frameStore.getOrCreateFrame(frameB).hiddenCommandIds,
      contains(commandB),
    );

    final secondRedo = c.redo();
    expect(secondRedo!.payloadRef.targetKey, frameB);
    expect(
      c.frameStore.getOrCreateFrame(frameB).commandById(commandB)!.state,
      BrushPaintCommandState.live,
    );
    expect(c.activeFrameKey, frameB);
  });

  test('no-op commit does not create paint command or undo history entry', () {
    final c = coordinator();

    final result = _emptyCommitResult(c);
    final command = c.applyBrushOperationResult(result);

    expect(command, isNull);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
      isEmpty,
    );
    expect(c.undoHistory.undoStack, isEmpty);
  });

  test(
    'no-op commit still updates session store when session state differs',
    () {
      final c = coordinator();
      final nextSession = _emptyCommitResult(c).sessionState;

      c.applyBrushOperationResult(
        BrushEditSessionCacheOperationResult(
          kind: BrushEditSessionOperationKind.commit,
          sessionState: nextSession,
          affectedEntry: null,
          cacheInvalidationResult: CacheInvalidationExecutionResult(
            layerTileCount: 0,
            frameCompositeCount: 0,
            playbackPreviewCount: 0,
          ),
        ),
      );

      expect(identical(c.activeSessionState, nextSession), isTrue);
      expect(
        c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
        isEmpty,
      );
      expect(c.undoHistory.undoStack, isEmpty);
    },
  );

  test('session reset preserves frame commands and unified undo history', () {
    final c = coordinator();

    c.applyBrushOperationResult(_commitResult(c));
    final beforeResetSession = c.activeSessionState;
    expect(beforeResetSession.materializationHistoryState.undoCount, 1);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
      hasLength(1),
    );
    expect(c.undoHistory.undoStack, hasLength(1));

    c.sessionStore.reset(c.activeFrameKey);

    expect(identical(c.activeSessionState, beforeResetSession), isFalse);
    expect(c.activeSessionState.materializationHistoryState.undoCount, 0);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
      hasLength(1),
    );
    expect(c.undoHistory.undoStack, hasLength(1));
  });

  test('repeated same-pixel same-color dab is no-op after first commit', () {
    final c = coordinator();

    c.applyBrushOperationResult(_commitResult(c));
    c.applyBrushOperationResult(_commitResult(c));

    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
      hasLength(1),
    );
    expect(c.undoHistory.undoStack, hasLength(1));
    expect(c.activeSessionState.materializationHistoryState.undoCount, 1);
  });
}

BrushDab _dab(int index) => BrushDab(
  center: CanvasPoint(x: 1 + (index * 2), y: 1),
  color: 0xFF000000,
  size: 2,
  opacity: 1,
  flow: 1,
  hardness: 1,
  tipShape: BrushTipShape.round,
  pressure: 1,
  sequence: 0,
);

BrushEditSessionCacheOperationResult _commitResult(
  BrushFrameEditingCoordinator coordinator, {
  int index = 0,
}) {
  return commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
    sessionState: coordinator.activeSessionState,
    sequence: BrushDabSequence([_dab(index)]),
    layerId: coordinator.activeFrameKey.layerId,
    frameId: coordinator.activeFrameKey.frameId,
    cacheInvalidationSink: _NoopSink(),
  );
}

BrushEditSessionCacheOperationResult _emptyCommitResult(
  BrushFrameEditingCoordinator coordinator,
) {
  return commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
    sessionState: coordinator.activeSessionState,
    sequence: BrushDabSequence(),
    layerId: coordinator.activeFrameKey.layerId,
    frameId: coordinator.activeFrameKey.frameId,
    cacheInvalidationSink: _NoopSink(),
  );
}

class _RecordingSink implements CacheInvalidationSink {
  final brushFrames = <BrushFrameCacheInvalidation>[];

  @override
  void invalidateBrushFrame(BrushFrameCacheInvalidation invalidation) =>
      brushFrames.add(invalidation);

  @override
  void invalidateFrameComposite(key) {}

  @override
  void invalidateLayerTile(key) {}

  @override
  void invalidatePlaybackPreview(key) {}
}

class _NoopSink implements CacheInvalidationSink {
  @override
  void invalidateBrushFrame(BrushFrameCacheInvalidation invalidation) {}

  @override
  void invalidateFrameComposite(key) {}

  @override
  void invalidateLayerTile(key) {}

  @override
  void invalidatePlaybackPreview(key) {}
}

int _alphaAtActivePixel(BrushFrameEditingCoordinator coordinator) {
  final surface = coordinator.activeSessionState.canvasState.currentSurface;
  final tile = surface.tileAt(TileCoord(x: 0, y: 0));
  if (tile == null) {
    return 0;
  }
  final pixels = tile.pixels;
  final offset = tile.byteOffsetForPixel(x: 1, y: 1);
  return pixels[offset + 3];
}
