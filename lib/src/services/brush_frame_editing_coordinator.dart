import '../models/brush_edit_session_cache_operation_result.dart';
import '../models/brush_edit_session_operation_kind.dart';
import '../models/brush_edit_session_state.dart';
import '../models/brush_frame_key.dart';
import '../models/brush_history_policy.dart';
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
  BrushEditSessionState get activeSessionState =>
      sessionStore.getOrCreate(_activeFrameKey);

  void selectFrame(BrushFrameKey key) {
    frameStore.getOrCreateFrame(key);
    sessionStore.getOrCreate(key);
    _activeFrameKey = key;
  }

  BrushPaintCommand? applyBrushOperationResult(
    BrushEditSessionCacheOperationResult result,
  ) {
    final previousUndoCount = activeSessionState.materializationHistoryState.undoCount;
    sessionStore.update(_activeFrameKey, result.sessionState);
    if (result.kind != BrushEditSessionOperationKind.commit) {
      return null;
    }

    final nextUndoCount = result.sessionState.materializationHistoryState.undoCount;
    if (nextUndoCount <= previousUndoCount) {
      return null;
    }

    final command = BrushPaintCommand(
      id: BrushPaintCommandId('brush-paint-${_nextSequenceNumber++}'),
      sequenceNumber: _nextSequenceNumber - 1,
      kind: BrushPaintCommandKind.paintStroke,
      debugLabel: 'Paint stroke ${_nextSequenceNumber - 1}',
    );
    frameStore.addLivePaintCommand(_activeFrameKey, command);
    final entry = UndoHistoryEntry(
      id: UndoHistoryEntryId('undo-${command.id.value}'),
      sequenceNumber: command.sequenceNumber,
      kind: UndoHistoryEntryKind.paintStroke,
      scope: UndoHistoryScope.brushFrame,
      payloadRef: UndoPayloadRef.paintCommand(
        frameKey: _activeFrameKey,
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
    frameStore.markPaintCommandHiddenByUndo(
      key,
      entry.payloadRef.paintCommandId,
    );
    final state = sessionStore.getOrCreate(key);
    if (state.canUndo) {
      final result = undoLatestBrushBitmapMaterializationInSessionStateWithCacheInvalidation(
        sessionState: state,
        cacheInvalidationSink:
            cacheInvalidationSink ?? _NoopCacheInvalidationSink(),
      );
      sessionStore.update(key, result.sessionState);
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
    frameStore.restorePaintCommandFromUndo(
      key,
      entry.payloadRef.paintCommandId,
    );
    final state = sessionStore.getOrCreate(key);
    if (state.canRedo) {
      final result = redoLatestBrushBitmapMaterializationInSessionStateWithCacheInvalidation(
        sessionState: state,
        cacheInvalidationSink:
            cacheInvalidationSink ?? _NoopCacheInvalidationSink(),
      );
      sessionStore.update(key, result.sessionState);
    }
    return entry;
  }

  int liveCommandCount(BrushFrameKey key) => frameStore
      .getOrCreateFrame(key)
      .paintCommands
      .where((command) => command.state == BrushPaintCommandState.live)
      .length;
}

class _NoopCacheInvalidationSink implements CacheInvalidationSink {
  @override
  void invalidateFrameComposite(key) {}
  @override
  void invalidateLayerTile(key) {}
  @override
  void invalidatePlaybackPreview(key) {}
}
