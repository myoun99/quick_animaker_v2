import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_state.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry_id.dart';
import 'package:quick_animaker_v2/src/models/undo_history_entry_kind.dart';
import 'package:quick_animaker_v2/src/models/undo_payload_ref.dart';
import 'package:quick_animaker_v2/src/models/unified_undo_history.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';

void main() {
  BrushFrameKey key({
    String project = 'p',
    String track = 't',
    String cut = 'c',
    String layer = 'l',
    String frame = 'f',
  }) => BrushFrameKey(
    projectId: ProjectId(project),
    trackId: TrackId(track),
    cutId: CutId(cut),
    layerId: LayerId(layer),
    frameId: FrameId(frame),
  );

  BrushPaintCommand command(int sequence) => BrushPaintCommand(
    id: BrushPaintCommandId('paint-$sequence'),
    sequenceNumber: sequence,
    kind: BrushPaintCommandKind.paintStroke,
    materializationRef: 'brush-materialization/session-only/$sequence',
  );

  UndoHistoryEntry paintEntry(BrushFrameKey frameKey, int sequence) =>
      UndoHistoryEntry(
        id: UndoHistoryEntryId('entry-$sequence'),
        sequenceNumber: sequence,
        kind: UndoHistoryEntryKind.paintStroke,
        scope: UndoHistoryScope.brushFrame,
        payloadRef: UndoPayloadRef.paintCommand(
          frameKey: frameKey,
          paintCommandId: BrushPaintCommandId('paint-$sequence'),
        ),
      );

  test(
    'paint undo payload ref resolves through BrushFrameStore to command payload',
    () {
      final store = BrushFrameStore();
      final frameKey = key();
      final added = command(1);
      store.addLivePaintCommand(frameKey, added);
      final entry = paintEntry(frameKey, 1);

      expect(entry.payloadRef.isPaintCommand, isTrue);
      expect(entry.payloadRef.storeName, UndoPayloadRef.paintStoreName);
      expect(entry.payloadRef.paintCommandId, added.id);

      final resolved = store.paintCommandForUndoPayload(entry.payloadRef);

      expect(resolved, isNotNull);
      expect(resolved!.id, added.id);
      expect(resolved.materializationRef, added.materializationRef);
      expect(resolved.state, BrushPaintCommandState.live);
    },
  );

  test(
    'non-paint undo payload ref does not resolve through brush frame store',
    () {
      final store = BrushFrameStore();
      final frameKey = key();
      store.addLivePaintCommand(frameKey, command(1));

      final resolved = store.paintCommandForUndoPayload(
        const UndoPayloadRef(
          storeName: 'brushBitmapMaterializationHistoryState',
          payloadId: 'entry-1',
          targetPath: 'internal/session-local',
        ),
      );

      expect(resolved, isNull);
    },
  );

  test(
    'trimmed paint entry moves to deferred bake and leaves kept entries undoable',
    () {
      final store = BrushFrameStore();
      final frameKey = key();
      var history = UnifiedUndoHistory(userUndoLimit: 3);

      for (var i = 1; i <= 4; i += 1) {
        store.addLivePaintCommand(frameKey, command(i));
        final result = history.pushNewEntry(paintEntry(frameKey, i));
        history = result.history;
        for (final trimmed in result.trimmedEntries.where(
          (entry) => entry.isPaintPayload,
        )) {
          store.movePaintCommandToDeferredBake(
            trimmed.payloadRef.targetKey!,
            trimmed.payloadRef.paintCommandId,
          );
        }
      }

      final state = store.getOrCreateFrame(frameKey);
      expect(
        state.commandById(BrushPaintCommandId('paint-1'))!.state,
        BrushPaintCommandState.deferredBake,
      );
      expect(state.livePaintCommands.map((item) => item.id.value), [
        'paint-2',
        'paint-3',
        'paint-4',
      ]);
      expect(state.visibleActivePaintCommands.map((item) => item.id.value), [
        'paint-1',
        'paint-2',
        'paint-3',
        'paint-4',
      ]);
      expect(
        history.undoStack.map((item) => item.payloadRef.payloadId),
        isNot(contains('paint-1')),
      );
    },
  );

  test('trimmed structural command is not deferred baked', () {
    final store = BrushFrameStore();
    final frameKey = key();
    store.addLivePaintCommand(frameKey, command(1));
    var history = UnifiedUndoHistory(userUndoLimit: 1);
    history = history
        .pushNewEntry(
          UndoHistoryEntry(
            id: UndoHistoryEntryId('structural'),
            sequenceNumber: 1,
            kind: UndoHistoryEntryKind.deleteLayer,
            scope: UndoHistoryScope.layer,
            payloadRef: UndoPayloadRef(
              storeName: 'layerStore',
              payloadId: 'delete-layer',
              targetPath: 'layer/l',
            ),
          ),
        )
        .history;
    final result = history.pushNewEntry(paintEntry(frameKey, 1));
    for (final trimmed in result.trimmedEntries.where(
      (entry) => entry.isPaintPayload,
    )) {
      store.movePaintCommandToDeferredBake(
        trimmed.payloadRef.targetKey!,
        trimmed.payloadRef.paintCommandId,
      );
    }

    expect(store.getOrCreateFrame(frameKey).deferredBakePaintCommands, isEmpty);
  });

  test('undo paint hides command without baking and redo restores it', () {
    final store = BrushFrameStore();
    final frameKey = key();
    store.addLivePaintCommand(frameKey, command(1));
    var history = UnifiedUndoHistory(
      userUndoLimit: 3,
    ).pushNewEntry(paintEntry(frameKey, 1)).history;

    final undo = history.takeUndo();
    history = undo.history;
    store.markPaintCommandHiddenByUndo(
      frameKey,
      undo.entry!.payloadRef.paintCommandId,
    );
    expect(
      store.getOrCreateFrame(frameKey).visibleActivePaintCommands,
      isEmpty,
    );
    expect(
      store.getOrCreateFrame(frameKey).hiddenCommandIds,
      contains(BrushPaintCommandId('paint-1')),
    );
    expect(store.getOrCreateFrame(frameKey).deferredBakePaintCommands, isEmpty);
    expect(store.getOrCreateFrame(frameKey).bakedPaintCommandIds, isEmpty);

    final redo = history.takeRedo();
    store.restorePaintCommandFromUndo(
      frameKey,
      redo.entry!.payloadRef.paintCommandId,
    );
    expect(
      store
          .getOrCreateFrame(frameKey)
          .visibleActivePaintCommands
          .map((item) => item.id.value),
      ['paint-1'],
    );
    expect(store.getOrCreateFrame(frameKey).hiddenCommandIds, isEmpty);
  });

  test('deferred commands stay visible when latest live command is undone', () {
    final store = BrushFrameStore();
    final frameKey = key();
    store.addLivePaintCommand(frameKey, command(1));
    store.addLivePaintCommand(frameKey, command(2));
    store.movePaintCommandToDeferredBake(
      frameKey,
      BrushPaintCommandId('paint-1'),
    );
    store.markPaintCommandHiddenByUndo(
      frameKey,
      BrushPaintCommandId('paint-2'),
    );

    final state = store.getOrCreateFrame(frameKey);
    expect(
      state.commandById(BrushPaintCommandId('paint-1'))!.state,
      BrushPaintCommandState.deferredBake,
    );
    expect(state.visibleActivePaintCommands.map((item) => item.id.value), [
      'paint-1',
    ]);
  });

  test(
    'flushFrame returns deferred commands without deleting live commands or changing undo order',
    () {
      final store = BrushFrameStore();
      final frameKey = key();
      store.addLivePaintCommand(frameKey, command(1));
      store.addLivePaintCommand(frameKey, command(2));
      store.movePaintCommandToDeferredBake(
        frameKey,
        BrushPaintCommandId('paint-1'),
      );
      final history = UnifiedUndoHistory(
        userUndoLimit: 3,
      ).pushNewEntry(paintEntry(frameKey, 2)).history;

      final flush = store.flushFrame(frameKey);

      expect(flush.deferredCommands.map((item) => item.id.value), ['paint-1']);
      expect(
        store
            .getOrCreateFrame(frameKey)
            .livePaintCommands
            .map((item) => item.id.value),
        ['paint-2'],
      );
      expect(history.undoStack.map((item) => item.payloadRef.payloadId), [
        'paint-2',
      ]);
    },
  );

  test('full-path BrushFrameKey isolates states sharing the same frame id', () {
    final store = BrushFrameStore();
    final first = key(project: 'p1', frame: 'same');
    final second = key(project: 'p2', frame: 'same');

    store.addLivePaintCommand(first, command(1));
    store.addLivePaintCommand(second, command(2));

    expect(
      store.getOrCreateFrame(first).livePaintCommands.single.id.value,
      'paint-1',
    );
    expect(
      store.getOrCreateFrame(second).livePaintCommands.single.id.value,
      'paint-2',
    );
  });
}
