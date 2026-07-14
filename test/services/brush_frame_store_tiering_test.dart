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
import 'package:quick_animaker_v2/src/services/brush_frame_store.dart';
import 'package:quick_animaker_v2/src/services/persistence/brush_drawing_binary_codec.dart';

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
