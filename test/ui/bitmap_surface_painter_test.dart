import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay_painter.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_surface_painter.dart';

void main() {
  group('BitmapSurfacePainter', () {
    test('repaints when surface or transparent background setting changes', () {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
      );
      final same = BitmapSurfacePainter(surface: surface);

      expect(
        BitmapSurfacePainter(surface: surface).shouldRepaint(same),
        isFalse,
      );
      expect(
        BitmapSurfacePainter(
          surface: surface,
          showTransparentBackground: false,
        ).shouldRepaint(same),
        isTrue,
      );
      expect(
        BitmapSurfacePainter(
          surface: surface.copyWith(tileSize: 1),
        ).shouldRepaint(same),
        isTrue,
      );
    });

    test('does not depend on active stroke path or overlay state', () {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 2, height: 2),
      );
      final painter = BitmapSurfacePainter(surface: surface);

      expect(
        painter.shouldRepaint(BitmapSurfacePainter(surface: surface)),
        isFalse,
      );
    });

    test('active overlay repaints when active stroke path version changes', () {
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(1, 1);
      final dab = _dab(0, 0);
      final oldPainter = ActiveStrokeOverlayPainter(
        activeStrokePath: path,
        activeStrokePathDab: dab,
        activeStrokePathVersion: 1,
      );

      expect(
        ActiveStrokeOverlayPainter(
          activeStrokePath: path,
          activeStrokePathDab: dab,
          activeStrokePathVersion: 2,
        ).shouldRepaint(oldPainter),
        isTrue,
      );
    });

    test('draws RGBA tile pixels at global tile coordinates', () async {
      final firstTile = _tile(
        coord: TileCoord(x: 0, y: 0),
        size: 2,
        colors: {
          const _Point(1, 0): RgbaColor(r: 255, g: 0, b: 0, a: 255),
          const _Point(0, 1): RgbaColor(r: 0, g: 255, b: 0, a: 255),
        },
      );
      final secondTile = _tile(
        coord: TileCoord(x: 1, y: 0),
        size: 2,
        colors: {const _Point(0, 1): RgbaColor(r: 0, g: 0, b: 255, a: 255)},
      );
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 4, height: 2),
        tileSize: 2,
        tiles: {firstTile.coord: firstTile, secondTile.coord: secondTile},
      );

      final pixels = await _paintPixels(
        BitmapSurfacePainter(
          surface: surface,
          showTransparentBackground: false,
        ),
        width: 4,
        height: 2,
      );

      expect(_rgbaAt(pixels, width: 4, x: 1, y: 0), [255, 0, 0, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 0, y: 1), [0, 255, 0, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 2, y: 1), [0, 0, 255, 255]);
      expect(_rgbaAt(pixels, width: 4, x: 0, y: 0), [0, 0, 0, 0]);
    });

    test(
      'paints sampled source dabs without connecting separate strokes',
      () async {
        final surface = BitmapSurface(
          canvasSize: CanvasSize(width: 12, height: 3),
        );

        final pixels = await _paintPixels(
          BitmapSurfacePainter(
            surface: surface,
            showTransparentBackground: false,
            committedSourceDabStrokes: [
              [_dab(1, 1), _dab(2, 1), _dab(3, 1)],
              [_dab(10, 1)],
            ],
          ),
          width: 12,
          height: 3,
        );

        expect(_rgbaAt(pixels, width: 12, x: 1, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 12, x: 2, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 12, x: 3, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 12, x: 5, y: 1).last, 0);
        expect(_rgbaAt(pixels, width: 12, x: 7, y: 1).last, 0);
        expect(_rgbaAt(pixels, width: 12, x: 10, y: 1).last, greaterThan(0));
      },
    );

    test(
      'draws sampled active stroke overlay dabs for live feedback',
      () async {
        final pixels = await _paintPixels(
          ActiveStrokeOverlayPainter(
            activeStrokeOverlay: [_dab(1, 1), _dab(3, 1), _dab(6, 1)],
          ),
          width: 8,
          height: 3,
        );

        expect(_rgbaAt(pixels, width: 8, x: 1, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 8, x: 3, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 8, x: 6, y: 1).last, greaterThan(0));
        expect(_rgbaAt(pixels, width: 8, x: 4, y: 1).last, 0);
      },
    );

    test('draws deterministic neutral background when enabled', () async {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 1, height: 1),
      );

      final pixels = await _paintPixels(
        BitmapSurfacePainter(surface: surface),
        width: 1,
        height: 1,
      );

      expect(_rgbaAt(pixels, width: 1, x: 0, y: 0), [237, 237, 237, 255]);
    });
  });
}

BitmapTile _tile({
  required TileCoord coord,
  required int size,
  required Map<_Point, RgbaColor> colors,
}) {
  var tile = BitmapTile.blank(coord: coord, size: size);
  for (final entry in colors.entries) {
    tile = writeRgbaColorToBitmapTile(
      tile: tile,
      x: entry.key.x,
      y: entry.key.y,
      color: entry.value,
    );
  }
  return tile;
}

Future<Uint8List> _paintPixels(
  CustomPainter painter, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return byteData!.buffer.asUint8List();
}

List<int> _rgbaAt(
  Uint8List pixels, {
  required int width,
  required int x,
  required int y,
}) {
  final offset = (y * width + x) * 4;
  return pixels.sublist(offset, offset + 4);
}

BrushDab _dab(double x, double y) => BrushDab(
  center: CanvasPoint(x: x, y: y),
  color: 0xFF000000,
  size: 1,
  opacity: 1,
  flow: 1,
  hardness: 1,
  tipShape: BrushTipShape.round,
  pressure: 1,
  sequence: x.round(),
);

class _Point {
  const _Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}
