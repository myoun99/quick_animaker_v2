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
import 'package:quick_animaker_v2/src/models/dirty_region.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/brush_live_stroke_rasterizer.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_surface_painter.dart';

/// The live stroke is CPU-rasterized with the same math as the commit path,
/// so the pixels on screen while drawing must be byte-identical to the
/// committed pixels — for every hardness, tip shape, and fractional center.
/// These tests lock that unification:
///
/// 1. `BrushLiveStrokeRasterizer` output == `materialize...` output, exactly.
/// 2. The pen-up composite fast path == full re-rasterization onto a painted
///    base, within one rounding step (source-over associativity).
/// 3. The overlay's region pictures — replayed in order through the
///    production painter's isolated layer — reproduce the buffer's
///    premultiplied bytes: replacement semantics, flattening, and the
///    source-over composite onto committed artwork.

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

  group('region pictures replay as the live buffer', () {
    // Renders the overlay exactly the way production does: through
    // BitmapSurfacePainter's isolated layer over the given surface.
    Future<Uint8List> paintedCanvasBytes(
      ActiveStrokeOverlayModel model, {
      BitmapSurface? baseSurface,
    }) async {
      final recorder = ui.PictureRecorder();
      BitmapSurfacePainter(
        surface:
            baseSurface ?? BitmapSurface(canvasSize: _canvasSize, tileSize: 64),
        overlayModel: model,
        showTransparentBackground: false,
      ).paint(
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
      return byteData!.buffer.asUint8List();
    }

    void addRegion(
      ActiveStrokeOverlayModel model,
      BrushLiveStrokeRasterizer rasterizer,
      DirtyRegion region,
    ) {
      model.addRegionPicture(
        strokeRegionPicture(
          pixels: rasterizer.pixels,
          canvasWidth: _canvasWidth,
          region: region,
        ),
      );
    }

    test('a single region picture replays as the premultiplied buffer', () async {
      final dabs = [
        _dab(x: 9.13, y: 8.62, size: 12, hardness: 0.4),
        _dab(x: 12.4, y: 10.1, size: 12, hardness: 0.4, sequence: 1),
      ];
      final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
      final region = rasterizer.blendFrom(dabs, from: 0)!;

      final model = ActiveStrokeOverlayModel();
      addTearDown(model.dispose);
      addRegion(model, rasterizer, region);

      _expectClose(
        await paintedCanvasBytes(model),
        _premultipliedCanvasBytes(rasterizer.pixels),
        'single region replay',
        tolerance: 2,
      );
    });

    test(
      'later region pictures replace overlapping content, not re-blend it',
      () async {
        // Each region picture carries the accumulated buffer values for its
        // rect, so where two batches overlap the second picture must REPLACE
        // the first one's pixels (BlendMode.src inside the isolated layer);
        // replaying it with source-over would blend the translucent overlap
        // twice and fail this byte comparison.
        final firstBatch = [_dab(x: 9.5, y: 9.5, size: 12, color: 0x8040A0C0)];
        final secondBatch = [
          _dab(x: 12.5, y: 10.5, size: 12, color: 0x80C04010, sequence: 1),
        ];
        final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
        final model = ActiveStrokeOverlayModel();
        addTearDown(model.dispose);

        final firstRegion = rasterizer.blendFrom(firstBatch, from: 0)!;
        addRegion(model, rasterizer, firstRegion);
        final allDabs = [...firstBatch, ...secondBatch];
        final secondRegion = rasterizer.blendFrom(allDabs, from: 1)!;
        addRegion(model, rasterizer, secondRegion);

        _expectClose(
          await paintedCanvasBytes(model),
          _premultipliedCanvasBytes(rasterizer.pixels),
          'replacement replay',
          tolerance: 2,
        );
      },
    );

    test(
      'flattening replays identically to the accumulated region pictures',
      () async {
        final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
        final model = ActiveStrokeOverlayModel();
        addTearDown(model.dispose);
        final allDabs = <BrushDab>[];
        for (var batch = 0; batch < 3; batch += 1) {
          final from = allDabs.length;
          allDabs.addAll([
            for (var i = 0; i < 2; i += 1)
              _dab(
                x: 8.3 + batch * 3.7 + i * 1.9,
                y: 9.1 + batch * 2.4,
                sequence: from + i,
              ),
          ]);
          final region = rasterizer.blendFrom(allDabs, from: from)!;
          addRegion(model, rasterizer, region);
        }
        expect(model.pictures, hasLength(3));
        final accumulated = await paintedCanvasBytes(model);

        model.replaceWithFlattened(
          strokeRegionPicture(
            pixels: rasterizer.pixels,
            canvasWidth: _canvasWidth,
            region: rasterizer.strokeBounds!,
          ),
        );
        expect(model.pictures, hasLength(1));

        _expectExact(
          await paintedCanvasBytes(model),
          accumulated,
          'flattened replay',
        );
      },
    );

    test(
      'overlay composites onto committed artwork with source-over',
      () async {
        final baseDabs = [
          _dab(
            x: 6.5,
            y: 6.5,
            size: 6,
            color: 0xFF994411,
            opacity: 1.0,
            flow: 1.0,
            hardness: 1.0,
          ),
        ];
        final base = materializeBrushDabSequenceOnBitmapSurface(
          surface: BitmapSurface(canvasSize: _canvasSize, tileSize: 64),
          sequence: BrushDabSequence(baseDabs),
        ).surface;

        final strokeDabs = [
          _dab(
            x: 20.5,
            y: 20.5,
            size: 6,
            color: 0xFF2266AA,
            opacity: 1.0,
            flow: 1.0,
            hardness: 1.0,
          ),
        ];
        final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
        final region = rasterizer.blendFrom(strokeDabs, from: 0)!;
        final model = ActiveStrokeOverlayModel();
        addTearDown(model.dispose);
        addRegion(model, rasterizer, region);

        final painted = await paintedCanvasBytes(model, baseSurface: base);
        int offsetOf(int x, int y) => (y * _canvasWidth + x) * 4;
        // Committed artwork outside the stroke stays visible below the
        // overlay layer...
        expect(painted[offsetOf(6, 6) + 3], 255);
        expect(painted[offsetOf(6, 6)], 0x99);
        // ...and the live stroke paints its own pixels above it.
        expect(painted[offsetOf(20, 20) + 3], 255);
        expect(painted[offsetOf(20, 20)], 0x22);
      },
    );

    test('reset clears the pictures and dabs', () {
      final rasterizer = BrushLiveStrokeRasterizer(canvasSize: _canvasSize);
      final dabs = [_dab(x: 8.5, y: 8.5)];
      final region = rasterizer.blendFrom(dabs, from: 0)!;
      final model = ActiveStrokeOverlayModel();
      addTearDown(model.dispose);
      model.dabs.addAll(dabs);
      addRegion(model, rasterizer, region);
      expect(model.hasStrokeContent, isTrue);

      model.reset();

      expect(model.hasStrokeContent, isFalse);
      expect(model.pictures, isEmpty);
      expect(model.dabs, isEmpty);
    });
  });
}

/// Full-canvas expected bytes: the straight-alpha buffer premultiplied the
/// way Skia rasterizes the region pictures (mul-div-255 rounding).
Uint8List _premultipliedCanvasBytes(Uint8List straight) {
  final out = Uint8List(straight.length);
  for (var offset = 0; offset < straight.length; offset += 4) {
    final alpha = straight[offset + 3];
    if (alpha == 0) {
      continue;
    }
    out[offset] = _mul255Round(straight[offset], alpha);
    out[offset + 1] = _mul255Round(straight[offset + 1], alpha);
    out[offset + 2] = _mul255Round(straight[offset + 2], alpha);
    out[offset + 3] = alpha;
  }
  return out;
}

int _mul255Round(int value, int alpha) {
  final product = value * alpha + 128;
  return (product + (product >> 8)) >> 8;
}
