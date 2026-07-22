import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/property_track.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/transform_track.dart';
import 'package:quick_animaker_v2/src/services/canvas_color_sampler.dart';

void main() {
  const canvasSize = CanvasSize(width: 8, height: 8);

  /// An 8×8 surface (2×2 tiles of 4) with straight-RGBA [pixels] set at
  /// canvas points.
  BitmapSurface surfaceWithPixels(Map<(int, int), List<int>> pixels) {
    final tiles = <TileCoord, Uint8List>{};
    for (final entry in pixels.entries) {
      final (x, y) = entry.key;
      final coord = TileCoord(x: x ~/ 4, y: y ~/ 4);
      final buffer = tiles.putIfAbsent(coord, () => Uint8List(4 * 4 * 4));
      final index = ((y % 4) * 4 + (x % 4)) * 4;
      buffer.setAll(index, entry.value);
    }
    return BitmapSurface(
      canvasSize: canvasSize,
      tileSize: 4,
      tiles: {
        for (final entry in tiles.entries)
          entry.key: BitmapTile(coord: entry.key, size: 4, pixels: entry.value),
      },
    );
  }

  Frame frame(String id) =>
      Frame(id: FrameId(id), duration: 1, strokes: const []);

  Layer layer(
    String id, {
    double opacity = 1,
    TransformTrack? transformTrack,
  }) => Layer(
    id: LayerId(id),
    name: id,
    frames: [frame('$id-frame')],
    timeline: {0: TimelineExposure.drawing(FrameId('$id-frame'), length: 1)},
    opacity: opacity,
    transformTrack: transformTrack ?? TransformTrack.empty(),
  );

  Cut cut(List<Layer> layers) => Cut(
    id: const CutId('cut'),
    name: 'Cut',
    layers: layers,
    duration: 24,
    canvasSize: canvasSize,
  );

  group('surfacePixelRgba', () {
    test('reads a pixel through the tile grid', () {
      final surface = surfaceWithPixels({
        (5, 2): [0x11, 0x22, 0x33, 0xFF],
      });
      expect(surfacePixelRgba(surface, 5, 2), 0x112233FF);
    });

    test('missing tiles are transparent; only beyond the PASTEBOARD wall '
        'is null (off-canvas pixels are pickable, Flash-style)', () {
      final surface = surfaceWithPixels({
        (0, 0): [1, 2, 3, 4],
      });
      expect(surfacePixelRgba(surface, 6, 6), 0);
      expect(surfacePixelRgba(surface, -1, 0), 0,
          reason: 'off-canvas but on the pasteboard = transparent, not null');
      expect(surfacePixelRgba(surface, 8, 0), 0);
      // The 8×8 stage's 5x5 pasteboard: x,y ∈ [-16, 24).
      expect(surfacePixelRgba(surface, -17, 0), isNull);
      expect(surfacePixelRgba(surface, 24, 0), isNull);
    });

    test('reads OFF-canvas pixels through negative tiles (floorDiv — the '
        'eyedropper picks pasteboard artwork)', () {
      // Canvas point (-3, 2) lives on tile (-1, 0) at local (1, 2)
      // (Dart % is Euclidean: -3 % 4 == 1).
      final buffer = Uint8List(4 * 4 * 4);
      buffer.setAll((2 * 4 + 1) * 4, [0xAA, 0xBB, 0xCC, 0xFF]);
      final surface = BitmapSurface(
        canvasSize: canvasSize,
        tileSize: 4,
        tiles: {
          TileCoord(x: -1, y: 0): BitmapTile(
            coord: TileCoord(x: -1, y: 0),
            size: 4,
            pixels: buffer,
          ),
        },
      );
      expect(surfacePixelRgba(surface, -3, 2), 0xAABBCCFF);
    });
  });

  group('sampleCompositeColor', () {
    test('empty canvas samples the paper color', () {
      final color = sampleCompositeColor(
        cut: cut([layer('a')]),
        frameIndex: 0,
        surfaceResolver: (_, _) => null,
        point: CanvasPoint(x: 3, y: 3),
      );
      expect(color, canvasPaperColor);
    });

    test('an opaque pixel samples exactly', () {
      final surface = surfaceWithPixels({
        (3, 3): [0xFF, 0x00, 0x00, 0xFF],
      });
      final color = sampleCompositeColor(
        cut: cut([layer('a')]),
        frameIndex: 0,
        surfaceResolver: (_, _) => surface,
        point: CanvasPoint(x: 3.4, y: 3.9),
      );
      expect(color, 0xFFFF0000);
    });

    test('layer opacity blends over the paper', () {
      final surface = surfaceWithPixels({
        (3, 3): [0xFF, 0x00, 0x00, 0xFF],
      });
      final color = sampleCompositeColor(
        cut: cut([layer('a', opacity: 0.5)]),
        frameIndex: 0,
        surfaceResolver: (_, _) => surface,
        point: CanvasPoint(x: 3, y: 3),
      );
      // r = 255·0.5 + 237·0.5 = 246; g = b = 237·0.5 = 118.5 → 119.
      expect(color, 0xFFF67777);
    });

    test('pixel alpha blends over the paper', () {
      final surface = surfaceWithPixels({
        (3, 3): [0xFF, 0x00, 0x00, 0x80],
      });
      final color = sampleCompositeColor(
        cut: cut([layer('a')]),
        frameIndex: 0,
        surfaceResolver: (_, _) => surface,
        point: CanvasPoint(x: 3, y: 3),
      );
      // α = 128/255: r = 255·α + 237·(1−α) ≈ 246, g = b ≈ 118.
      expect(color, 0xFFF67676);
    });

    test('the top layer wins where opaque', () {
      final red = surfaceWithPixels({
        (3, 3): [0xFF, 0x00, 0x00, 0xFF],
      });
      final blue = surfaceWithPixels({
        (3, 3): [0x00, 0x00, 0xFF, 0xFF],
      });
      final color = sampleCompositeColor(
        cut: cut([layer('bottom'), layer('top')]),
        frameIndex: 0,
        surfaceResolver: (layer, _) => layer.id.value == 'bottom' ? red : blue,
        point: CanvasPoint(x: 3, y: 3),
      );
      expect(color, 0xFF0000FF);
    });

    test('posed layers are skipped (v1) unless their fx are bypassed', () {
      final surface = surfaceWithPixels({
        (3, 3): [0x00, 0xFF, 0x00, 0xFF],
      });
      final posed = cut([
        layer(
          'a',
          transformTrack: TransformTrack.empty().copyWith(
            scale: PropertyTrack<double>.empty().withKey(0, 2.0),
          ),
        ),
      ]);
      expect(
        sampleCompositeColor(
          cut: posed,
          frameIndex: 0,
          surfaceResolver: (_, _) => surface,
          point: CanvasPoint(x: 3, y: 3),
        ),
        canvasPaperColor,
      );
      // With the layer's fx bypassed the pose drops out and the pixel
      // samples directly.
      expect(
        sampleCompositeColor(
          cut: posed,
          frameIndex: 0,
          surfaceResolver: (_, _) => surface,
          point: CanvasPoint(x: 3, y: 3),
          fxBypassedLayerIds: {const LayerId('a')},
        ),
        0xFF00FF00,
      );
    });

    test('points outside the canvas sample the paper', () {
      final surface = surfaceWithPixels({
        (0, 0): [0xFF, 0x00, 0x00, 0xFF],
      });
      final color = sampleCompositeColor(
        cut: cut([layer('a')]),
        frameIndex: 0,
        surfaceResolver: (_, _) => surface,
        point: CanvasPoint(x: -2, y: 11),
      );
      expect(color, canvasPaperColor);
    });
  });
}
