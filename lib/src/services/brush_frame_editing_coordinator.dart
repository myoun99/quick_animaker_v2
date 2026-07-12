import 'dart:typed_data';

import '../models/brush_bitmap_materialization_history_entry.dart';
import '../models/brush_dab.dart';
import '../models/brush_dab_sequence.dart';
import '../models/canvas_size.dart';
import '../models/canvas_surface_state.dart';
import '../models/dirty_region.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_frame_cache_invalidation.dart';
import '../models/brush_frame_key.dart';
import '../models/brush_history_policy.dart';
import '../models/dirty_tile_set.dart';
import '../models/brush_paint_command.dart';
import '../models/brush_paint_command_id.dart';
import '../models/brush_paint_command_state.dart';
import '../models/undo_history_entry.dart';
import '../models/undo_history_entry_id.dart';
import '../models/undo_history_entry_kind.dart';
import '../models/undo_payload_ref.dart';
import '../models/unified_undo_history.dart';
import 'bitmap_surface_brush_commit.dart';
import 'brush_edit_session_cache_operations.dart';
import 'brush_frame_edit_session_store.dart';
import 'brush_frame_store.dart';
import 'brush_materialization_history_budget.dart';
import 'cache_invalidation_executor.dart';

class BrushFrameEditingCoordinator {
  BrushFrameEditingCoordinator({
    required BrushFrameKey initialFrameKey,
    required this.frameStore,
    required this.sessionStore,
    required this.historyPolicy,
    UnifiedUndoHistory? undoHistory,
  }) : _activeFrameKey = initialFrameKey,
       _undoHistory =
           undoHistory ??
           UnifiedUndoHistory(userUndoLimit: historyPolicy.userUndoLimit);

  final BrushFrameStore frameStore;
  final BrushFrameEditSessionStore sessionStore;
  final BrushHistoryPolicy historyPolicy;
  BrushFrameKey _activeFrameKey;
  UnifiedUndoHistory _undoHistory;
  int _nextSequenceNumber = 1;

  BrushFrameKey get activeFrameKey => _activeFrameKey;
  UnifiedUndoHistory get undoHistory => _undoHistory;
  bool get canUndo => _undoHistory.undoStack.isNotEmpty;
  bool get canRedo => _undoHistory.redoStack.isNotEmpty;
  BrushEditSessionState get activeSessionState => _sessionFor(_activeFrameKey);

  void selectFrame(BrushFrameKey key) {
    frameStore.getOrCreateFrame(key);
    _sessionFor(key);
    _activeFrameKey = key;
  }

  /// Adopts a new editing canvas size.
  ///
  /// Session surfaces and display caches are derived at the old size, so they
  /// are dropped and rebuilt from the durable paint commands. Stroke
  /// coordinates are untouched (top-left anchor): shrinking crops
  /// non-destructively and growing extends with transparency, so resizing back
  /// restores the original picture.
  void resizeCanvas(CanvasSize canvasSize) {
    if (canvasSize == sessionStore.canvasSize) {
      return;
    }
    sessionStore.resizeCanvas(canvasSize);
    frameStore.clearDisplayCaches();
    _rebuildSessionFromCommands(_activeFrameKey);
  }

  BrushEditSessionState _sessionFor(BrushFrameKey key) {
    return sessionStore.sessionOrNull(key) ?? _rebuildSessionFromCommands(key);
  }

