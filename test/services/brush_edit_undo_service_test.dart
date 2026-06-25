import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_entry.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_surface_edit.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';
import 'package:quick_animaker_v2/src/services/brush_edit_undo_service.dart';

void main() {
  group('undoLatestBrushEdit', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface({Map<TileCoord, BitmapTile> tiles = const {}}) {
      return BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
        tileSize: 2,
        tiles: tiles,
      );
    }

    BitmapTile tile({required int firstByte}) {
      return BitmapTile(
        coord: TileCoord(x: 0, y: 0),
        size: 2,
        pixels: Uint8List(16)..[0] = firstByte,
      );
    }

    BrushEditHistoryEntry entryForDelta(TileDelta delta) {
      final command = TileDeltaCommand(deltas: [delta]);
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

    test('no undo entry returns same canvasState instance', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());

      final result = undoLatestBrushEdit(
        canvasState: canvasState,
        historyState: BrushEditHistoryState(),
      );

      expect(identical(result.canvasState, canvasState), isTrue);
    });

    test('no undo entry returns same historyState instance', () {
      final historyState = BrushEditHistoryState();

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: historyState,
      );

      expect(identical(result.historyState, historyState), isTrue);
    });

    test('no undo entry has undoneEntry null', () {
      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
      );

      expect(result.undoneEntry, isNull);
      expect(result.didUndo, isFalse);
    });

    test('undo reverts currentSurface', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
      final afterSurface = surface(tiles: {afterTile.coord: afterTile});
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: afterSurface),
        historyState: BrushEditHistoryState(undoEntries: [entry]),
      );

      expect(result.canvasState.currentSurface, beforeSurface);
    });

    test('undo clears CanvasSurfaceState.lastEdit', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
      final afterSurface = surface(tiles: {afterTile.coord: afterTile});
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );
      final lastEdit = BrushSurfaceEdit(
        beforeSurface: beforeSurface,
        afterSurface: afterSurface,
        commitResult: entry.commitResult,
      );

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: afterSurface,
          lastEdit: lastEdit,
        ),
        historyState: BrushEditHistoryState(undoEntries: [entry]),
      );

      expect(result.canvasState.lastEdit, isNull);
    });

    test('undo removes latest entry from undoEntries', () {
      final first = entryForDelta(TileDelta.created(tile(firstByte: 1)));
      final secondBefore = tile(firstByte: 1);
      final secondAfter = tile(firstByte: 2);
      final second = entryForDelta(
        TileDelta.replaced(before: secondBefore, after: secondAfter),
      );

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: surface(tiles: {secondAfter.coord: secondAfter}),
        ),
        historyState: BrushEditHistoryState(undoEntries: [first, second]),
      );

      expect(result.historyState.undoEntries, [first]);
      expect(result.undoneEntry, second);
    });

    test('undo appends undone entry to redoEntries', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: surface(tiles: {afterTile.coord: afterTile}),
        ),
        historyState: BrushEditHistoryState(undoEntries: [entry]),
      );

      expect(result.historyState.redoEntries, [entry]);
    });

    test('undo preserves previous redo order', () {
      final redoEntry = entryForDelta(TileDelta.created(tile(firstByte: 3)));
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final undoEntry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = undoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: surface(tiles: {afterTile.coord: afterTile}),
        ),
        historyState: BrushEditHistoryState(
          undoEntries: [undoEntry],
          redoEntries: [redoEntry],
        ),
      );

      expect(result.historyState.redoEntries, [redoEntry, undoEntry]);
    });
  });
}
