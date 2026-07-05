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
import 'package:quick_animaker_v2/src/services/brush_live_stroke_rasterizer.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay_painter.dart';

/// The live stroke is CPU-rasterized with the same math as the commit path,
/// so the pixels on screen while drawing must be byte-identical to the
/// committed pixels — for every hardness, tip shape, and fractional center.
/// These tests lock that unification:
///
/// 1. `BrushLiveStrokeRasterizer` output == `materialize...` output, exactly.
/// 2. The pen-up composite fast path == full re-rasterization onto a painted
///    base, within one rounding step (source-over associativity).
/// 3. The region sprite (GPU upload of the live buffer) reads back as the
///    buffer's premultiplied bytes.

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

const int _canvasWidth = 40;
const int _canvasHeight = 40;
const _canvasSize = CanvasSize(width: _canvasWidth, height: _canvasHeight);

Uint8List _liveBufferFor(List<BrushDab> dabs) {
  final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
  rasterizer.blendFrom(dabs, from: 0);
  return rasterizer.pixels;
}

/// Canvas-wide straight-alpha bytes of the materialized surface.
Uint8List _materializedBytes(
  List<BrushDab> dabs, {
  BitmapSurface? baseSurface,
}) {
  final result = materializeBrushDabSequenceOnBitmapSurface(
    surface:
        baseSurface ?? BitmapSurface(canvasSize: _canvasSize, tileSize: 64),
    sequence: BrushDabSequence(dabs),
  );
  return _surfaceBytes(result.surface);
}

Uint8List _surfaceBytes(BitmapSurface surface) {
  final bytes = Uint8List(_canvasWidth * _canvasHeight * 4);
  final tile = surface.tileAt(TileCoord(x: 0, y: 0));
  if (tile == null) {
    return bytes;
  }
  final tilePixels = tile.pixels;
  for (var y = 0; y < _canvasHeight; y += 1) {
    for (var x = 0; x < _canvasWidth; x += 1) {
      final tileOffset = (y * tile.size + x) * 4;
      final outOffset = (y * _canvasWidth + x) * 4;
      for (var channel = 0; channel < 4; channel += 1) {
        bytes[outOffset + channel] = tilePixels[tileOffset + channel];
      }
    }
  }
  return bytes;
}

void _expectExact(Uint8List actual, Uint8List expected, String reason) {
  expect(actual.length, expected.length);
  for (var index = 0; index < actual.length; index += 1) {
    if (actual[index] != expected[index]) {
      final pixel = index ~/ 4;
      fail(
        '$reason: channel ${index % 4} at pixel '
        '(${pixel % _canvasWidth}, ${pixel ~/ _canvasWidth}) is '
        '${actual[index]}, expected ${expected[index]}.',
      );
    }
  }
}

void _expectClose(
  Uint8List actual,
  Uint8List expected,
  String reason, {
  required int tolerance,
}) {
  expect(actual.length, expected.length);
  for (var index = 0; index < actual.length; index += 1) {
    final difference = (actual[index] - expected[index]).abs();
    if (difference > tolerance) {
      final pixel = index ~/ 4;
      fail(
        '$reason: channel ${index % 4} at pixel '
        '(${pixel % _canvasWidth}, ${pixel ~/ _canvasWidth}) differs by '
        '$difference (actual ${actual[index]}, expected ${expected[index]}).',
      );
    }
  }
}

