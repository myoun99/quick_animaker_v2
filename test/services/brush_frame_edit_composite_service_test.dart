import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command.dart';
import 'package:quick_animaker_v2/src/models/brush_paint_command_id.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_edit_composite_service.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/brush_pixel_grid_rasterizer.dart';

void main() {
  group('BrushFrameEditCompositeService', () {
    test('stroke commit appends to existing composite and rasterizes once', () {
      final store = BrushFrameStore();
      final rasterizer = _CountingRasterizer();
      final service = BrushFrameEditCompositeService(
        frameStore: store,
        canvasSize: CanvasSize(width: 16, height: 16),
        tileSize: 4,
        rasterizer: rasterizer,
      );
      final key = _key();
      service.ensureComposite(key);
      final command = _command('a', sequence: 1, x: 2, y: 2);

      store.addLivePaintCommand(key, command);
      final beforeRebuilds = rasterizer.commandRasterizeCount;
      final composite = service.updateAfterCommandCommit(
        key: key,
        command: command,
      );

      expect(rasterizer.commandRasterizeCount - beforeRebuilds, 1);
      expect(composite.compositeSurface.tiles, isNotEmpty);
      expect(
        store.commandRasterCacheOrNull(key)!.entryFor(command.id),
        isNotNull,
      );
      expect(store.editCompositeOrNull(key), same(composite));
    });

    test('rebuildComposite reuses command raster cache entries', () {
      final store = BrushFrameStore();
      final rasterizer = _CountingRasterizer();
      final service = BrushFrameEditCompositeService(
        frameStore: store,
        canvasSize: CanvasSize(width: 16, height: 16),
        tileSize: 4,
        rasterizer: rasterizer,
      );
      final key = _key();
      final first = _command('a', sequence: 1, x: 2, y: 2);
      final second = _command('b', sequence: 2, x: 6, y: 2);
      store.addLivePaintCommand(key, first);
      store.addLivePaintCommand(key, second);

      service.rebuildComposite(key);
      expect(rasterizer.commandRasterizeCount, 2);

      service.rebuildComposite(key);
      expect(rasterizer.commandRasterizeCount, 2);
    });

    test(
      'undo and redo stale composite is recomposed from visible commands',
      () {
        final store = BrushFrameStore();
        final service = BrushFrameEditCompositeService(
          frameStore: store,
          canvasSize: CanvasSize(width: 16, height: 16),
          tileSize: 4,
        );
        final key = _key();
        final command = _command('a', sequence: 1, x: 2, y: 2);
        store.addLivePaintCommand(key, command);
        final visibleComposite = service.rebuildComposite(key);
        expect(visibleComposite.compositeSurface.tiles, isNotEmpty);

        store.markPaintCommandHiddenByUndo(key, command.id);
        expect(
          store
              .editCompositeOrNull(key)!
              .isValidForRevision(store.getOrCreateFrame(key).sourceRevision),
          isFalse,
        );
        final hiddenComposite = service.ensureComposite(key);
        expect(hiddenComposite.compositeSurface.tiles, isEmpty);

        store.restorePaintCommandFromUndo(key, command.id);
        final restoredComposite = service.ensureComposite(key);
        expect(restoredComposite.compositeSurface.tiles, isNotEmpty);
      },
    );
  });
}

class _CountingRasterizer extends BrushPixelGridRasterizer {
  var commandRasterizeCount = 0;

  @override
  BrushSurfaceMaterialization rasterizeCommand({
    required BitmapSurface baseSurface,
    required BrushPaintCommand command,
  }) {
    commandRasterizeCount += 1;
    return super.rasterizeCommand(baseSurface: baseSurface, command: command);
  }
}

BrushFrameKey _key() => BrushFrameKey(
  projectId: ProjectId('p'),
  trackId: TrackId('t'),
  cutId: CutId('c'),
  layerId: LayerId('l'),
  frameId: FrameId('f'),
);

BrushPaintCommand _command(
  String id, {
  required int sequence,
  required double x,
  required double y,
}) {
  return BrushPaintCommand(
    id: BrushPaintCommandId(id),
    sequenceNumber: sequence,
    kind: BrushPaintCommandKind.paintStroke,
    sourceDabs: [
      BrushDab(
        center: CanvasPoint(x: x, y: y),
        color: 0xFF000000,
        size: 2,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: sequence,
      ),
    ],
  );
}
