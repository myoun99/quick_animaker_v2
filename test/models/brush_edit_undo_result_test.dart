import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_undo_result.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('BrushEditUndoResult', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface() =>
        BitmapSurface(canvasSize: CanvasSize(width: 2, height: 2), tileSize: 2);

    BrushEditHistoryEntry entry({int firstByte = 1}) {
      final tile = BitmapTile(
        coord: TileCoord(x: 0, y: 0),
        size: 2,
        pixels: Uint8List(16)..[0] = firstByte,
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

    test('stores canvasState, historyState, undoneEntry', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final undoneEntry = entry();

      final result = BrushEditUndoResult(
        canvasState: canvasState,
        historyState: historyState,
        undoneEntry: undoneEntry,
      );

      expect(result.canvasState, canvasState);
      expect(result.historyState, historyState);
      expect(result.undoneEntry, undoneEntry);
    });

    test('didUndo false when undoneEntry is null', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: null,
      );

      expect(result.didUndo, isFalse);
    });

    test('didUndo true when undoneEntry is non-null', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: entry(),
      );

      expect(result.didUndo, isTrue);
    });

    test('copyWith preserves omitted values', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(undoEntries: [entry()]),
        undoneEntry: entry(firstByte: 2),
      );

      expect(result.copyWith(), result);
    });

    test('copyWith updates canvasState', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: null,
      );
      final canvasState = CanvasSurfaceState(currentSurface: surface());

      expect(
        result.copyWith(canvasState: canvasState).canvasState,
        canvasState,
      );
    });

    test('copyWith updates historyState', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: null,
      );
      final historyState = BrushEditHistoryState(undoEntries: [entry()]);

      expect(
        result.copyWith(historyState: historyState).historyState,
        historyState,
      );
    });

    test('copyWith can set undoneEntry', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: null,
      );
      final undoneEntry = entry();

      expect(
        result.copyWith(undoneEntry: undoneEntry).undoneEntry,
        undoneEntry,
      );
    });

    test('copyWith can clear undoneEntry with null', () {
      final result = BrushEditUndoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        undoneEntry: entry(),
      );

      expect(result.copyWith(undoneEntry: null).undoneEntry, isNull);
    });

    test('equality / hashCode / toString', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final undoneEntry = entry();
      final first = BrushEditUndoResult(
        canvasState: canvasState,
        historyState: historyState,
        undoneEntry: undoneEntry,
      );
      final second = BrushEditUndoResult(
        canvasState: canvasState,
        historyState: historyState,
        undoneEntry: undoneEntry,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('BrushEditUndoResult'));
      expect(first.toString(), contains('undoneEntry'));
    });
  });
}