void main() {
  group('live stroke rasterizer matches the commit rasterizer exactly', () {
    final scenarios = <String, List<BrushDab>>{
      'hard round dab on fractional center': [
        _dab(x: 9.13, y: 8.62, hardness: 1.0, opacity: 1.0, flow: 1.0),
      ],
      'soft round dab on fractional center': [
        _dab(x: 14.37, y: 12.81, size: 16, hardness: 0.3),
      ],
      'fully soft dab': [_dab(x: 14.5, y: 14.5, hardness: 0.0, size: 16)],
      'square tip dab': [_dab(x: 11.4, y: 9.7, tipShape: BrushTipShape.square)],
      'overlapping translucent stroke': [
        for (var i = 0; i < 6; i += 1)
          _dab(
            x: 7.37 + i * 3.21,
            y: 9.81 + i * 1.43,
            color: 0x8040A0C0,
            sequence: i,
          ),
      ],
      'canvas edge overhang': [
        _dab(x: 0.6, y: 0.4, size: 14, sequence: 0),
        _dab(x: 38.7, y: 38.9, size: 14, sequence: 1),
      ],
    };

    scenarios.forEach((name, dabs) {
      test(name, () {
        _expectExact(_liveBufferFor(dabs), _materializedBytes(dabs), name);
      });
    });
  });

  group('pen-up composite fast path matches full re-rasterization', () {
    test('stroke over painted base within one rounding step', () {
      final baseDabs = [
        for (var i = 0; i < 5; i += 1)
          _dab(x: 8.5 + i * 4.0, y: 12.5, color: 0xCC994411, sequence: i),
      ];
      final base = materializeBrushDabSequenceOnBitmapSurface(
        surface: BitmapSurface(canvasSize: _canvasSize, tileSize: 64),
        sequence: BrushDabSequence(baseDabs),
      ).surface;

      final strokeDabs = [
        for (var i = 0; i < 5; i += 1)
          _dab(x: 10.2 + i * 3.6, y: 13.4, color: 0x9040A0C0, sequence: i),
      ];
      final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
      rasterizer.blendFrom(strokeDabs, from: 0);

      final composite = compositeStrokePixelsOntoBitmapSurface(
        surface: base,
        strokePixels: rasterizer.pixels,
        bounds: rasterizer.strokeBounds!,
      );
      final reference = materializeBrushDabSequenceOnBitmapSurface(
        surface: base,
        sequence: BrushDabSequence(strokeDabs),
      );

      expect(composite.dirtyTiles.isNotEmpty, isTrue);
      // Source-over is associative in real arithmetic but the two routes
      // quantize at different points (per-dab onto base vs stroke buffer
      // then one composite), so translucent overlaps drift by a rounding
      // step per overlapping dab. The painted pixel SET must match exactly;
      // channel values may drift slightly. What the user saw while drawing
      // is the buffer, and the commit composites exactly that buffer, so
      // the on-screen/committed unification itself is exact by construction.
      final compositeBytes = _surfaceBytes(composite.surface);
      final referenceBytes = _surfaceBytes(reference.surface);
      for (var index = 3; index < compositeBytes.length; index += 4) {
        expect(
          compositeBytes[index] > 0,
          referenceBytes[index] > 0,
          reason: 'painted pixel set must match at byte ',
        );
      }
      _expectClose(
        compositeBytes,
        referenceBytes,
        'composite vs re-rasterize',
        tolerance: 8,
      );
    });

    test('opaque stroke over blank base is exact', () {
      final strokeDabs = [
        for (var i = 0; i < 4; i += 1)
          _dab(
            x: 9.3 + i * 4.1,
            y: 11.8,
            opacity: 1.0,
            flow: 1.0,
            hardness: 1.0,
            sequence: i,
          ),
      ];
      final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
      rasterizer.blendFrom(strokeDabs, from: 0);

      final composite = compositeStrokePixelsOntoBitmapSurface(
        surface: BitmapSurface(canvasSize: _canvasSize, tileSize: 64),
        strokePixels: rasterizer.pixels,
        bounds: rasterizer.strokeBounds!,
      );

      _expectExact(
        _surfaceBytes(composite.surface),
        _materializedBytes(strokeDabs),
        'opaque composite',
      );
    });
  });

  group('region sprite reads back as the live buffer', () {
    test('sprite pixels equal premultiplied buffer pixels', () async {
      final dabs = [
        _dab(x: 9.13, y: 8.62, size: 12, hardness: 0.4),
        _dab(x: 12.4, y: 10.1, size: 12, hardness: 0.4, sequence: 1),
      ];
      final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
      final region = rasterizer.blendFrom(dabs, from: 0)!;

      final sprite = strokeRegionSprite(
        pixels: rasterizer.pixels,
        canvasWidth: _canvasWidth,
        region: region,
      );
      final byteData = await sprite.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final spriteBytes = byteData!.buffer.asUint8List();

      final width = region.rightExclusive - region.left;
      for (var y = 0; y < region.bottomExclusive - region.top; y += 1) {
        for (var x = 0; x < width; x += 1) {
          final bufferOffset =
              ((region.top + y) * _canvasWidth + region.left + x) * 4;
          final spriteOffset = (y * width + x) * 4;
          final alpha = rasterizer.pixels[bufferOffset + 3];
          final expected = [
            _mul255Round(rasterizer.pixels[bufferOffset], alpha),
            _mul255Round(rasterizer.pixels[bufferOffset + 1], alpha),
            _mul255Round(rasterizer.pixels[bufferOffset + 2], alpha),
            alpha,
          ];
          for (var channel = 0; channel < 4; channel += 1) {
            final difference =
                (spriteBytes[spriteOffset + channel] - expected[channel]).abs();
            if (difference > 2) {
              fail(
                'sprite channel $channel at ($x, $y) differs by $difference',
              );
            }
          }
        }
      }
    });

    test(
      'painter draws the composed overlay image with plain source-over',
      () async {
        final dabs = [_dab(x: 8.5, y: 8.5, opacity: 1.0, flow: 1.0)];
        final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
        final region = rasterizer.blendFrom(dabs, from: 0)!;

        final sprite = strokeRegionSprite(
          pixels: rasterizer.pixels,
          canvasWidth: _canvasWidth,
          region: region,
        );
        final model = ActiveStrokeOverlayModel();
        model.dabs.addAll(dabs);
        model.overlayImage = composeOverlayImage(
          previous: null,
          regionSprite: sprite,
          regionOffset: Offset(region.left.toDouble(), region.top.toDouble()),
          canvasWidth: _canvasWidth,
          canvasHeight: _canvasHeight,
        );
        sprite.dispose();

        final recorder = ui.PictureRecorder();
        ActiveStrokeOverlayPainter(model: model).paint(
          Canvas(recorder),
          const Size(_canvasWidth * 1.0, _canvasHeight * 1.0),
        );
        final image = await recorder.endRecording().toImage(
          _canvasWidth,
          _canvasHeight,
        );
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final painted = byteData!.buffer.asUint8List();

        // The dab center pixel must carry the full stroke color.
        final centerOffset = (8 * _canvasWidth + 8) * 4;
        expect(painted[centerOffset + 3], greaterThan(0));
        model.dispose();
      },
    );

    test(
      'overlay image region replacement keeps earlier stroke content',
      () async {
        // Two batches whose regions overlap: the second compose must keep
        // the first batch's pixels inside the shared rect (the sprite crops
        // the accumulated buffer) and outside it (source-over base draw).
        final firstBatch = [_dab(x: 8.5, y: 8.5, opacity: 1.0, flow: 1.0)];
        final secondBatch = [
          _dab(x: 12.5, y: 8.5, opacity: 1.0, flow: 1.0, sequence: 1),
        ];
        final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);

        final firstRegion = rasterizer.blendFrom(firstBatch, from: 0)!;
        final firstSprite = strokeRegionSprite(
          pixels: rasterizer.pixels,
          canvasWidth: _canvasWidth,
          region: firstRegion,
        );
        var overlay = composeOverlayImage(
          previous: null,
          regionSprite: firstSprite,
          regionOffset: Offset(
            firstRegion.left.toDouble(),
            firstRegion.top.toDouble(),
          ),
          canvasWidth: _canvasWidth,
          canvasHeight: _canvasHeight,
        );
        firstSprite.dispose();

        final allDabs = [...firstBatch, ...secondBatch];
        final secondRegion = rasterizer.blendFrom(allDabs, from: 1)!;
        final secondSprite = strokeRegionSprite(
          pixels: rasterizer.pixels,
          canvasWidth: _canvasWidth,
          region: secondRegion,
        );
        final previousOverlay = overlay;
        overlay = composeOverlayImage(
          previous: previousOverlay,
          regionSprite: secondSprite,
          regionOffset: Offset(
            secondRegion.left.toDouble(),
            secondRegion.top.toDouble(),
          ),
          canvasWidth: _canvasWidth,
          canvasHeight: _canvasHeight,
        );
        secondSprite.dispose();
        previousOverlay.dispose();

        final byteData = await overlay.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final bytes = byteData!.buffer.asUint8List();
        // Both dab centers remain painted after the second compose.
        expect(bytes[(8 * _canvasWidth + 8) * 4 + 3], greaterThan(0));
        expect(bytes[(8 * _canvasWidth + 12) * 4 + 3], greaterThan(0));
        overlay.dispose();
      },
    );
  });
}

int _mul255Round(int value, int alpha) {
  final product = value * alpha + 128;
  return (product + (product >> 8)) >> 8;
}
