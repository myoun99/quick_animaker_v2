import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';

void main() {
  final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);
  final red = RgbaColor(r: 255, g: 0, b: 0, a: 255);
  final blue = RgbaColor(r: 0, g: 0, b: 255, a: 255);
  final purple = RgbaColor(r: 128, g: 0, b: 128, a: 255);

  BitmapSurface surface({
    int width = 4,
    int height = 4,
    int tileSize = 2,
    Map<TileCoord, BitmapTile> tiles = const {},
  }) {
    return BitmapSurface(
      canvasSize: CanvasSize(width: width, height: height),
      tileSize: tileSize,
      tiles: tiles,
    );
  }

  BitmapTile blankTile({required int tileX, required int tileY, int size = 2}) {
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

  group('tileDeltaCommandForBrushDabSequenceOnBitmapSurface', () {
    test('returns null for empty BrushDabSequence', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence(),
      );

      expect(command, isNull);
    });

    test('returns null for non-effective dab', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([
          onePixelDab(globalX: 0, globalY: 0, opacity: 0),
        ]),
      );

      expect(command, isNull);
    });

    test('returns null when dab affects only pixels outside surface', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(width: 2, height: 2, tileSize: 2),
        sequence: BrushDabSequence([onePixelDab(globalX: 3, globalY: 0)]),
      );

      expect(command, isNull);
    });

    test('creates replacement delta for existing tile', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(tiles: {existing.coord: existing}),
        sequence: BrushDabSequence([onePixelDab(globalX: 1, globalY: 0)]),
      )!;

      final delta = command.deltas.single;
      expect(delta.isReplacement, isTrue);
      expect(delta.before, existing);
      expect(readRgbaColorFromBitmapTile(tile: delta.after!, x: 1, y: 0), red);
    });

    test('creates creation delta for missing tile', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 2, globalY: 0)]),
      )!;

      final delta = command.deltas.single;
      expect(delta.isCreation, isTrue);
      expect(delta.before, isNull);
      expect(delta.after!.coord, TileCoord(x: 1, y: 0));
      expect(readRgbaColorFromBitmapTile(tile: delta.after!, x: 0, y: 0), red);
    });

    test(
      'does not create replacement delta with blank before for missing tile',
      () {
        final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
          surface: surface(),
          sequence: BrushDabSequence([onePixelDab(globalX: 2, globalY: 0)]),
        )!;

        final delta = command.deltas.single;
        expect(delta.isCreation, isTrue);
        expect(delta.isReplacement, isFalse);
        expect(delta.before, isNull);
      },
    );

    test('command contains multiple deltas for multi-tile dab', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([squareDab(centerX: 2, centerY: 1)]),
      )!;

      expect(command.length, 2);
      expect(command.deltas.map((delta) => delta.coord), [
        TileCoord(x: 0, y: 0),
        TileCoord(x: 1, y: 0),
      ]);
    });

    test('respects existing destination color on existing tile', () {
      final existing = writeRgbaColorToBitmapTile(
        tile: blankTile(tileX: 0, tileY: 0),
        x: 0,
        y: 0,
        color: blue,
      );

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(tiles: {existing.coord: existing}),
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

    test('treats missing tile destination as transparent', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]),
      )!;

      expect(command.deltas.single.isCreation, isTrue);
      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 0,
          y: 0,
        ),
        red,
      );
    });

    test('ignores pixels outside canvas bounds', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(width: 2, height: 2, tileSize: 2),
        sequence: BrushDabSequence([squareDab(centerX: 2, centerY: 0.5)]),
      )!;

      expect(command.length, 1);
      final after = command.deltas.single.after!;
      expect(readRgbaColorFromBitmapTile(tile: after, x: 1, y: 0), red);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 1, y: 1), red);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 0, y: 0), transparent);
      expect(readRgbaColorFromBitmapTile(tile: after, x: 0, y: 1), transparent);
    });

    test('does not mutate original BitmapSurface', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final original = surface(tiles: {existing.coord: existing});

      tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: original,
        sequence: BrushDabSequence([onePixelDab(globalX: 1, globalY: 0)]),
      );

      expect(original, surface(tiles: {existing.coord: existing}));
      expect(
        readRgbaColorFromBitmapTile(
          tile: original.tileAt(existing.coord)!,
          x: 1,
          y: 0,
        ),
        transparent,
      );
    });

    test('does not mutate existing BitmapTile', () {
      final existing = blankTile(tileX: 0, tileY: 0);
      final originalPixels = existing.pixels;

      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(tiles: {existing.coord: existing}),
        sequence: BrushDabSequence([onePixelDab(globalX: 1, globalY: 0)]),
      )!;

      expect(existing.pixels, originalPixels);
      expect(
        readRgbaColorFromBitmapTile(tile: existing, x: 1, y: 0),
        transparent,
      );
      expect(
        readRgbaColorFromBitmapTile(
          tile: command.deltas.single.after!,
          x: 1,
          y: 0,
        ),
        red,
      );
    });

    test('applyAfter produces expected surface', () {
      final original = surface();
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: original,
        sequence: BrushDabSequence([onePixelDab(globalX: 2, globalY: 0)]),
      )!;

      final updated = command.applyAfter(original);

      expect(
        updated.tileAt(TileCoord(x: 1, y: 0)),
        command.deltas.single.after,
      );
      expect(
        readRgbaColorFromBitmapTile(
          tile: updated.tileAt(TileCoord(x: 1, y: 0))!,
          x: 0,
          y: 0,
        ),
        red,
      );
    });

    test('applyBefore restores original surface', () {
      final original = surface();
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: original,
        sequence: BrushDabSequence([onePixelDab(globalX: 2, globalY: 0)]),
      )!;

      final updated = command.applyAfter(original);
      final restored = command.applyBefore(updated);

      expect(restored, original);
    });

    test('preserves surface tileSize expectations through deltas', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(width: 6, height: 6, tileSize: 3),
        sequence: BrushDabSequence([onePixelDab(globalX: 3, globalY: 0)]),
      )!;

      expect(command.deltas.single.after!.size, 3);
    });

    test('groups deltas deterministically by tile coord', () {
      final command = tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(width: 6, height: 6, tileSize: 2),
        sequence: BrushDabSequence([
          onePixelDab(globalX: 4, globalY: 2, sequence: 0),
          onePixelDab(globalX: 2, globalY: 0, sequence: 1),
          onePixelDab(globalX: 0, globalY: 2, sequence: 2),
        ]),
      )!;

      expect(command.deltas.map((delta) => delta.coord), [
        TileCoord(x: 1, y: 0),
        TileCoord(x: 0, y: 1),
        TileCoord(x: 2, y: 1),
      ]);
    });

    test('does not mutate BrushDabSequence', () {
      final sequence = BrushDabSequence([onePixelDab(globalX: 0, globalY: 0)]);
      final beforeJson = sequence.toJson();

      tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: sequence,
      );

      expect(sequence.toJson(), beforeJson);
    });

    test('does not mutate BrushDab', () {
      final dab = onePixelDab(globalX: 0, globalY: 0);
      final beforeJson = dab.toJson();

      tileDeltaCommandForBrushDabSequenceOnBitmapSurface(
        surface: surface(),
        sequence: BrushDabSequence([dab]),
      );

      expect(dab.toJson(), beforeJson);
    });
  });
}
