import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_cache_invalidation.dart';
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
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_display_cache_renderer.dart';
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

    final command = c.commitSourceStroke(sourceDabs: sourceDabs)!;

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

  test('commit materializes the stroke and records unified undo history', () {
    final c = coordinator();

    final command = c.commitSourceStroke(sourceDabs: [_dab(0)])!;

    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(command.sourceDabs, isNotEmpty);
    expect(command.materializationRef, isNotNull);
    expect(
      command.materializationRef,
      contains(c.activeFrameKey.layerId.value),
    );
    expect(
      command.materializationRef,
      contains(c.activeFrameKey.frameId.value),
    );
    expect(command.materializationRef, contains('dirty-tiles-'));
    expect(frame.livePaintCommands, hasLength(1));
    expect(frame.commandById(command.id), command);
    expect(c.undoHistory.undoStack, hasLength(1));
    expect(c.undoHistory.undoStack.single.isPaintPayload, isTrue);
    expect(
      c.undoHistory.undoStack.single.payloadRef.paintCommandId,
      command.id,
    );
    expect(c.activeSessionState.materializationHistoryState.undoCount, 1);
    expect(_alphaAtActivePixel(c), greaterThan(0));
  });

  test('commit emits brush invalidation and leaves a FRESH display cache '
      '(the session surface is donated — no consumer replays the frame)', () {
    final c = coordinator();
    final sink = _RecordingSink();

    c.commitSourceStroke(sourceDabs: [_dab(0)], cacheInvalidationSink: sink);

    // Derived ui.Image caches still re-upload via the sink…
    expect(sink.brushFrames, hasLength(1));
    expect(sink.brushFrames.single.frameKey, c.activeFrameKey);
    expect(sink.brushFrames.single.hasDirtyTiles, isTrue);
    expect(sink.brushFrames.single.wholeFrame, isFalse);
    // …but the display cache is already valid at the new revision: the
    // commit donated the session surface, so nothing replays commands.
    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    expect(frame.inactivePreviewDirty, isFalse);
    expect(frame.cacheDirtyTiles.isEmpty, isTrue);
    final cache = c.frameStore.displayCacheOrNull(c.activeFrameKey)!;
    expect(cache.isValid, isTrue);
    expect(cache.sourceRevision, frame.sourceRevision);
    expect(
      identical(
        cache.previewSurface,
        c.activeSessionState.canvasState.currentSurface,
      ),
      isTrue,
      reason: 'donation shares the immutable surface, no copy',
    );
  });

  test('undo and redo emit invalidations and keep the display cache fresh', () {
    final c = coordinator();
    c.commitSourceStroke(sourceDabs: [_dab(0)]);
    final sink = _RecordingSink();

    final undone = c.undo(cacheInvalidationSink: sink);

    expect(undone!.payloadRef.targetKey, c.activeFrameKey);
    final afterUndo = c.frameStore.displayCacheOrNull(c.activeFrameKey)!;
    expect(afterUndo.isValid, isTrue);
    expect(
      identical(
        afterUndo.previewSurface,
        c.activeSessionState.canvasState.currentSurface,
      ),
      isTrue,
      reason: 'undo donates the reverted session surface',
    );

    final redone = c.redo(cacheInvalidationSink: sink);

    expect(redone!.payloadRef.targetKey, c.activeFrameKey);
    expect(sink.brushFrames, hasLength(2));
    expect(sink.brushFrames.map((event) => event.frameKey), [
      c.activeFrameKey,
      c.activeFrameKey,
    ]);
    expect(sink.brushFrames.every((event) => event.hasDirtyTiles), isTrue);
    final afterRedo = c.frameStore.displayCacheOrNull(c.activeFrameKey)!;
    expect(afterRedo.isValid, isTrue);
    expect(
      identical(
        afterRedo.previewSurface,
        c.activeSessionState.canvasState.currentSurface,
      ),
      isTrue,
    );
  });

  test('the donated display cache is byte-identical to a command replay', () {
    final c = coordinator();
    c.commitSourceStroke(sourceDabs: [_dab(0), _dab(1).copyWith(sequence: 1)]);
    c.commitSourceStroke(sourceDabs: [_dab(2)]);

    final frame = c.frameStore.getOrCreateFrame(c.activeFrameKey);
    final donated = c.frameStore
        .displayCacheOrNull(c.activeFrameKey)!
        .previewSurface;
    final replayed = const BrushFrameDisplayCacheRenderer(
      canvasSize: canvasSize,
      tileSize: 4,
    ).rebuildPreview(frame);

    expect(donated.tiles.keys.toSet(), replayed.tiles.keys.toSet());
    for (final coord in replayed.tiles.keys) {
      expect(
        donated.tileAt(coord)!.pixels,
        replayed.tileAt(coord)!.pixels,
        reason: 'tile $coord must match the reference replay byte-for-byte',
      );
    }
  });

  test('userUndoLimit trim moves old paint command to deferredBake', () {
    final c = coordinator(userUndoLimit: 2);

    c.commitSourceStroke(sourceDabs: [_dab(0)]);
    c.commitSourceStroke(sourceDabs: [_dab(1)]);
    c.commitSourceStroke(sourceDabs: [_dab(2)]);

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
    c.commitSourceStroke(sourceDabs: [_dab(0)]);
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

      final command = c.commitSourceStroke(sourceDabs: [_dab(0)]);
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

    c.commitSourceStroke(sourceDabs: [_dab(0)]);
    final commandA = c.frameStore
        .getOrCreateFrame(frameA)
        .paintCommands
        .single
        .id;
    c.selectFrame(frameB);
    c.commitSourceStroke(sourceDabs: [_dab(1)]);
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

  test('stroke that changes no pixels creates no command or undo entry', () {
    final c = coordinator();

    final first = c.commitSourceStroke(sourceDabs: [_dab(0)]);
    final second = c.commitSourceStroke(sourceDabs: [_dab(0)]);

    expect(first, isNotNull);
    expect(second, isNull);
    expect(
      c.frameStore.getOrCreateFrame(c.activeFrameKey).paintCommands,
      hasLength(1),
    );
    expect(c.undoHistory.undoStack, hasLength(1));
    expect(c.activeSessionState.materializationHistoryState.undoCount, 1);
  });

  test('session reset preserves frame commands and unified undo history', () {
    final c = coordinator();

    c.commitSourceStroke(sourceDabs: [_dab(0)]);
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
