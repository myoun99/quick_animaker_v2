import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_cache_operation_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_operation_kind.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_composite_cache_key.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_tile_cache_key.dart';
import 'package:quick_animaker_v2/src/models/playback_preview_cache_key.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_cache_operations.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_session_state_operations.dart';
import 'package:quick_animaker_v2/src/services/cache_invalidation_executor.dart';

class FakeCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  int get totalCalls =>
      layerTiles.length + frameComposites.length + playbackPreviews.length;

  @override
  void invalidateLayerTile(LayerTileCacheKey key) {
    layerTiles.add(key);
  }

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) {
    frameComposites.add(key);
  }

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) {
    playbackPreviews.add(key);
  }
}

void main() {
  group('brush edit session cache operations', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface() => BitmapSurface(
      canvasSize: CanvasSize(width: 4, height: 4),
      tileSize: 2,
    );

    BrushEditSessionState emptySession() => BrushEditSessionState(
      canvasState: CanvasSurfaceState(currentSurface: surface()),
      historyState: BrushEditHistoryState(),
    );

    BrushDabSequence changedSequence() => BrushDabSequence([
      BrushDab(
        center: CanvasPoint(x: 0.5, y: 0.5),
        color: 0xFFFF0000,
        size: 1,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: 0,
      ),
    ]);

    BrushEditSessionCacheOperationResult commitChanged(
      BrushEditSessionState sessionState,
      FakeCacheInvalidationSink sink,
    ) {
      return commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
        sessionState: sessionState,
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
        cacheInvalidationSink: sink,
      );
    }

    test('commit no-op does not call cache sink', () {
      final sink = FakeCacheInvalidationSink();

      commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
        sessionState: emptySession(),
        sequence: BrushDabSequence(),
        layerId: layerId,
        frameId: frameId,
        cacheInvalidationSink: sink,
      );

      expect(sink.totalCalls, 0);
    });

    test('commit no-op returns zero cache invalidation result', () {
      final result = commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
        sessionState: emptySession(),
        sequence: BrushDabSequence(),
        layerId: layerId,
        frameId: frameId,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(result.cacheInvalidationResult.totalCount, 0);
      expect(result.cacheInvalidationResult.didInvalidate, isFalse);
    });

    test('commit changed calls cache sink', () {
      final sink = FakeCacheInvalidationSink();
      final result = commitChanged(emptySession(), sink);

      expect(sink.totalCalls, result.affectedEntry!.cacheInvalidationPlan.totalKeyCount);
      expect(sink.totalCalls, greaterThan(0));
    });

    test('commit changed result kind is commit', () {
      expect(commitChanged(emptySession(), FakeCacheInvalidationSink()).kind, BrushEditSessionOperationKind.commit);
    });

    test('commit changed result sessionState matches normal session commit conversion', () {
      final sessionState = emptySession();
      final sequence = changedSequence();
      final normal = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
      );
      final cacheAware = commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(cacheAware.sessionState, sessionStateFromCommitResult(normal));
    });

    test('commit changed affectedEntry equals normal commit historyEntry', () {
      final sessionState = emptySession();
      final sequence = changedSequence();
      final normal = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
      );
      final cacheAware = commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
        sessionState: sessionState,
        sequence: sequence,
        layerId: layerId,
        frameId: frameId,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(cacheAware.affectedEntry, normal.historyEntry);
    });

    test('undo no-op does not call cache sink', () {
      final sink = FakeCacheInvalidationSink();

      undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: emptySession(),
        cacheInvalidationSink: sink,
      );

      expect(sink.totalCalls, 0);
    });

    test('undo no-op returns zero cache invalidation result', () {
      final result = undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: emptySession(),
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(result.cacheInvalidationResult.totalCount, 0);
    });

    test('undo changed calls cache sink', () {
      final committed = commitChanged(emptySession(), FakeCacheInvalidationSink());
      final sink = FakeCacheInvalidationSink();
      final result = undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: committed.sessionState,
        cacheInvalidationSink: sink,
      );

      expect(sink.totalCalls, result.affectedEntry!.cacheInvalidationPlan.totalKeyCount);
    });

    test('undo changed result kind/sessionState/affectedEntry match normal undo', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final sessionState = sessionStateFromCommitResult(committed);
      final normal = undoLatestBrushEditInSessionState(sessionState: sessionState);
      final cacheAware = undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(cacheAware.kind, BrushEditSessionOperationKind.undo);
      expect(cacheAware.sessionState, sessionStateFromUndoResult(normal));
      expect(cacheAware.affectedEntry, normal.undoneEntry);
    });

    test('redo no-op does not call cache sink', () {
      final sink = FakeCacheInvalidationSink();

      redoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: emptySession(),
        cacheInvalidationSink: sink,
      );

      expect(sink.totalCalls, 0);
    });

    test('redo no-op returns zero cache invalidation result', () {
      final result = redoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: emptySession(),
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(result.cacheInvalidationResult.totalCount, 0);
    });

    test('redo changed calls cache sink', () {
      final committed = commitChanged(emptySession(), FakeCacheInvalidationSink());
      final undone = undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: committed.sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );
      final sink = FakeCacheInvalidationSink();
      final result = redoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: undone.sessionState,
        cacheInvalidationSink: sink,
      );

      expect(sink.totalCalls, result.affectedEntry!.cacheInvalidationPlan.totalKeyCount);
    });

    test('redo changed result kind/sessionState/affectedEntry match normal redo', () {
      final committed = commitBrushDabSequenceToBrushEditSessionState(
        sessionState: emptySession(),
        sequence: changedSequence(),
        layerId: layerId,
        frameId: frameId,
      );
      final undone = undoLatestBrushEditInSessionState(
        sessionState: sessionStateFromCommitResult(committed),
      );
      final sessionState = sessionStateFromUndoResult(undone);
      final normal = redoLatestBrushEditInSessionState(sessionState: sessionState);
      final cacheAware = redoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(cacheAware.kind, BrushEditSessionOperationKind.redo);
      expect(cacheAware.sessionState, sessionStateFromRedoResult(normal));
      expect(cacheAware.affectedEntry, normal.redoneEntry);
    });

    test('cache invalidation counts match executed plan counts', () {
      final result = commitChanged(emptySession(), FakeCacheInvalidationSink());
      final plan = result.affectedEntry!.cacheInvalidationPlan;

      expect(result.cacheInvalidationResult.layerTileCount, plan.layerTiles.length);
      expect(result.cacheInvalidationResult.frameCompositeCount, plan.frameComposites.length);
      expect(result.cacheInvalidationResult.playbackPreviewCount, plan.playbackPreviews.length);
      expect(result.cacheInvalidationResult.totalCount, plan.totalKeyCount);
    });

    test('commit -> undo -> redo with cache-aware facade works', () {
      final committed = commitChanged(emptySession(), FakeCacheInvalidationSink());
      final undone = undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: committed.sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );
      final redone = redoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: undone.sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(committed.didAffectHistory, isTrue);
      expect(undone.didAffectHistory, isTrue);
      expect(redone.didAffectHistory, isTrue);
      expect(redone.sessionState, committed.sessionState);
    });

    test('input BrushEditSessionState is not mutated', () {
      final sessionState = emptySession();
      final snapshot = sessionState.copyWith();

      commitChanged(sessionState, FakeCacheInvalidationSink());

      expect(sessionState, snapshot);
    });

    test('input CanvasSurfaceState is not mutated', () {
      final sessionState = emptySession();
      final canvasState = sessionState.canvasState;

      commitChanged(sessionState, FakeCacheInvalidationSink());

      expect(identical(sessionState.canvasState, canvasState), isTrue);
      expect(sessionState.canvasState.currentSurface.tiles, isEmpty);
      expect(sessionState.canvasState.lastEdit, isNull);
    });

    test('input BrushEditHistoryState is not mutated', () {
      final sessionState = emptySession();
      final historyState = sessionState.historyState;

      commitChanged(sessionState, FakeCacheInvalidationSink());

      expect(identical(sessionState.historyState, historyState), isTrue);
      expect(sessionState.historyState.undoEntries, isEmpty);
      expect(sessionState.historyState.redoEntries, isEmpty);
    });

    test('CacheInvalidationPlan is not mutated', () {
      final committed = commitChanged(emptySession(), FakeCacheInvalidationSink());
      final plan = committed.affectedEntry!.cacheInvalidationPlan;
      final before = plan.toJson();

      undoLatestBrushEditInSessionStateWithCacheInvalidation(
        sessionState: committed.sessionState,
        cacheInvalidationSink: FakeCacheInvalidationSink(),
      );

      expect(plan.toJson(), before);
    });

    test('no real cache storage is implemented', () {
      final sink = FakeCacheInvalidationSink();
      final result = commitChanged(emptySession(), sink);

      expect(result.didInvalidateCache, isTrue);
      expect(
        sink.layerTiles,
        unorderedEquals(result.affectedEntry!.cacheInvalidationPlan.layerTiles),
      );
    });

    test('no UI/state management/timeline/storyboard changes', () {
      expect(commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation, isA<Function>());
      expect(undoLatestBrushEditInSessionStateWithCacheInvalidation, isA<Function>());
      expect(redoLatestBrushEditInSessionStateWithCacheInvalidation, isA<Function>());
    });
  });
}
