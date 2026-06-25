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

void main() {
  group('BrushEditHistoryState', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BrushEditHistoryEntry entry({
      int tileX = 0,
      int tileY = 0,
      LayerId entryLayerId = layerId,
      FrameId entryFrameId = frameId,
    }) {
      final tile = BitmapTile.blank(
        coord: TileCoord(x: tileX, y: tileY),
        size: 2,
      );
      final command = TileDeltaCommand(deltas: [TileDelta.created(tile)]);
      return BrushEditHistoryEntry(
        layerId: entryLayerId,
        frameId: entryFrameId,
        commitResult: BrushCommitResult.changed(
          command: command,
          cacheInvalidationPlan: CacheInvalidationPlan.fromTileDeltaCommand(
            layerId: entryLayerId,
            frameId: entryFrameId,
            command: command,
          ),
        ),
      );
    }

    test('initial state has empty undoEntries and redoEntries', () {
      final state = BrushEditHistoryState();

      expect(state.undoEntries, isEmpty);
      expect(state.redoEntries, isEmpty);
    });

    test('stores undoEntries and redoEntries', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final state = BrushEditHistoryState(
        undoEntries: [undoEntry],
        redoEntries: [redoEntry],
      );

      expect(state.undoEntries, [undoEntry]);
      expect(state.redoEntries, [redoEntry]);
    });

    test('defensively copies constructor lists', () {
      final undoEntry = entry(tileX: 0);
      final redoEntry = entry(tileX: 1);
      final undoEntries = [undoEntry];
      final redoEntries = [redoEntry];
      final state = BrushEditHistoryState(
        undoEntries: undoEntries,
        redoEntries: redoEntries,
      );

      undoEntries.add(entry(tileX: 2));
      redoEntries.clear();

      expect(state.undoEntries, [undoEntry]);
      expect(state.redoEntries, [redoEntry]);
    });

    test('exposes unmodifiable undoEntries', () {
      final state = BrushEditHistoryState(undoEntries: [entry(tileX: 0)]);

      expect(
        () => state.undoEntries.add(entry(tileX: 1)),
        throwsUnsupportedError,
      );
    });

    test('exposes unmodifiable redoEntries', () {
      final state = BrushEditHistoryState(redoEntries: [entry(tileX: 0)]);

      expect(
        () => state.redoEntries.add(entry(tileX: 1)),
        throwsUnsupportedError,
      );
    });

    test('canUndo is false when undoEntries is empty', () {
      expect(BrushEditHistoryState().canUndo, isFalse);
    });

    test('canUndo is true when undoEntries is non-empty', () {
      expect(BrushEditHistoryState(undoEntries: [entry()]).canUndo, isTrue);
    });

    test('canRedo is false when redoEntries is empty', () {
      expect(BrushEditHistoryState().canRedo, isFalse);
    });

    test('canRedo is true when redoEntries is non-empty', () {
      expect(BrushEditHistoryState(redoEntries: [entry()]).canRedo, isTrue);
    });

    test('isEmpty is true only when both stacks are empty', () {
      expect(BrushEditHistoryState().isEmpty, isTrue);
      expect(
        BrushEditHistoryState(undoEntries: [entry(tileX: 0)]).isEmpty,
        isFalse,
      );
      expect(
        BrushEditHistoryState(redoEntries: [entry(tileX: 1)]).isEmpty,
        isFalse,
      );
      expect(
        BrushEditHistoryState(
          undoEntries: [entry(tileX: 0)],
          redoEntries: [entry(tileX: 1)],
        ).isEmpty,
        isFalse,
      );
    });

    test('undoCount returns undoEntries length', () {
      expect(
        BrushEditHistoryState(
          undoEntries: [entry(tileX: 0), entry(tileX: 1)],
        ).undoCount,
        2,
      );
    });

    test('redoCount returns redoEntries length', () {
      expect(
        BrushEditHistoryState(
          redoEntries: [entry(tileX: 0), entry(tileX: 1)],
        ).redoCount,
        2,
      );
    });

    test('latestUndoEntry returns null when undoEntries is empty', () {
      expect(BrushEditHistoryState().latestUndoEntry, isNull);
    });

    test('latestUndoEntry returns last undo entry', () {
      final first = entry(tileX: 0);
      final second = entry(tileX: 1);

      expect(
        BrushEditHistoryState(undoEntries: [first, second]).latestUndoEntry,
        second,
      );
    });

    test('latestRedoEntry returns null when redoEntries is empty', () {
      expect(BrushEditHistoryState().latestRedoEntry, isNull);
    });

    test('latestRedoEntry returns last redo entry', () {
      final first = entry(tileX: 0);
      final second = entry(tileX: 1);

      expect(
        BrushEditHistoryState(redoEntries: [first, second]).latestRedoEntry,
        second,
      );
    });

    test('copyWith preserves omitted values', () {
      final state = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      );

      expect(state.copyWith(), state);
    });

    test('copyWith updates undoEntries', () {
      final replacement = entry(tileX: 2);
      final state = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      ).copyWith(undoEntries: [replacement]);

      expect(state.undoEntries, [replacement]);
      expect(state.redoEntries, [entry(tileX: 1)]);
    });

    test('copyWith updates redoEntries', () {
      final replacement = entry(tileX: 2);
      final state = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      ).copyWith(redoEntries: [replacement]);

      expect(state.undoEntries, [entry(tileX: 0)]);
      expect(state.redoEntries, [replacement]);
    });

    test('equality uses element-wise list equality', () {
      expect(
        BrushEditHistoryState(
          undoEntries: [entry(tileX: 0), entry(tileX: 1)],
          redoEntries: [entry(tileX: 2)],
        ),
        BrushEditHistoryState(
          undoEntries: [entry(tileX: 0), entry(tileX: 1)],
          redoEntries: [entry(tileX: 2)],
        ),
      );
      expect(
        BrushEditHistoryState(
          undoEntries: [entry(tileX: 1), entry(tileX: 0)],
        ),
        isNot(
          BrushEditHistoryState(
            undoEntries: [entry(tileX: 0), entry(tileX: 1)],
          ),
        ),
      );
    });

    test('hashCode matches equality', () {
      final a = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      );
      final b = BrushEditHistoryState(
        undoEntries: [entry(tileX: 0)],
        redoEntries: [entry(tileX: 1)],
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('toString contains useful class name', () {
      expect(
        BrushEditHistoryState().toString(),
        contains('BrushEditHistoryState'),
      );
    });

    test('does not store BitmapSurface', () {
      final text = BrushEditHistoryState(undoEntries: [entry()]).toString();

      expect(text, isNot(contains('BitmapSurface')));
      expect(text, isNot(contains('beforeSurface')));
      expect(text, isNot(contains('afterSurface')));
    });
  });
}
