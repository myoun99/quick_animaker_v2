import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_history_stack.dart';

void main() {
  group('brush edit history stack services', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BrushEditHistoryEntry entry({int tileX = 0, int tileY = 0}) {
      final tile = BitmapTile.blank(
        coord: TileCoord(x: tileX, y: tileY),
        size: 2,
      );
      final command = TileDeltaCommand(deltas: [TileDelta.created(tile)]);
      return BrushEditHistoryEntry(
        layerId: layerId,
        frameId: frameId,
        commitResult: BrushCommitResult.changed(
          command: command,
          cacheInvalidationPlan: CacheInvalidationPlan.fromTileDeltaCommand(
            layerId: layerId,
            frameId: frameId,
            command: command,
          ),
        ),
      );
    }

    test('pushBrushEditHistoryEntry appends entry to undoEntries', () {
      final newEntry = entry(tileX: 0);
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(),
        entry: newEntry,
      );

      expect(next.undoEntries, [newEntry]);
    });

    test('pushBrushEditHistoryEntry clears redoEntries', () {
      final redoEntry = entry(tileX: 1);
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(redoEntries: [redoEntry]),
        entry: entry(tileX: 0),
      );

      expect(next.redoEntries, isEmpty);
    });

    test('pushBrushEditHistoryEntry returns new state', () {
      final history = BrushEditHistoryState();
      final next = pushBrushEditHistoryEntry(
        history: history,
        entry: entry(tileX: 0),
      );

      expect(identical(next, history), isFalse);
    });

    test('pushBrushEditHistoryEntry does not mutate input history', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final history = BrushEditHistoryState(
        undoEntries: [undoEntry],
        redoEntries: [redoEntry],
      );

      pushBrushEditHistoryEntry(history: history, entry: entry(tileX: 2));

      expect(history.undoEntries, [undoEntry]);
      expect(history.redoEntries, [redoEntry]);
    });

    test('pushBrushEditHistoryEntry preserves existing undo order', () {
      final first = entry(tileX: 0);
      final second = entry(tileX: 1);
      final third = entry(tileX: 2);
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(undoEntries: [first, second]),
        entry: third,
      );

      expect(next.undoEntries, [first, second, third]);
    });

    test('pushBrushEditHistoryEntry puts new entry at latestUndoEntry', () {
      final newEntry = entry(tileX: 1);
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(undoEntries: [entry(tileX: 0)]),
        entry: newEntry,
      );

      expect(next.latestUndoEntry, newEntry);
    });

    test('clearBrushEditHistoryState clears undoEntries and redoEntries', () {
      final next = clearBrushEditHistoryState(
        history: BrushEditHistoryState(
          undoEntries: [entry(tileX: 0)],
          redoEntries: [entry(tileX: 1)],
        ),
      );

      expect(next.undoEntries, isEmpty);
      expect(next.redoEntries, isEmpty);
    });

    test('clearBrushEditHistoryState returns new empty state', () {
      final history = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      );
      final next = clearBrushEditHistoryState(history: history);

      expect(identical(next, history), isFalse);
      expect(next.isEmpty, isTrue);
    });

    test('clearBrushEditHistoryState does not mutate input history', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final history = BrushEditHistoryState(
        undoEntries: [undoEntry],
        redoEntries: [redoEntry],
      );

      clearBrushEditHistoryState(history: history);

      expect(history.undoEntries, [undoEntry]);
      expect(history.redoEntries, [redoEntry]);
    });

    test('clearRedoEntries clears only redoEntries', () {
      final next = clearRedoEntries(
        history: BrushEditHistoryState(
          undoEntries: [entry(tileX: 0)],
          redoEntries: [entry(tileX: 1)],
        ),
      );

      expect(next.redoEntries, isEmpty);
    });

    test('clearRedoEntries preserves undoEntries', () {
      final undoEntry = entry(tileX: 0);
      final next = clearRedoEntries(
        history: BrushEditHistoryState(
          undoEntries: [undoEntry],
          redoEntries: [entry(tileX: 1)],
        ),
      );

      expect(next.undoEntries, [undoEntry]);
    });

    test('clearRedoEntries does not mutate input history', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final history = BrushEditHistoryState(
        undoEntries: [undoEntry],
        redoEntries: [redoEntry],
      );

      clearRedoEntries(history: history);

      expect(history.undoEntries, [undoEntry]);
      expect(history.redoEntries, [redoEntry]);
    });

    test('services do not execute undo', () {
      final before = entry(tileX: 0);
      final after = entry(tileX: 1);
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(undoEntries: [before]),
        entry: after,
      );

      expect(next.undoEntries, [before, after]);
      expect(next.redoEntries, isEmpty);
    });

    test('services do not execute redo', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final next = clearRedoEntries(
        history: BrushEditHistoryState(
          undoEntries: [undoEntry],
          redoEntries: [redoEntry],
        ),
      );

      expect(next.undoEntries, [undoEntry]);
      expect(next.redoEntries, isEmpty);
    });

    test('services do not execute CacheInvalidationPlan', () {
      final undoEntry = entry(tileX: 0);
      final beforeKeyCount = undoEntry.cacheInvalidationPlan.totalKeyCount;

      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(),
        entry: undoEntry,
      );

      expect(
        next.latestUndoEntry!.cacheInvalidationPlan,
        undoEntry.cacheInvalidationPlan,
      );
      expect(
        next.latestUndoEntry!.cacheInvalidationPlan.totalKeyCount,
        beforeKeyCount,
      );
    });

    test('services do not mutate BrushEditHistoryEntry', () {
      final undoEntry = entry(tileX: 0);
      final beforeEntry = undoEntry.copyWith();

      pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(),
        entry: undoEntry,
      );

      expect(undoEntry, beforeEntry);
    });

    test('services do not add canvas UI behavior', () {
      final next = pushBrushEditHistoryEntry(
        history: BrushEditHistoryState(),
        entry: entry(tileX: 0),
      );

      expect(next.toString(), isNot(contains('Canvas')));
      expect(next.toString(), isNot(contains('Widget')));
    });
  });
}
