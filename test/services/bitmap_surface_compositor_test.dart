import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/bitmap_tile.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_dab_sequence.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/dirty_tile_set.dart';
import 'package:quick_animaker_v2/src/models/rgba_color.dart';
import 'package:quick_animaker_v2/src/models/tile_coord.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_brush_commit.dart';
import 'package:quick_animaker_v2/src/services/bitmap_surface_compositor.dart';
import 'package:quick_animaker_v2/src/services/bitmap_tile_rgba.dart';
import 'package:quick_animaker_v2/src/services/rgba_blend.dart';

void main() {
  group('BitmapSurfaceCompositor', () {
    const compositor = BitmapSurfaceCompositor();

    test('preserves straight-alpha color over transparent base', () {
      final base = _blankSurface();
      final overlay = _surfaceWithPixel(
        const TileCoord(x: 0, y: 0),
        x: 0,
        y: 0,
        color: RgbaColor(r: 255, g: 0, b: 0, a: 128),
      );

      final result = compositor.composite(
        baseSurface: base,
        overlaySurface: overlay,
      );

      expect(_pixel(result, x: 0, y: 0), RgbaColor(r: 255, g: 0, b: 0, a: 128));
    });

    test('matches rgbaSourceOver for semi-transparent source over base', () {
      final destination = RgbaColor(r: 0, g: 0, b: 255, a: 192);
      final source = RgbaColor(r: 255, g: 0, b: 0, a: 128);
      final base = _surfaceWithPixel(
        const TileCoord(x: 0, y: 0),
        x: 0,
        y: 0,
        color: destination,
      );
      final overlay = _surfaceWithPixel(
        const TileCoord(x: 0, y: 0),
        x: 0,
        y: 0,
        color: source,
      );

      final result = compositor.composite(
        baseSurface: base,
        overlaySurface: overlay,
      );
      final expected = rgbaSourceOver(
        source: source,
        destination: destination,
        opacity: 1.0,
        flow: 1.0,
      );

      expect(_pixel(result, x: 0, y: 0), expected);
    });

    test('matches direct sequential brush rasterization for command surfaces', () {
      final blank = _blankSurface();
      final first = BrushDabSequence([
        _dab(x: 1, y: 1, color: 0x80FF0000, sequence: 1),
      ]);
      final second = BrushDabSequence([
        _dab(x: 1, y: 1, color: 0x800000FF, sequence: 2),
      ]);

      final directFirst = materializeBrushDabSequenceOnBitmapSurface(
        surface: blank,
        sequence: first,
      ).surface;
      final direct = materializeBrushDabSequenceOnBitmapSurface(
        surface: directFirst,
        sequence: second,
      ).surface;

      final firstCommandSurface = materializeBrushDabSequenceOnBitmapSurface(
        surface: blank,
        sequence: first,
      ).surface;
      final secondCommandSurface = materializeBrushDabSequenceOnBitmapSurface(
        surface: blank,
        sequence: second,
      ).surface;
      final compositedFirst = compositor.composite(
        baseSurface: blank,
        overlaySurface: firstCommandSurface,
      );
      final composited = compositor.composite(
        baseSurface: compositedFirst,
        overlaySurface: secondCommandSurface,
      );

      expect(_pixel(composited, x: 1, y: 1), _pixel(direct, x: 1, y: 1));
    });

    test('compositeTiles only reads requested dirty tiles', () {
      final base = _blankSurface();
      final overlay = _surfaceWithPixel(
        const TileCoord(x: 0, y: 0),
        x: 0,
        y: 0,
        color: RgbaColor(r: 255, g: 0, b: 0, a: 255),
      );

      final result = compositor.compositeTiles(
        baseSurface: base,
        overlaySurface: overlay,
        dirtyTiles: DirtyTileSet.empty(),
      );

      expect(result.tiles, isEmpty);
    });
  });
}

BitmapSurface _blankSurface() => BitmapSurface(
  canvasSize: CanvasSize(width: 4, height: 4),
  tileSize: 2,
);

BitmapSurface _surfaceWithPixel(
  TileCoord coord, {
  required int x,
  required int y,
  required RgbaColor color,
}) {
  final tile = writeRgbaColorToBitmapTile(
    tile: BitmapTile.blank(coord: coord, size: 2),
    x: x,
    y: y,
    color: color,
  );
  return _blankSurface().putTile(tile);
}

RgbaColor _pixel(BitmapSurface surface, {required int x, required int y}) {
  final coord = TileCoord(x: x ~/ surface.tileSize, y: y ~/ surface.tileSize);
  final tile = surface.tileAt(coord);
  if (tile == null) return RgbaColor(r: 0, g: 0, b: 0, a: 0);
  return readRgbaColorFromBitmapTile(
    tile: tile,
    x: x - coord.x * surface.tileSize,
    y: y - coord.y * surface.tileSize,
  );
}

BrushDab _dab({
  required double x,
  required double y,
  required int color,
  required int sequence,
}) {
  return BrushDab(
    center: CanvasPoint(x: x, y: y),
    color: color,
    size: 1,
    opacity: 1,
    flow: 1,
    hardness: 1,
    tipShape: BrushTipShape.round,
    pressure: 1,
    sequence: sequence,
  );
}
