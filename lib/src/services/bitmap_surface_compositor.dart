import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/dirty_tile_set.dart';
import '../models/rgba_color.dart';
import '../models/tile_coord.dart';
import 'rgba_blend.dart';

/// Composites derived bitmap surfaces without re-rasterizing source commands.
class BitmapSurfaceCompositor {
  const BitmapSurfaceCompositor();

  BitmapSurface composite({
    required BitmapSurface baseSurface,
    required BitmapSurface overlaySurface,
  }) {
    return compositeTiles(
      baseSurface: baseSurface,
      overlaySurface: overlaySurface,
      dirtyTiles: DirtyTileSet(overlaySurface.tiles.keys),
    );
  }

  BitmapSurface compositeTiles({
    required BitmapSurface baseSurface,
    required BitmapSurface overlaySurface,
    required DirtyTileSet dirtyTiles,
  }) {
    var surface = baseSurface;
    for (final coord in _sortedCoords(dirtyTiles.coords)) {
      final overlayTile = overlaySurface.tileAt(coord);
      if (overlayTile == null || overlayTile.isFullyTransparent) {
        continue;
      }
      final baseTile = surface.tileAt(coord) ??
          BitmapTile.blank(coord: coord, size: surface.tileSize);
      surface = surface.putTile(_compositeTile(baseTile, overlayTile));
    }
    return surface;
  }

  BitmapTile _compositeTile(BitmapTile baseTile, BitmapTile overlayTile) {
    final basePixels = baseTile.pixels;
    final overlayPixels = overlayTile.pixels;
    final out = Uint8List.fromList(basePixels);

    for (
      var offset = 0;
      offset < out.length;
      offset += BitmapTile.bytesPerPixel
    ) {
      final oa = overlayPixels[offset + 3];
      if (oa == 0) continue;
      final source = RgbaColor(
        r: overlayPixels[offset],
        g: overlayPixels[offset + 1],
        b: overlayPixels[offset + 2],
        a: oa,
      );
      final destination = RgbaColor(
        r: out[offset],
        g: out[offset + 1],
        b: out[offset + 2],
        a: out[offset + 3],
      );
      final result = rgbaSourceOver(
        source: source,
        destination: destination,
        opacity: 1.0,
        flow: 1.0,
      );
      out[offset] = result.r;
      out[offset + 1] = result.g;
      out[offset + 2] = result.b;
      out[offset + 3] = result.a;
    }
    return baseTile.copyWith(pixels: out);
  }

  List<TileCoord> _sortedCoords(Iterable<TileCoord> coords) {
    return coords.toList()
      ..sort((a, b) {
        final y = a.y.compareTo(b.y);
        if (y != 0) return y;
        return a.x.compareTo(b.x);
      });
  }
}
