import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/dirty_tile_set.dart';
import '../models/tile_coord.dart';

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
      final baseTile =
          surface.tileAt(coord) ??
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
      final or = overlayPixels[offset];
      final og = overlayPixels[offset + 1];
      final ob = overlayPixels[offset + 2];
      if (oa == 255) {
        out[offset] = or;
        out[offset + 1] = og;
        out[offset + 2] = ob;
        out[offset + 3] = oa;
        continue;
      }

      final ba = out[offset + 3];
      final alpha = oa / 255.0;
      final inverse = 1.0 - alpha;
      out[offset] = _clampByte((or * alpha + out[offset] * inverse).round());
      out[offset + 1] = _clampByte(
        (og * alpha + out[offset + 1] * inverse).round(),
      );
      out[offset + 2] = _clampByte(
        (ob * alpha + out[offset + 2] * inverse).round(),
      );
      out[offset + 3] = _clampByte((oa + ba * inverse).round());
    }
    return baseTile.copyWith(pixels: out);
  }

  List<TileCoord> _sortedCoords(Iterable<TileCoord> coords) {
    return coords.toList()..sort((a, b) {
      final y = a.y.compareTo(b.y);
      if (y != 0) return y;
      return a.x.compareTo(b.x);
    });
  }
}

int _clampByte(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);
