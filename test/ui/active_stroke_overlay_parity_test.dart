import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay_painter.dart';

/// The active overlay is a live preview of what the commit rasterizer will
/// produce on pointer-up. These tests stamp dabs through the overlay painter
/// and compare against the rasterized surface within a small tolerance
/// (byte-quantized mask coverage + premultiplied readback rounding). The old
/// square-stamp painter differed by full 255-alpha pixels at tip corners, so
/// this parity bound would catch any regression to non-WYSIWYG previews.
const int channelTolerance = 8;

BrushDab _dab({
  required double x,
  required double y,
  double size = 10,
  int color = 0xFF336699,
  double opacity = 0.8,
  double flow = 0.7,
  double hardness = 0.5,
  BrushTipShape tipShape = BrushTipShape.round,
  int sequence = 0,
}) {
  return BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: color,
    size: size,
    opacity: opacity,
    flow: flow,
    hardness: hardness,
    tipShape: tipShape,
    pressure: 1.0,
    sequence: sequence,
  );
}

Future<Uint8List> _stampedPixels(
  List<BrushDab> dabs, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ActiveStrokeOverlayPainter(
    activeStrokeOverlay: dabs,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

/// Rasterizes [dabs] and returns straight-alpha RGBA converted to the same
/// premultiplied form the overlay readback uses.
Uint8List _rasterizedPixels(
  List<BrushDab> dabs, {
  required int width,
  required int height,
}) {
  final result = materializeBrushDabSequenceOnBitmapSurface(
    surface: BitmapSurface(
      canvasSize: CanvasSize(width: width, height: height),
      tileSize: 64,
    ),
    sequence: BrushDabSequence(dabs),
  );

  final premultiplied = Uint8List(width * height * 4);
  final tile = result.surface.tileAt(TileCoord(x: 0, y: 0));
  if (tile == null) {
    return premultiplied;
  }
  final tilePixels = tile.pixels;
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      final tileOffset = (y * tile.size + x) * 4;
      final outOffset = (y * width + x) * 4;
      final alpha = tilePixels[tileOffset + 3];
      premultiplied[outOffset] = _mul255Round(tilePixels[tileOffset], alpha);
      premultiplied[outOffset + 1] = _mul255Round(
        tilePixels[tileOffset + 1],
        alpha,
      );
      premultiplied[outOffset + 2] = _mul255Round(
        tilePixels[tileOffset + 2],
        alpha,
      );
      premultiplied[outOffset + 3] = alpha;
    }
  }
  return premultiplied;
}

int _mul255Round(int value, int alpha) {
  final product = value * alpha + 128;
  return (product + (product >> 8)) >> 8;
}

void _expectClose(
  Uint8List actual,
  Uint8List expected, {
  required int width,
  required String reason,
  int tolerance = channelTolerance,
}) {
  expect(actual.length, expected.length);
  for (var index = 0; index < actual.length; index += 1) {
    final difference = (actual[index] - expected[index]).abs();
    if (difference > tolerance) {
      final pixel = index ~/ 4;
      fail(
        '$reason: channel ${index % 4} at pixel '
        '(${pixel % width}, ${pixel ~/ width}) differs by $difference '
        '(actual ${actual[index]}, expected ${expected[index]}).',
      );
    }
  }
}

Future<void> _expectStampParity(
  List<BrushDab> dabs, {
  required String reason,
  int width = 40,
  int height = 40,
  int tolerance = channelTolerance,
}) async {
  final stamped = await _stampedPixels(dabs, width: width, height: height);
  final rasterized = _rasterizedPixels(dabs, width: width, height: height);
  _expectClose(
    stamped,
    rasterized,
    width: width,
    reason: reason,
    tolerance: tolerance,
  );
}

void main() {
  group('active stroke overlay parity with commit rasterizer', () {
    test('soft round dab on a pixel-aligned center', () async {
      // size 10 -> mask dimension 11, half 5.5; center x=8.5 places the mask
      // at integer offset 3.0 so mask texels align with canvas pixels.
      await _expectStampParity([
        _dab(x: 8.5, y: 8.5),
      ], reason: 'soft round dab');
    });

    test('hard round dab', () async {
      await _expectStampParity([
        _dab(x: 12.5, y: 10.5, hardness: 1.0, opacity: 1.0, flow: 1.0),
      ], reason: 'hard round dab');
    });

    test('hardness zero (fully soft) dab', () async {
      await _expectStampParity([
        _dab(x: 14.5, y: 14.5, hardness: 0.0, size: 16),
      ], reason: 'fully soft dab');
    });

    test(
      'sequential overlapping stroke accumulates like the rasterizer',
      () async {
        await _expectStampParity([
          for (var i = 0; i < 6; i += 1)
            _dab(x: 8.5 + i * 3.0, y: 10.5 + i * 1.0, sequence: i),
        ], reason: 'overlapping stroke');
      },
    );

    test('translucent color stroke', () async {
      await _expectStampParity([
        _dab(x: 10.5, y: 10.5, color: 0x8040A0C0, sequence: 0),
        _dab(x: 13.5, y: 11.5, color: 0x8040A0C0, sequence: 1),
      ], reason: 'translucent stroke');
    });

    // Fractional dab centers exercise the subpixel-phase masks: the stamp
    // coverage must track the rasterizer's true-center sampling instead of
    // snapping to the pixel grid (which fizzed along live stroke edges).
    // Soft tips keep the residual 1/8px phase-quantization error to a small
    // alpha delta; hard tips can flip full boundary pixels, so they are
    // covered by the visual-stability design rather than byte parity.
    test('fractional-center soft dab tracks the rasterizer', () async {
      await _expectStampParity(
        [_dab(x: 9.13, y: 8.62, size: 14, hardness: 0.3)],
        reason: 'fractional center dab',
        tolerance: 32,
      );
    });

    test('fractional-center soft stroke tracks the rasterizer', () async {
      await _expectStampParity(
        [
          for (var i = 0; i < 5; i += 1)
            _dab(
              x: 7.37 + i * 3.21,
              y: 9.81 + i * 1.43,
              size: 12,
              hardness: 0.2,
              sequence: i,
            ),
        ],
        reason: 'fractional center stroke',
        tolerance: 32,
      );
    });
  });
}
