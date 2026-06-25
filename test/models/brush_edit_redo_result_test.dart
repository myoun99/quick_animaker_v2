import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_redo_result.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('BrushEditRedoResult', () {
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

    test('stores canvasState, historyState, redoneEntry', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final redoneEntry = entry();

      final result = BrushEditRedoResult(
        canvasState: canvasState,
        historyState: historyState,
        redoneEntry: redoneEntry,
      );

      expect(result.canvasState, canvasState);
      expect(result.historyState, historyState);
      expect(result.redoneEntry, redoneEntry);
    });

    test('didRedo false when redoneEntry is null', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: null,
      );

      expect(result.didRedo, isFalse);
    });

    test('didRedo true when redoneEntry is non-null', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: entry(),
      );

      expect(result.didRedo, isTrue);
    });

    test('copyWith preserves omitted values', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(redoEntries: [entry()]),
        redoneEntry: entry(firstByte: 2),
      );

      expect(result.copyWith(), result);
    });

    test('copyWith updates canvasState', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: null,
      );
      final canvasState = CanvasSurfaceState(currentSurface: surface());

      expect(
        result.copyWith(canvasState: canvasState).canvasState,
        canvasState,
      );
    });

    test('copyWith updates historyState', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: null,
      );
      final historyState = BrushEditHistoryState(redoEntries: [entry()]);

      expect(
        result.copyWith(historyState: historyState).historyState,
        historyState,
      );
    });

    test('copyWith can set redoneEntry', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: null,
      );
      final redoneEntry = entry();

      expect(
        result.copyWith(redoneEntry: redoneEntry).redoneEntry,
        redoneEntry,
      );
    });

    test('copyWith can clear redoneEntry with null', () {
      final result = BrushEditRedoResult(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
        redoneEntry: entry(),
      );

      expect(result.copyWith(redoneEntry: null).redoneEntry, isNull);
    });

    test('equality / hashCode / toString', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());
      final historyState = BrushEditHistoryState();
      final redoneEntry = entry();
      final first = BrushEditRedoResult(
        canvasState: canvasState,
        historyState: historyState,
        redoneEntry: redoneEntry,
      );
      final second = BrushEditRedoResult(
        canvasState: canvasState,
        historyState: historyState,
        redoneEntry: redoneEntry,
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toString(), contains('BrushEditRedoResult'));
      expect(first.toString(), contains('redoneEntry'));
    });
  });
}
