import '../models/brush_bitmap_materialization_history_entry.dart';
import '../models/brush_dab.dart';
import '../models/brush_dab_sequence.dart';
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
import 'brush_edit_session_cache_operations.dart';
import 'brush_frame_edit_session_store.dart';
import 'brush_frame_store.dart';
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
  BrushEditSessionState get activeSessionState =>
      sessionStore.getOrCreate(_activeFrameKey);

  void selectFrame(BrushFrameKey key) {
    frameStore.getOrCreateFrame(key);
    sessionStore.getOrCreate(key);
    _activeFrameKey = key;
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
        );
    sessionStore.update(_activeFrameKey, result.sessionState);
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
    _invalidateBrushFrame(
      cacheInvalidationSink,
      _activeFrameKey,
      dirtyTiles: affectedEntry.dirtyTiles,
    );
    _pushBrushPaintUndoEntry(command, _activeFrameKey);
    return command;
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
    final state = sessionStore.getOrCreate(key);
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
      _invalidateBrushFrame(
        cacheInvalidationSink,
        key,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
    } else {
      frameStore.markPaintCommandHiddenByUndo(
        key,
        entry.payloadRef.paintCommandId,
      );
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
    final state = sessionStore.getOrCreate(key);
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
      _invalidateBrushFrame(
        cacheInvalidationSink,
        key,
        dirtyTiles: result.affectedEntry?.dirtyTiles,
      );
    } else {
      frameStore.restorePaintCommandFromUndo(
        key,
        entry.payloadRef.paintCommandId,
      );
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