  /// Rebuilds the frame's session surface at the store's current canvas
  /// size. A VALID display cache seeds it directly (byte-identical to a
  /// replay — donations come FROM session surfaces and rebuilt caches ride
  /// the parity-pinned renderer), so opening a frame costs O(1) instead of
  /// replaying its whole stroke history (R11-⑦: the first edit of every
  /// frame after a project load replayed thousands of commands). The
  /// command replay stays the cold fallback. The bitmap materialization
  /// history starts empty either way; undo/redo of older strokes falls
  /// back to a full replay.
  BrushEditSessionState _rebuildSessionFromCommands(BrushFrameKey key) {
    final blank = sessionStore.reset(key);
    final commands =
        frameStore.frameOrNull(key)?.allPaintCommandsInDisplayOrder ??
        const <BrushPaintCommand>[];
    if (commands.isEmpty) {
      return blank;
    }
    final cachedSurface = frameStore.validPreviewSurfaceOrNull(key);
    if (cachedSurface != null &&
        cachedSurface.canvasSize == sessionStore.canvasSize) {
      return sessionStore.update(
        key,
        blank.copyWith(
          canvasState: CanvasSurfaceState(currentSurface: cachedSurface),
        ),
      );
    }
    var surface = blank.canvasState.currentSurface;
    for (final command in commands) {
      if (command.sourceDabs.isEmpty) {
        continue;
      }
      surface = materializeBrushDabSequenceOnBitmapSurface(
        surface: surface,
        sequence: BrushDabSequence(command.sourceDabs),
      ).surface;
    }
    final rebuilt = sessionStore.update(
      key,
      blank.copyWith(canvasState: CanvasSurfaceState(currentSurface: surface)),
    );
    // The replay just produced the frame's exact pixels — donate them so no
    // display consumer replays the same commands again.
    _donateSessionSurfaceToDisplayCache(key, rebuilt);
    return rebuilt;
  }

  /// Donates the session's post-edit surface to the store's display cache.
  ///
  /// The commit fast path already produced the exact post-stroke pixels
  /// (byte-identical to a command replay — the three-route parity suites pin
  /// live == commit == reference), and [BitmapSurface] is an immutable tile
  /// map, so sharing it is a free snapshot. Downstream consumers (playback
  /// layer images, storyboard thumbnails, camera preview) then skip the
  /// full-frame command replay whose cost grows with every stroke on the
  /// frame — the post-stroke UI freeze.
  void _donateSessionSurfaceToDisplayCache(
    BrushFrameKey key,
    BrushEditSessionState sessionState,
  ) {
    frameStore.storeRebuiltDisplayCache(
      key: key,
      previewSurface: sessionState.canvasState.currentSurface,
    );
  }

  /// Commits a finished stroke: stores the source dabs as the durable
  /// [BrushPaintCommand] (source of truth) and materializes the stroke into
  /// the session bitmap surface so the canvas displays exactly what was
  /// committed and undo/redo can revert the bitmap alongside the command.
  ///
  /// Returns `null` when the stroke changed no pixels: creating a paint
  /// command and undo entry without a matching bitmap materialization entry
  /// would desynchronize the two histories, making a later undo revert the
  /// previous stroke's bitmap while hiding the no-op command.
  BrushPaintCommand? commitSourceStroke({
    required List<BrushDab> sourceDabs,
    CacheInvalidationSink? cacheInvalidationSink,
    Uint8List? prerasterizedStrokePixels,
    DirtyRegion? prerasterizedStrokeBounds,
  }) {
    if (sourceDabs.isEmpty) {
      throw ArgumentError.value(sourceDabs, 'sourceDabs', 'must not be empty');
    }

    final result =
        commitBrushDabSequenceToBrushEditSessionWithCacheInvalidation(
          sessionState: activeSessionState,
          sequence: BrushDabSequence(sourceDabs),
          layerId: _activeFrameKey.layerId,
          frameId: _activeFrameKey.frameId,
          cacheInvalidationSink:
              cacheInvalidationSink ?? _NoopCacheInvalidationSink(),
          prerasterizedStrokePixels: prerasterizedStrokePixels,
          prerasterizedStrokeBounds: prerasterizedStrokeBounds,
        );
    // Bitmap undo snapshots are byte- AND count-budgeted: the deepest
    // entries drop first (their undos fall back to the command replay), so
    // a run of huge strokes can never pin gigabytes of touched tiles — and
    // a run of SMALL strokes can never pile snapshots past the unified
    // history's reach (userUndoLimit), which used to fill the whole byte
    // budget with unreachable entries.
    final budgetedHistory = trimMaterializationHistoryToByteBudget(
      result.sessionState.materializationHistoryState,
      maxBytes: historyPolicy.materializationByteBudget,
      maxEntries: historyPolicy.userUndoLimit,
    );
    final committedState =
        identical(
          budgetedHistory,
          result.sessionState.materializationHistoryState,
        )
        ? result.sessionState
        : result.sessionState.copyWith(
            materializationHistoryState: budgetedHistory,
          );
    sessionStore.update(_activeFrameKey, committedState);
    final affectedEntry = result.affectedEntry;
    if (affectedEntry == null) {
      return null;
    }

    final sequenceNumber = _nextSequenceNumber++;
    final command = BrushPaintCommand(
      id: BrushPaintCommandId('brush-paint-$sequenceNumber'),
      sequenceNumber: sequenceNumber,
      kind: BrushPaintCommandKind.paintStroke,
      debugLabel: 'Paint stroke $sequenceNumber',
      sourceDabs: List<BrushDab>.unmodifiable(sourceDabs),
      materializationRef: _materializationRefFor(
        frameKey: _activeFrameKey,
        sequenceNumber: sequenceNumber,
        entry: affectedEntry,
      ),
    );
    frameStore.addLivePaintCommand(
      _activeFrameKey,
      command,
      dirtyTiles: affectedEntry.dirtyTiles,
    );
    // Keep the display cache fresh across the commit (donation replaces the
    // dirty-then-replay cycle); derived ui.Image caches still re-upload via
    // the invalidation sink below.
    _donateSessionSurfaceToDisplayCache(_activeFrameKey, committedState);
    _invalidateBrushFrame(
      cacheInvalidationSink,
      _activeFrameKey,
      dirtyTiles: affectedEntry.dirtyTiles,
    );
    _pushBrushPaintUndoEntry(command, _activeFrameKey);
    return command;
  }

