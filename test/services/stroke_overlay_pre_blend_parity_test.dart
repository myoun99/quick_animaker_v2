import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/native_engine_path.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_blend_mode.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/dirty_region.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/native/qa_native_engine.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_stroke_blend.dart';

/// R27 #4: the live overlay's PRE-BLEND must be byte-identical to the
/// pen-up commit — for EVERY brush blend mode, erase included, against
/// both the native kernel and the Dart fallback. This is the user's rule
/// verbatim: "블렌드모드를 다른걸로 해두더라도 오차가 없어야" — the tile
/// on screen while drawing IS the committed tile, not an approximation
/// of it. Randomized bases (missing / partial tiles) and edge-biased
/// stroke alphas; any single byte of drift fails.
void main() {
  final dllPath = nativeEngineLibraryPathOrNull();
  final available = dllPath != null;

  tearDown(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = null;
    QaNativeEngine.debugForceDartFallback = false;
  });

  Uint8List randomPixels(Random random, int byteLength) {
    final bytes = Uint8List(byteLength);
    for (var i = 0; i < byteLength; i += 1) {
      final roll = random.nextInt(10);
      bytes[i] = roll == 0
          ? 0
          : roll == 1
          ? 255
          : random.nextInt(256);
    }
    return bytes;
  }

  const tileSize = 32;
  const canvasSize = CanvasSize(width: 96, height: 64);

  BitmapSurface randomSurface(Random random) {
    final tiles = <TileCoord, BitmapTile>{};
    for (var tileY = -1; tileY * tileSize < canvasSize.height; tileY += 1) {
      for (var tileX = -1; tileX * tileSize < canvasSize.width; tileX += 1) {
        if (random.nextInt(3) == 0) {
          continue; // Missing tiles: the transparent-read branches.
        }
        final coord = TileCoord(x: tileX, y: tileY);
        tiles[coord] = BitmapTile(
          coord: coord,
          size: tileSize,
          pixels: randomPixels(random, tileSize * tileSize * 4),
        );
      }
    }
    return BitmapSurface(
      canvasSize: canvasSize,
      tileSize: tileSize,
      tiles: tiles,
    );
  }

  /// The modes a stroke can pre-blend — everything but plain color.
  const preBlendModes = [
    BrushBlendMode.erase,
    BrushBlendMode.behind,
    BrushBlendMode.add,
    BrushBlendMode.darken,
    BrushBlendMode.multiply,
    BrushBlendMode.colorBurn,
    BrushBlendMode.lighten,
    BrushBlendMode.screen,
    BrushBlendMode.colorDodge,
    BrushBlendMode.overlay,
    BrushBlendMode.softLight,
    BrushBlendMode.hardLight,
    BrushBlendMode.difference,
    BrushBlendMode.exclusion,
  ];

  void runAllModes({required int seed}) {
    final random = Random(seed);
    for (final mode in preBlendModes) {
      final surface = randomSurface(random);
      // A stroke region straddling tile boundaries and the canvas edge.
      final bounds = DirtyRegion(
        left: 7,
        top: 5,
        rightExclusive: 71,
        bottomExclusive: 53,
      );
      final width = bounds.rightExclusive - bounds.left;
      final height = bounds.bottomExclusive - bounds.top;
      final stroke = randomPixels(random, width * height * 4);

      // What the pen-up will land: the REAL commit, whichever kernel is
      // live (native when loaded, Dart reference otherwise).
      final committed = compositeStrokePixelsOntoBitmapSurface(
        surface: surface,
        strokePixels: stroke,
        bounds: bounds,
        erase: mode == BrushBlendMode.erase,
        blendMode: mode,
      );
      final expected = bitmapSurfaceRegionPixels(committed.surface, bounds);

      // What the overlay shows while drawing.
      final live = preBlendStrokeOverlayPixels(
        dst: bitmapSurfaceRegionPixels(surface, bounds),
        src: stroke,
        mode: mode,
        erase: mode == BrushBlendMode.erase,
        pixelCount: width * height,
      );

      expect(
        live,
        expected,
        reason:
            '${mode.name}: the live overlay must be byte-identical to the '
            'commit',
      );
    }
  }

  test('live pre-blend == Dart-reference commit, every mode, byte for byte',
      () {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugForceDartFallback = true;
    expect(QaNativeEngine.instance, isNull);
    runAllModes(seed: 20260723);
  });

  test('live pre-blend == NATIVE commit, every mode, byte for byte', () {
    if (!available) {
      markTestSkipped(
        'qa_engine.dll not built — run: cmake -S packages/qa_native/src -B '
        'build/native_standalone && cmake --build build/native_standalone '
        '--config Release',
      );
      return;
    }
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = dllPath;
    QaNativeEngine.debugForceDartFallback = false;
    expect(QaNativeEngine.instance, isNotNull);
    runAllModes(seed: 8151225);
  });
}
