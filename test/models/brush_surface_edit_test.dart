import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_commit_result.dart';
import 'package:quick_animaker_v2/src/models/brush_surface_edit.dart';
import 'package:quick_animaker_v2/src/models/cache_invalidation_plan.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/tile_delta.dart';
import 'package:quick_animaker_v2/src/models/tile_delta_command.dart';

void main() {
  group('BrushSurfaceEdit', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    BitmapSurface surface({Map<TileCoord, BitmapTile> tiles = const {}}) {
      return BitmapSurface(
        canvasSize: const CanvasSize(width: 4, height: 4),
        tileSize: 2,
        tiles: tiles,
      );
    }

    BitmapTile tile({required int firstByte}) {
      return BitmapTile(
        coord: const TileCoord(x: 0, y: 0),
        size: 2,
        pixels: Uint8List(2 * 2 * BitmapTile.bytesPerPixel)..[0] = firstByte,
      );
    }

    BrushCommitResult changedResult(BitmapTile afterTile) {
      final command = TileDeltaCommand(deltas: [TileDelta.created(afterTile)]);
      return BrushCommitResult.changed(
        command: command,
        cacheInvalidationPlan: CacheInvalidationPlan.fromTileDeltaCommand(
          layerId: layerId,
          frameId: frameId,
          command: command,
        ),
      );
    }

    test('stores beforeSurface, afterSurface, and commitResult', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final after = surface(tiles: {afterTile.coord: afterTile});
      final commitResult = changedResult(afterTile);

      final edit = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: commitResult,
      );

      expect(edit.beforeSurface, before);
      expect(edit.afterSurface, after);
      expect(edit.commitResult, commitResult);
    });

    test('hasChanges delegates to commitResult.hasChanges', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final edit = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: surface(tiles: {afterTile.coord: afterTile}),
        commitResult: changedResult(afterTile),
      );

      expect(edit.hasChanges, edit.commitResult.hasChanges);
    });

    test('isNoOp delegates to commitResult.isNoOp', () {
      final original = surface();
      final edit = BrushSurfaceEdit(
        beforeSurface: original,
        afterSurface: original,
        commitResult: BrushCommitResult.noOp(),
      );

      expect(edit.isNoOp, edit.commitResult.isNoOp);
    });

    test('effectiveSurface returns afterSurface', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final after = surface(tiles: {afterTile.coord: afterTile});

      final edit = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: changedResult(afterTile),
      );

      expect(edit.effectiveSurface, after);
      expect(identical(edit.effectiveSurface, edit.afterSurface), isTrue);
    });

    test('constructor accepts no-op edit when beforeSurface equals afterSurface', () {
      final original = surface();

      expect(
        () => BrushSurfaceEdit(
          beforeSurface: original,
          afterSurface: original.copyWith(),
          commitResult: BrushCommitResult.noOp(),
        ),
        returnsNormally,
      );
    });

    test('constructor rejects no-op edit when beforeSurface differs from afterSurface', () {
      final afterTile = tile(firstByte: 1);

      expect(
        () => BrushSurfaceEdit(
          beforeSurface: surface(),
          afterSurface: surface(tiles: {afterTile.coord: afterTile}),
          commitResult: BrushCommitResult.noOp(),
        ),
        throwsArgumentError,
      );
    });

    test('constructor accepts changed edit', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);

      expect(
        () => BrushSurfaceEdit(
          beforeSurface: before,
          afterSurface: surface(tiles: {afterTile.coord: afterTile}),
          commitResult: changedResult(afterTile),
        ),
        returnsNormally,
      );
    });

    test('copyWith preserves existing values when omitted', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final edit = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: surface(tiles: {afterTile.coord: afterTile}),
        commitResult: changedResult(afterTile),
      );

      expect(edit.copyWith(), edit);
    });

    test('copyWith updates fields', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final edit = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: surface(tiles: {afterTile.coord: afterTile}),
        commitResult: changedResult(afterTile),
      );
      final sameSurface = surface();

      final updated = edit.copyWith(
        beforeSurface: sameSurface,
        afterSurface: sameSurface,
        commitResult: BrushCommitResult.noOp(),
      );

      expect(updated.beforeSurface, sameSurface);
      expect(updated.afterSurface, sameSurface);
      expect(updated.commitResult, BrushCommitResult.noOp());
    });

    test('equality compares beforeSurface, afterSurface, and commitResult', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final after = surface(tiles: {afterTile.coord: afterTile});
      final commitResult = changedResult(afterTile);

      final first = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: commitResult,
      );
      final second = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: commitResult,
      );
      final different = BrushSurfaceEdit(
        beforeSurface: after,
        afterSurface: after,
        commitResult: commitResult,
      );

      expect(first, second);
      expect(first, isNot(different));
    });

    test('hashCode matches equality', () {
      final before = surface();
      final afterTile = tile(firstByte: 1);
      final after = surface(tiles: {afterTile.coord: afterTile});
      final commitResult = changedResult(afterTile);

      final first = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: commitResult,
      );
      final second = BrushSurfaceEdit(
        beforeSurface: before,
        afterSurface: after,
        commitResult: commitResult,
      );

      expect(first.hashCode, second.hashCode);
    });

    test('toString contains useful class name', () {
      final original = surface();
      final edit = BrushSurfaceEdit(
        beforeSurface: original,
        afterSurface: original,
        commitResult: BrushCommitResult.noOp(),
      );

      expect(edit.toString(), contains('BrushSurfaceEdit'));
    });
  });
}
