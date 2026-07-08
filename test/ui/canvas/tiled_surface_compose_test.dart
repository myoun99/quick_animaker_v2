import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/ui/camera/camera_frame_render_service.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_tile_image_cache.dart';
import 'package:quick_animaker_v2/src/ui/canvas/tiled_surface_compose.dart';

/// The per-tile GPU compose must be byte-identical to the CPU assembly
/// path ([bitmapSurfaceToImage]) — with and without cache reuse — and turn
/// the post-stroke rebuild into cache-hit draws.
void main() {
  tearDown(() {
    debugUploadOffloadPixelThreshold = null;
  });

  BitmapSurface patternedSurface(CanvasSize canvasSize) {
    var surface = BitmapSurface(canvasSize: canvasSize);
    final columns = (canvasSize.width + 255) ~/ 256;
    final rows = (canvasSize.height + 255) ~/ 256;
    for (var tileY = 0; tileY < rows; tileY += 1) {
      for (var tileX = 0; tileX < columns; tileX += 1) {
        final pixels = Uint8List(256 * 256 * 4);
        for (var index = 0; index < pixels.length; index += 4) {
          final pixel = index >> 2;
          pixels[index] = (pixel * 7 + tileX) & 0xFF;
          pixels[index + 1] = (pixel * 13 + tileY) & 0xFF;
          pixels[index + 2] = (pixel * 29) & 0xFF;
          pixels[index + 3] = (pixel * 5) % 256; // 0 / mid / 255 regimes
        }
        surface = surface.putTile(
          BitmapTile(
            coord: TileCoord(x: tileX, y: tileY),
            size: 256,
            pixels: pixels,
          ),
        );
      }
    }
    return surface;
  }

  Future<Uint8List> bytesOf(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> seedCache(
    BitmapTileImageCache cache,
    BitmapSurface surface,
  ) async {
    for (final tile in surface.tiles.values) {
      cache.ensureDecoded(tile);
    }
    while (!cache.allDecoded(surface.tiles.values)) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  testWidgets('tile compose is byte-identical to the CPU assembly, with '
      'and without cache reuse', (tester) async {
    await tester.runAsync(() async {
      // Partial edge tiles on both axes.
      final surface = patternedSurface(
        const CanvasSize(width: 300, height: 200),
      );

      debugUploadOffloadPixelThreshold = 1 << 62; // CPU path stays sync
      final reference = await bytesOf(await bitmapSurfaceToImage(surface));

      final cold = await bytesOf(await composeTiledSurfaceImage(surface));
      expect(cold, reference, reason: 'transient-decode path');

      final cache = BitmapTileImageCache();
      await seedCache(cache, surface);
      final warm = await bytesOf(
        await composeTiledSurfaceImage(surface, reuse: cache),
      );
      expect(warm, reference, reason: 'cache-reuse path');
    });
  });

  testWidgets('warm compose skips every upload (documented timing)', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final surface = patternedSurface(
        const CanvasSize(width: 1920, height: 1080),
      );

      debugUploadOffloadPixelThreshold = 1 << 62;
      final cpuWatch = Stopwatch()..start();
      (await bitmapSurfaceToImage(surface)).dispose();
      cpuWatch.stop();

      // The editing canvas keeps the active frame's tiles decoded — the
      // post-stroke rebuild is the warm case.
      final cache = BitmapTileImageCache();
      await seedCache(cache, surface);
      final warmWatch = Stopwatch()..start();
      (await composeTiledSurfaceImage(surface, reuse: cache)).dispose();
      warmWatch.stop();

      // ignore: avoid_print
      print(
        'layer image rebuild @1920x1080 — CPU assembly+upload: '
        '${cpuWatch.elapsedMilliseconds}ms, warm per-tile GPU compose: '
        '${warmWatch.elapsedMilliseconds}ms (active-frame post-stroke case)',
      );
      expect(
        warmWatch.elapsedMilliseconds,
        lessThanOrEqualTo(cpuWatch.elapsedMilliseconds),
      );
    });
  });
}
