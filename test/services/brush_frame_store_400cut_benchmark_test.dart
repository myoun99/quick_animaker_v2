import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/persistence/brush_drawing_binary_codec.dart';
import 'package:quick_animaker_v2/src/services/persistence/qap_file_service.dart';

/// R20 verdict lab (400-cut scenario): the cold-cel tier must hold a
/// TV-scale project — 400 HD cels — with bounded RAM, archive-speed
/// opens (zero pixel decode) and pass-through saves. Prints measured
/// wall times; assertions pin the architecture, not the clock.
void main() {
  test(
    '400 HD cels: cold landing, spill, save pass-through, lazy open',
    () async {
      const cels = 400;
      const canvasSize = CanvasSize(width: 1920, height: 1080);
      final directory = await Directory.systemTemp.createTemp('qa-400cut');
      addTearDown(() => directory.delete(recursive: true));

      BrushFrameKey key(int i) => BrushFrameKey(
        projectId: const ProjectId('p'),
        trackId: const TrackId('t'),
        cutId: CutId('cut-${i ~/ 4}'),
        layerId: const LayerId('l'),
        frameId: FrameId('f$i'),
      );

      // One inked 256px tile per cel (sparse line art — the realistic cel).
      BitmapSurface inked(int seed) {
        final pixels = Uint8List(256 * 256 * 4);
        for (var i = 0; i < 4096; i += 1) {
          final at = ((i * 97 + seed) % (256 * 256)) * 4;
          pixels[at] = 20;
          pixels[at + 3] = 255;
        }
        return BitmapSurface(
          canvasSize: canvasSize,
          tileSize: 256,
          tiles: {
            TileCoord(x: 2, y: 2): BitmapTile(
              coord: TileCoord(x: 2, y: 2),
              size: 256,
              pixels: pixels,
            ),
          },
        );
      }

      final encodeWatch = Stopwatch()..start();
      final blobs = <BrushFrameKey, QapCelBlob>{
        for (var i = 0; i < cels; i += 1)
          key(i): QapCelBlob.encode(QapCelEntry.fromSurface(key(i), inked(i))),
      };
      encodeWatch.stop();
      var blobBytes = 0;
      for (final blob in blobs.values) {
        blobBytes += blob.bytes.length;
      }

      // COLD LANDING (the open path's store side): must be near-instant.
      final store = BrushFrameStore();
      final landWatch = Stopwatch()..start();
      store.restoreBaked(blobs);
      landWatch.stop();
      expect(store.coldCelKeys.length + store.scratchCelKeys.length, cels);
      expect(store.hotBakedBytes, 0, reason: 'no pixel decode on open');

      // SPILL: force the whole cold set to disk (theatrical-scale RAM cap).
      // Re-land under a zero budget — restoreBaked schedules the spill.
      store.coldCelByteBudget = 0;
      final spillWatch = Stopwatch()..start();
      store.restoreBaked(blobs);
      await store.drainTiering();
      spillWatch.stop();
      expect(store.scratchCelKeys.length, cels);

      // SAVE: spilled cels stream from disk inside the save isolate.
      final path = '${directory.path}/tv400.qap';
      final saveWatch = Stopwatch()..start();
      await const QapFileService().save(
        project: createDefaultProject(),
        brushFrameStore: store,
        filePath: path,
      );
      saveWatch.stop();
      final fileBytes = await File(path).length();

      // OPEN: archive parse only — cels come back cold.
      final openWatch = Stopwatch()..start();
      final result = await const QapFileService().open(filePath: path);
      openWatch.stop();
      expect(result.cels.length, cels);

      // First-access materialization stays per-cel cheap.
      final store2 = BrushFrameStore()..restoreBaked(result.cels);
      final touchWatch = Stopwatch()..start();
      final surface = store2.bakedSurfaceOrNull(key(7))!;
      touchWatch.stop();
      expect(surface.tiles.length, 1);

      // ignore: avoid_print
      print(
        'LAB400: cels=$cels encode=${encodeWatch.elapsedMilliseconds}ms '
        'blobBytes=${(blobBytes / 1024).round()}KB '
        'coldLand=${landWatch.elapsedMilliseconds}ms '
        'spillAll=${spillWatch.elapsedMilliseconds}ms '
        'save=${saveWatch.elapsedMilliseconds}ms '
        'file=${(fileBytes / 1024).round()}KB '
        'open=${openWatch.elapsedMilliseconds}ms '
        'firstTouch=${touchWatch.elapsedMicroseconds}us',
      );
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
