import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
import 'package:quick_animaker_v2/src/controllers/default_project_helpers.dart';
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/persistence/brush_drawing_binary_codec.dart';
import 'package:quick_animaker_v2/src/services/persistence/qap_file_service.dart';

/// R20-A1 two-tier baked truth: cold cels are encoded+deflated blobs
/// (the same bytes the archive stores), materialize byte-exactly on
/// first access, and over-budget hot cels cool back down in LRU order.
/// Representation must never change existence or bytes.
void main() {
  const canvasSize = CanvasSize(width: 16, height: 16);

  BrushFrameKey key({String layer = 'l', String frame = 'f'}) => BrushFrameKey(
    projectId: const ProjectId('p'),
    trackId: const TrackId('t'),
    cutId: const CutId('c'),
    layerId: LayerId(layer),
    frameId: FrameId(frame),
  );

  BitmapSurface inkSurface({int seed = 1}) {
    final pixels = Uint8List(8 * 8 * 4);
    for (var i = 0; i < pixels.length; i += 1) {
      pixels[i] = (i * seed * 31 + seed) & 0xFF;
    }
    return BitmapSurface(
      canvasSize: canvasSize,
      tileSize: 8,
      tiles: {
        TileCoord(x: 0, y: 0): BitmapTile(
          coord: TileCoord(x: 0, y: 0),
          size: 8,
          pixels: pixels,
        ),
      },
    );
  }

  QapCelBlob blobOf(BrushFrameKey k, BitmapSurface surface) =>
      QapCelBlob.encode(QapCelEntry.fromSurface(k, surface));

  test('a restored (cold) cel counts as content, materializes byte-exactly '
      'on first access and promotes to hot', () {
    final store = BrushFrameStore();
    final k = key();
    final source = inkSurface();
    store.restoreBaked({k: blobOf(k, source)});

    expect(
      store.celHasRenderableContent(k),
      isTrue,
      reason: 'representation is not existence',
    );
    expect(store.isCelCold(k), isTrue);
    expect(store.hotBakedBytes, 0);

    final materialized = store.bakedSurfaceOrNull(k)!;
    expect(store.isCelCold(k), isFalse);
    expect(
      materialized.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      source.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      reason: 'cold → hot round trip is byte-exact',
    );
    expect(
      identical(store.bakedSurfaceOrNull(k), materialized),
      isTrue,
      reason: 'promotion is once — later reads hit the hot tier',
    );
    expect(
      identical(store.displayCacheOrNull(k)?.previewSurface, materialized),
      isTrue,
      reason: 'promotion reseeds the display cache like open used to',
    );
  });

  test('currentSurfaceWithoutReplay materializes a size-matched cold cel '
      'and rejects a mismatched one', () {
    final store = BrushFrameStore();
    final k = key();
    store.restoreBaked({k: blobOf(k, inkSurface())});

    expect(
      store.currentSurfaceWithoutReplay(
        k,
        canvasSize: const CanvasSize(width: 99, height: 99),
      ),
      isNull,
      reason: 'the cold header carries the size — no inflate to reject',
    );
    expect(store.isCelCold(k), isTrue, reason: 'rejection must not promote');

    expect(
      store.currentSurfaceWithoutReplay(k, canvasSize: canvasSize),
      isNotNull,
    );
    expect(store.isCelCold(k), isFalse);
  });

  test('over-budget hot cels COOL in LRU order; the most recent never '
      'cools; cooled bytes survive exactly', () async {
    final store = BrushFrameStore()..hotCelByteBudget = 0;
    final k1 = key(frame: 'f1');
    final k2 = key(frame: 'f2');
    final s1 = inkSurface(seed: 3);
    store.storeBakedSurface(k1, s1);
    store.storeBakedSurface(k2, inkSurface(seed: 5));
    await store.drainCooling();

    expect(store.isCelCold(k1), isTrue, reason: 'LRU victim cools first');
    expect(
      store.isCelCold(k2),
      isFalse,
      reason: 'the most recently used cel NEVER cools',
    );
    expect(
      store.displayCacheOrNull(k1),
      isNull,
      reason: 'the derived alias must drop or nothing frees',
    );
    expect(store.celHasRenderableContent(k1), isTrue);

    final back = store.bakedSurfaceOrNull(k1)!;
    expect(
      back.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      s1.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      reason: 'hot → cold → hot round trip is byte-exact',
    );
  });

  test(
    'a donation onto a cold key replaces it (hot wins, cold dropped)',
    () async {
      final store = BrushFrameStore();
      final k = key();
      store.restoreBaked({k: blobOf(k, inkSurface(seed: 7))});

      final donated = inkSurface(seed: 9);
      store.storeBakedSurface(k, donated);
      expect(store.isCelCold(k), isFalse);
      expect(identical(store.bakedSurfaceOrNull(k), donated), isTrue);
    },
  );

  test('bakedSnapshotForSave passes cold blobs through untouched — the '
      'save path re-encodes nothing for unedited cels', () {
    final store = BrushFrameStore();
    final k = key();
    final blob = blobOf(k, inkSurface());
    store.restoreBaked({k: blob});

    final snapshot = store.bakedSnapshotForSave();
    expect(identical(snapshot.cold[k], blob), isTrue);
    expect(snapshot.hot, isEmpty);
  });

  test('rekeyFrames moves a COLD cel with its key', () {
    final store = BrushFrameStore();
    final from = key(layer: 'a');
    final to = key(layer: 'b');
    store.restoreBaked({from: blobOf(from, inkSurface())});

    store.rekeyFrames([(from, to)]);

    expect(store.celHasRenderableContent(from), isFalse);
    expect(store.isCelCold(to), isTrue);
    expect(store.bakedSurfaceOrNull(to), isNotNull);
  });

  test('over-budget COLD blobs SPILL to scratch files and read back '
      'byte-exactly (R20-A2)', () async {
    final store = BrushFrameStore()..coldCelByteBudget = 0;
    final k1 = key(frame: 'f1');
    final k2 = key(frame: 'f2');
    final s1 = inkSurface(seed: 11);
    store.restoreBaked({k1: blobOf(k1, s1), k2: blobOf(k2, inkSurface())});
    await store.drainTiering();

    expect(store.isCelSpilled(k1), isTrue);
    expect(store.isCelSpilled(k2), isTrue);
    expect(store.coldBakedBytes, 0, reason: 'RAM holds nothing spilled');
    expect(store.celHasRenderableContent(k1), isTrue);
    expect(
      store.currentSurfaceWithoutReplay(
        k1,
        canvasSize: const CanvasSize(width: 99, height: 99),
      ),
      isNull,
      reason: 'the scratch ref carries the size — no disk read to reject',
    );
    expect(store.isCelSpilled(k1), isTrue);

    final back = store.bakedSurfaceOrNull(k1)!;
    expect(store.isCelSpilled(k1), isFalse, reason: 'read back promotes');
    expect(
      back.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      s1.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      reason: 'cold → disk → hot round trip is byte-exact',
    );
  });

  test('the full ladder: hot → cold → scratch under zero budgets, and '
      'save snapshot exposes every tier', () async {
    final store = BrushFrameStore()
      ..hotCelByteBudget = 0
      ..coldCelByteBudget = 0;
    final k1 = key(frame: 'f1');
    final k2 = key(frame: 'f2');
    store.storeBakedSurface(k1, inkSurface(seed: 2));
    store.storeBakedSurface(k2, inkSurface(seed: 4));
    await store.drainTiering();

    expect(
      store.isCelSpilled(k1),
      isTrue,
      reason: 'cooled blob immediately exceeds the zero cold budget',
    );
    expect(store.isCelCold(k1), isFalse);
    expect(
      store.isCelSpilled(k2),
      isFalse,
      reason: 'the most recent cel stays hot end to end',
    );

    final snapshot = store.bakedSnapshotForSave();
    expect(snapshot.hot.containsKey(k2), isTrue);
    expect(snapshot.scratch.containsKey(k1), isTrue);
  });

  test(
    'scratch file deletion DEFERS while locked (the save-read window)',
    () async {
      final store = BrushFrameStore()..coldCelByteBudget = 0;
      final k = key();
      final s = inkSurface(seed: 13);
      store.restoreBaked({k: blobOf(k, s)});
      await store.drainTiering();
      final ref = store.bakedSnapshotForSave().scratch[k]!;

      store.lockScratchFiles();
      // Materialization normally deletes the file — the lock must defer it.
      final surface = store.bakedSurfaceOrNull(k)!;
      expect(
        surface.tiles[TileCoord(x: 0, y: 0)]!.pixels,
        s.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      );
      expect(
        File(ref.filePath).existsSync(),
        isTrue,
        reason: 'a concurrent save may still be reading this file',
      );
      store.unlockScratchFiles();
      // Deletion is async best-effort after unlock; poll briefly.
      for (var i = 0; i < 50 && File(ref.filePath).existsSync(); i += 1) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(File(ref.filePath).existsSync(), isFalse);
    },
  );

  test('a SPILLED cel saves through the .qap byte-exactly (the save '
      'isolate reads the scratch file itself)', () async {
    final directory = await Directory.systemTemp.createTemp('qa-spill-save');
    addTearDown(() => directory.delete(recursive: true));
    final store = BrushFrameStore()..coldCelByteBudget = 0;
    final k = key();
    final s = inkSurface(seed: 17);
    store.restoreBaked({k: blobOf(k, s)});
    await store.drainTiering();
    expect(store.isCelSpilled(k), isTrue);

    final path = '${directory.path}/spill.qap';
    await const QapFileService().save(
      project: createDefaultProject(),
      brushFrameStore: store,
      filePath: path,
    );
    final result = await const QapFileService().open(filePath: path);

    expect(result.cels.keys, [k]);
    expect(
      result.cels[k]!.decode().toSurface().tiles[TileCoord(x: 0, y: 0)]!.pixels,
      s.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      reason: 'disk-tier cels reach the archive byte-exactly',
    );
  });

  test('resizeBakedSurfaces transforms cold cels WITHOUT materializing '
      'them into the hot tier', () {
    final store = BrushFrameStore();
    final k = key();
    final source = inkSurface();
    store.restoreBaked({k: blobOf(k, source)});

    const grown = CanvasSize(width: 32, height: 32);
    store.resizeBakedSurfaces(grown);

    expect(store.isCelCold(k), isTrue, reason: '1500 cels must not blow RAM');
    final resized = store.bakedSurfaceOrNull(k)!;
    expect(resized.canvasSize, grown);
    expect(
      resized.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      source.tiles[TileCoord(x: 0, y: 0)]!.pixels,
      reason: 'top-left anchored resize keeps the tile bytes',
    );
  });
}
