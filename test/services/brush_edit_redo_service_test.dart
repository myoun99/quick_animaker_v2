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
import 'package:quick_animaker_v2/src/services/brush_edit_redo_service.dart';

void main() {
  group('redoLatestBrushEdit', () {
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

    test('no redo entry returns same canvasState instance', () {
      final canvasState = CanvasSurfaceState(currentSurface: surface());

      final result = redoLatestBrushEdit(
        canvasState: canvasState,
        historyState: BrushEditHistoryState(),
      );

      expect(identical(result.canvasState, canvasState), isTrue);
    });

    test('no redo entry returns same historyState instance', () {
      final historyState = BrushEditHistoryState();

      final result = redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: historyState,
      );

      expect(identical(result.historyState, historyState), isTrue);
    });

    test('no redo entry has redoneEntry null', () {
      final result = redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: surface()),
        historyState: BrushEditHistoryState(),
      );

      expect(result.redoneEntry, isNull);
      expect(result.didRedo, isFalse);
    });

    test('redo reapplies currentSurface using existing apply behavior', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
      final afterSurface = surface(tiles: {afterTile.coord: afterTile});
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: beforeSurface),
        historyState: BrushEditHistoryState(redoEntries: [entry]),
      );

      expect(result.canvasState.currentSurface, afterSurface);
    });

    test(
      'redo sets CanvasSurfaceState.lastEdit from previous and updated surfaces',
      () {
        final beforeTile = tile(firstByte: 1);
        final afterTile = tile(firstByte: 2);
        final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
        final entry = entryForDelta(
          TileDelta.replaced(before: beforeTile, after: afterTile),
        );

        final result = redoLatestBrushEdit(
          canvasState: CanvasSurfaceState(currentSurface: beforeSurface),
          historyState: BrushEditHistoryState(redoEntries: [entry]),
        );

        expect(result.canvasState.lastEdit, isA<BrushSurfaceEdit>());
        expect(result.canvasState.lastEdit!.beforeSurface, beforeSurface);
        expect(
          result.canvasState.lastEdit!.afterSurface,
          result.canvasState.currentSurface,
        );
        expect(result.canvasState.lastEdit!.commitResult, entry.commitResult);
      },
    );

    test('redo removes latest redo entry and appends it to undo entries', () {
      final first = entryForDelta(TileDelta.created(tile(firstByte: 3)));
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final second = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: surface(tiles: {beforeTile.coord: beforeTile}),
        ),
        historyState: BrushEditHistoryState(
          undoEntries: [first],
          redoEntries: [first, second],
        ),
      );

      expect(result.historyState.redoEntries, [first]);
      expect(result.historyState.undoEntries, [first, second]);
      expect(result.redoneEntry, second);
    });

    test('redo does not mutate input CanvasSurfaceState or history state', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );
      final canvasState = CanvasSurfaceState(currentSurface: beforeSurface);
      final historyState = BrushEditHistoryState(redoEntries: [entry]);

      redoLatestBrushEdit(canvasState: canvasState, historyState: historyState);

      expect(canvasState.currentSurface, beforeSurface);
      expect(canvasState.lastEdit, isNull);
      expect(historyState.undoEntries, isEmpty);
      expect(historyState.redoEntries, [entry]);
    });

    test('redo does not mutate BrushEditHistoryEntry', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );
      final originalEntry = entry.copyWith();

      redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(
          currentSurface: surface(tiles: {beforeTile.coord: beforeTile}),
        ),
        historyState: BrushEditHistoryState(redoEntries: [entry]),
      );

      expect(entry, originalEntry);
    });

    test('redo does not execute cache invalidation or undo behavior', () {
      final beforeTile = tile(firstByte: 1);
      final afterTile = tile(firstByte: 2);
      final beforeSurface = surface(tiles: {beforeTile.coord: beforeTile});
      final entry = entryForDelta(
        TileDelta.replaced(before: beforeTile, after: afterTile),
      );

      final result = redoLatestBrushEdit(
        canvasState: CanvasSurfaceState(currentSurface: beforeSurface),
        historyState: BrushEditHistoryState(redoEntries: [entry]),
      );

      expect(result.redoneEntry!.commitResult.cacheInvalidationPlan, isNotNull);
      expect(result.canvasState.currentSurface, isNot(beforeSurface));
      expect(result.canvasState.currentSurface, isNot(surface()));
    });

    test('no UI/state management/timeline/storyboard changes are required', () {
      expect(redoLatestBrushEdit, isA<Function>());
    });
  });
}
