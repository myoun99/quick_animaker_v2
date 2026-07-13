import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_stamp_image.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/native/qa_native_engine.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';

/// R18 A-0: the native engine core must be BYTE-IDENTICAL to the Dart
/// reference implementation — randomized stamps (paint and erase, edge
/// alphas, fractional opacities) materialized through both paths and
/// compared per pixel. Skips (loudly) when no locally built binary is
/// found; CI/dev machines with the standalone cmake build run it.
void main() {
  final dllPath =
      '${Directory.current.path}\\build\\native_standalone\\Release\\qa_engine.dll';
  final available = File(dllPath).existsSync();

  setUp(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = dllPath;
    QaNativeEngine.debugForceDartFallback = false;
  });

  tearDown(() {
    QaNativeEngine.debugResetForTests();
    QaNativeEngine.debugLibraryPathOverride = null;
    QaNativeEngine.debugForceDartFallback = false;
  });

  Uint8List snapshot(BitmapSurface surface, CanvasSize canvasSize) {
    final bytes = Uint8List(canvasSize.width * canvasSize.height * 4);
    for (final tile in surface.tiles.values) {
      final pixels = tile.pixels;
      for (var y = 0; y < tile.size; y += 1) {
        final globalY = tile.coord.y * tile.size + y;
        if (globalY >= canvasSize.height) {
          break;
        }
        for (var x = 0; x < tile.size; x += 1) {
          final globalX = tile.coord.x * tile.size + x;
          if (globalX >= canvasSize.width) {
            break;
          }
          final source = (y * tile.size + x) * 4;
          final target = (globalY * canvasSize.width + globalX) * 4;
          bytes.setRange(target, target + 4, pixels, source);
        }
      }
    }
    return bytes;
  }

  test('native stamp blend == Dart reference, byte for byte (randomized)', () {
    if (!available) {
      markTestSkipped(
        'qa_engine.dll not built — run: cmake -S native -B '
        'build/native_standalone && cmake --build build/native_standalone '
        '--config Release',
      );
      return;
    }
    expect(
      QaNativeEngine.instance,
      isNotNull,
      reason: 'the locally built engine must load',
    );

    const canvasSize = CanvasSize(width: 96, height: 64);
    final random = Random(20260714);

    for (var round = 0; round < 24; round += 1) {
      final width = 1 + random.nextInt(60);
      final height = 1 + random.nextInt(40);
      final rgba = Uint8List(width * height * 4);
      for (var i = 0; i < rgba.length; i += 1) {
        // Edge-biased alphas: plenty of 0s and 255s plus the full range.
        final roll = random.nextInt(10);
        rgba[i] = roll == 0
            ? 0
            : roll == 1
            ? 255
            : random.nextInt(256);
      }
      final erase = round.isOdd;
      final opacityRoll = round % 3;
      final opacity = opacityRoll == 0
          ? 1.0
          : opacityRoll == 1
          ? 0.5
          : random.nextDouble();
      final dab = BrushDab(
        center: CanvasPoint(
          x: random.nextInt(canvasSize.width).toDouble(),
          y: random.nextInt(canvasSize.height).toDouble(),
        ),
        color: 0xFF000000,
        size: max(width, height).toDouble(),
        opacity: opacity,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.square,
        pressure: 1,
        sequence: 0,
        stamp: BrushStampImage(
          id: 'parity-$round',
          width: width,
          height: height,
          rgba: rgba,
        ),
        erase: erase,
      );

      // A non-blank base so blends exercise real destination bytes.
      final baseRgba = Uint8List(48 * 48 * 4);
      for (var i = 0; i < baseRgba.length; i += 1) {
        baseRgba[i] = random.nextInt(256);
      }
      final base = materializeBrushDabSequenceOnBitmapSurface(
        surface: BitmapSurface(canvasSize: canvasSize, tileSize: 32),
        sequence: BrushDabSequence([
          BrushDab(
            center: CanvasPoint(x: 30, y: 30),
            color: 0xFF000000,
            size: 48,
            opacity: 1,
            flow: 1,
            hardness: 1,
            tipShape: BrushTipShape.square,
            pressure: 1,
            sequence: 0,
            stamp: BrushStampImage(
              id: 'base-$round',
              width: 48,
              height: 48,
              rgba: baseRgba,
            ),
          ),
        ]),
      ).surface;

      QaNativeEngine.debugForceDartFallback = true;
      final dartResult = materializeBrushDabSequenceOnBitmapSurface(
        surface: base,
        sequence: BrushDabSequence([dab]),
      );
      QaNativeEngine.debugForceDartFallback = false;
      final nativeResult = materializeBrushDabSequenceOnBitmapSurface(
        surface: base,
        sequence: BrushDabSequence([dab]),
      );

      expect(
        snapshot(nativeResult.surface, canvasSize),
        snapshot(dartResult.surface, canvasSize),
        reason: 'round $round (erase=$erase opacity=$opacity '
            '${width}x$height) must be byte-identical',
      );
      expect(
        nativeResult.dirtyTiles.coords.toSet(),
        dartResult.dirtyTiles.coords.toSet(),
        reason: 'round $round dirty tiles must agree',
      );
    }
  });
}