  /// Rewrites the given commands' dabs in place on the ACTIVE frame (P9
  /// selection move/transform) and rebuilds the session from the command
  /// replay — the same fallback path undo uses, so what displays equals
  /// what every composite route replays, by construction.
  ///
  /// The bitmap materialization history resets with the rebuild (an
  /// arbitrary rewrite has no incremental entry): undo of OLDER strokes
  /// falls back to the replay path, exactly like after a canvas resize.
  /// This operation itself creates no coordinator undo entry — the
  /// app-level BrushSelectionTransformHistoryCommand owns before/after.
  void rewritePaintCommandDabs(
    Map<BrushPaintCommandId, List<BrushDab>> dabsById, {
    BrushFrameKey? frameKey,
    CacheInvalidationSink? cacheInvalidationSink,
  }) {
    if (dabsById.isEmpty) {
      return;
    }
    // Undo/redo may fire after the playhead moved on: the command targets
    // the frame it was recorded on, not whatever is active now.
    final key = frameKey ?? _activeFrameKey;
    frameStore.replacePaintCommandDabs(key, dabsById);
    _rebuildSessionFromCommands(key);
    _invalidateBrushFrame(cacheInvalidationSink, key);
  }

  UndoHistoryEntry? undo({CacheInvalidationSink? cacheInvalidationSink}) {
    final take = _undoHistory.takeUndo();
    _undoHistory = take.history;
    final entry = take.entry;
    if (entry == null ||
        !entry.isPaintPayload ||
        entry.payloadRef.targetKey == null) {
      return entry;
    }
    final key = entry.payloadRef.targetKey!;
    final state = _sessionFor(key);
    if (state.canUndo) {
      final result =
          undoLatestBrushBitmapMaterializationInSessionStateWithCacheInvalidation(
            sessionState: state,
            cacheInvalidationSink:
                cacheInvalidationSink ?? _NoopCacheInvalidationSink(),
          );
      sessionStore.update(key, result.sessionState);
      frameStore.markPaintCommandHiddenByUndo(
        key,
        entry.payloadRef.paintCommandId,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
      _donateSessionSurfaceToDisplayCache(key, result.sessionState);
      _invalidateBrushFrame(
        cacheInvalidationSink,
        key,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
    } else {
      // The bitmap materialization history no longer covers this entry (it is
      // reset by a canvas resize), so revert the bitmap by replaying the
      // remaining visible commands instead.
      frameStore.markPaintCommandHiddenByUndo(
        key,
        entry.payloadRef.paintCommandId,
      );
      _rebuildSessionFromCommands(key);
      _invalidateBrushFrame(cacheInvalidationSink, key);
    }
    return entry;
  }

  UndoHistoryEntry? redo({CacheInvalidationSink? cacheInvalidationSink}) {
    final take = _undoHistory.takeRedo();
    _undoHistory = take.history;
    final entry = take.entry;
    if (entry == null ||
        !entry.isPaintPayload ||
        entry.payloadRef.targetKey == null) {
      return entry;
    }
    final key = entry.payloadRef.targetKey!;
    final state = _sessionFor(key);
    if (state.canRedo) {
      final result =
          redoLatestBrushBitmapMaterializationInSessionStateWithCacheInvalidation(
            sessionState: state,
            cacheInvalidationSink:
                cacheInvalidationSink ?? _NoopCacheInvalidationSink(),
          );
      sessionStore.update(key, result.sessionState);
      frameStore.restorePaintCommandFromUndo(
        key,
        entry.payloadRef.paintCommandId,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
      _donateSessionSurfaceToDisplayCache(key, result.sessionState);
      _invalidateBrushFrame(
        cacheInvalidationSink,
        key,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
    } else {
      // Same fallback as undo: replay visible commands when the bitmap
      // materialization history cannot restore this entry.
      frameStore.restorePaintCommandFromUndo(
        key,
        entry.payloadRef.paintCommandId,
      );
      _rebuildSessionFromCommands(key);
      _invalidateBrushFrame(cacheInvalidationSink, key);
    }
    return entry;
  }

  void _pushBrushPaintUndoEntry(
    BrushPaintCommand command,
    BrushFrameKey frameKey,
  ) {
    final entry = UndoHistoryEntry(
      id: UndoHistoryEntryId('undo-${command.id.value}'),
      sequenceNumber: command.sequenceNumber,
      kind: UndoHistoryEntryKind.paintStroke,
      scope: UndoHistoryScope.brushFrame,
      payloadRef: UndoPayloadRef.paintCommand(
        frameKey: frameKey,
        paintCommandId: command.id,
      ),
    );
    final pushResult = _undoHistory.pushNewEntry(entry);
    _undoHistory = pushResult.history;
    for (final trimmed in pushResult.trimmedEntries) {
      if (trimmed.isPaintPayload && trimmed.payloadRef.targetKey != null) {
        frameStore.movePaintCommandToDeferredBake(
          trimmed.payloadRef.targetKey!,
          trimmed.payloadRef.paintCommandId,
        );
      }
    }
  }

  void _invalidateBrushFrame(
    CacheInvalidationSink? sink,
    BrushFrameKey key, {
    DirtyTileSet? dirtyTiles,
  }) {
    (sink ?? _NoopCacheInvalidationSink()).invalidateBrushFrame(
      BrushFrameCacheInvalidation(
        frameKey: key,
        dirtyTiles: dirtyTiles,
        wholeFrame: dirtyTiles == null || dirtyTiles.isEmpty,
      ),
    );
  }

  String _materializationRefFor({
    required BrushFrameKey frameKey,
    required int sequenceNumber,
    required BrushBitmapMaterializationHistoryEntry entry,
  }) {
    return [
      'brush-materialization',
      frameKey.projectId.value,
      frameKey.trackId.value,
      frameKey.cutId.value,
      frameKey.layerId.value,
      frameKey.frameId.value,
      'seq-$sequenceNumber',
      'entry-layer-${entry.layerId.value}',
      'entry-frame-${entry.frameId.value}',
      'dirty-tiles-${entry.changedTileCount}',
    ].join('/');
  }

  int liveCommandCount(BrushFrameKey key) => frameStore
      .getOrCreateFrame(key)
      .paintCommands
      .where((command) => command.state == BrushPaintCommandState.live)
      .length;
}

class _NoopCacheInvalidationSink implements CacheInvalidationSink {
  @override
  void invalidateBrushFrame(BrushFrameCacheInvalidation invalidation) {}

  @override
  void invalidateFrameComposite(key) {}
  @override
  void invalidateLayerTile(key) {}
  @override
  void invalidatePlaybackPreview(key) {}
}
