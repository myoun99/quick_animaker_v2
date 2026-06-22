import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';

void main() {
  final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
  final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
  final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
  final purple = RgbaColor(r: 128, g: 0, b: 128, a: 255);

  BitmapTile blankTile({int tileX = 0, int tileY = 0, int size = 2}) {
    return BitmapTile.blank(
      coord: TileCoord(x: tileX, y: tileY),
      size: size,
    );
  }

  BrushDab onePixelDab({
    required double globalX,
    required double globalY,
    int color = 0xFFFF0000,
    double opacity = 1,
    double flow = 1,
    int sequence = 0,
  }) {
    return BrushDab(
      center: CanvasPoint(x: globalX + 0.5, y: globalY + 0.5),
      color: color,
      size: 1,
      opacity: opacity,
      flow: flow,
      hardness: 1,
      tipShape: BrushTipShape.round,
      pressure: 1,
      sequence: sequence,
    );
  }

  BrushDab squareDab({
    required double centerX,
    required double centerY,
    int color = 0xFFFF0000,
    int sequence = 0,
  }) {
    return BrushDab(
      center: CanvasPoint(x: centerX, y: centerY),
      color: color,
      size: 2,
      opacity: 1,
      flow: 1,
      hardness: 1,
      tipShape: BrushTipShape.square,
      pressure: 1,
      sequence: sequence,
    );
  }

  group('tileDeltaCommandForBrushDabSequenceOnBitmapTile', () {
    test('returns null for empty BrushDabSequence', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(),
        sequence: BrushDabSequence(),
      );

      expect(command, isNull);
    });

    test('returns null for non-effective dab', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(),
        sequence: BrushDabSequence([
          onePixelDab(globalX: 0, globalY: 0, opacity: 0),
        ]),
      );

      expect(command, isNull);
    });

    test('returns null when dab affects only pixels outside tile', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(size: 2),
        sequence: BrushDabSequence([onePixelDab(globalX: 3, globalY: 0)]),
      );

      expect(command, isNull);
    });

    test('returns TileDeltaCommand for one-pixel dab over transparent tile', () {
      final tile = blankTile();

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 1, globalY: 0)]),
      );

      expect(command, isNotNull);
      expect(command!.length, 1);
      final delta = command.deltas.single;
      expect(delta.isReplacement, isTrue);
      expect(delta.before, tile);
      expect(readRgbaColorFromBitmapTile(tile: delta.after!, x: 1, y: 0), red);
    });

    test('does not mutate original tile', () {
      final tile = blankTile();
      final originalPixels = tile.pixels;

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 1, globalY: 0)]),
      )!;

      expect(tile.pixels, originalPixels);
      expect(readRgbaColorFromBitmapTile(tile: tile, x: 1, y: 0), transparent);
      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 1,
          y: 0,
        ),
        red,
      );
    });

    test('respects existing destination color inside tile', () {
      final tile = writeRgbaColorToBitmapTile(
        tile: blankTile(),
        x: 0,
        y: 0,
        color: blue,
      );

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([
          onePixelDab(globalX: 0, globalY: 0, opacity: 0.5),
        ]),
      )!;

      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 0,
          y: 0,
        ),
        purple,
      );
    });

    test('maps global dab coordinates to local tile pixels', () {
      final tile = blankTile(tileX: 2, tileY: 3, size: 4);

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 8, globalY: 12)]),
      )!;

      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 0,
          y: 0,
        ),
        red,
      );
    });

    test('does not treat global dab coordinates as local tile coordinates', () {
      final tile = blankTile(tileX: 2, tileY: 3, size: 4);

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 8, globalY: 12)]),
      )!;

      expect(command.deltas.single.after!.size, 4);
      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 0,
          y: 0,
        ),
        red,
      );
    });

    test('handles repeated same-pixel dabs using accumulated operation colors', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(),
        sequence: BrushDabSequence([
          onePixelDab(globalX: 0, globalY: 0, color: 0xFFFF0000, sequence: 0),
          onePixelDab(
            globalX: 0,
            globalY: 0,
            color: 0xFF0000FF,
            opacity: 0.5,
            sequence: 1,
          ),
        ]),
      )!;

      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 0,
          y: 0,
        ),
        purple,
      );
    });

    test('handles dab crossing tile boundary by applying only in-tile pixel changes', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(size: 2),
        sequence: BrushDabSequence([squareDab(centerX: 2, centerY: 0.5)]),
      )!;
      final after = command.deltas.single.after!;

      expect(readRgbaColorFromBitmapTile(tile: after, x: 1, y: 0), red);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 0, y: 0), transparent);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 0, y: 1), transparent);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 1, y: 1), transparent);
    });

    test('preserves updated tile coord', () {
      final tile = blankTile(tileX: 3, tileY: 4, size: 2);

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 6, globalY: 8)]),
      )!;

      expect(command.deltas.single.after!.coord, tile.coord);
    });

    test('preserves updated tile size', () {
      final tile = blankTile(tileX: 3, tileY: 4, size: 2);

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: tile,
        sequence: BrushDabSequence([onePixelDab(globalX: 6, globalY: 8)]),
      )!;

      expect(command.deltas.single.after!.size, tile.size);
    });

    test('does not mutate BrushDabSequence', () {
      final sequence = BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]);
      final before = BrushDabSequence(sequence.dabs);

      tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(),
        sequence: sequence,
      );

      expect(sequence, before);
    });

    test('does not mutate BrushDab', () {
      final dab = onePixelDab(globalX: 0, globalY: 0);
      final before = dab.copyWith();

      tileDeltaCommandForBrushDabSequenceOnBitmapTile(
        tile: blankTile(),
        sequence: BrushDabSequence([dab]),
      );

      expect(dab, before);
    });
  });
}
