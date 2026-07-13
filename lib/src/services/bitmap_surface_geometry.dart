import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/canvas_size.dart';
import '../models/tile_coord.dart';

/// Raster geometry ops for baked surfaces (R19 bake-only): canvas resize
/// and anchored-content translation operate on PIXELS now — the raster
/// is the truth. A resize is top-left anchored: in-grid tiles keep their
/// coords, tiles beyond the new grid drop (raster crop, PS semantics).
/// The resize COMMAND keeps a reference snapshot of the pre-resize baked
/// surfaces, so its undo restores cropped pixels exactly.
BitmapSurface resizeBitmapSurfaceCanvas(
  BitmapSurface surface,
  CanvasSize canvasSize,
) {
  if (surface.canvasSize == canvasSize) {
    return surface;
  }
  final tileSize = surface.tileSize;
  return BitmapSurface(
    canvasSize: canvasSize,
    tileSize: tileSize,
    tiles: {
      for (final entry in surface.tiles.entries)
        if (entry.key.x * tileSize < canvasSize.width &&
            entry.key.y * tileSize < canvasSize.height)
          entry.key: entry.value,
    },
  );
}

/// Translates the surface's pixels by integer ([dx], [dy]) and adopts
/// [canvasSize] — the anchored-resize blit. Whole-tile shifts rebase
/// coordinates for free; fractional-of-a-tile shifts blit each input
/// tile's rows into up to four output tiles. Fully transparent output
/// tiles are dropped.
BitmapSurface translateBitmapSurface(
  BitmapSurface surface, {
  required int dx,
  required int dy,
  required CanvasSize canvasSize,
}) {
  if (dx == 0 && dy == 0) {
    return resizeBitmapSurfaceCanvas(surface, canvasSize);
  }
  final tileSize = surface.tileSize;

  if (dx % tileSize == 0 && dy % tileSize == 0) {
    final tileDx = dx ~/ tileSize;
    final tileDy = dy ~/ tileSize;
    final rebased = <TileCoord, BitmapTile>{};
    for (final entry in surface.tiles.entries) {
      final coord = TileCoord(x: entry.key.x + tileDx, y: entry.key.y + tileDy);
      rebased[coord] = entry.value.copyWith(coord: coord);
    }
    return resizeBitmapSurfaceCanvas(
      BitmapSurface(
        canvasSize: surface.canvasSize,
        tileSize: tileSize,
        tiles: rebased,
      ),
      canvasSize,
    );
  }

  final rowBytes = tileSize * BitmapTile.bytesPerPixel;
  final buffers = <TileCoord, Uint8List>{};

  // The output grid is unbounded on the positive side (overhang tiles
  // are part of the model); only pixels shifted into negative canvas
  // space are unrepresentable and clip — the anchored-resize command
  // snapshots baked references for its undo, so nothing is lost across
  // an undo round trip.
  Uint8List? bufferFor(int tileX, int tileY) {
    if (tileX < 0 || tileY < 0) {
      return null;
    }
    return buffers.putIfAbsent(
      TileCoord(x: tileX, y: tileY),
      () => Uint8List(tileSize * rowBytes),
    );
  }

  for (final tile in surface.tiles.values) {
    final pixels = tile.pixels;
    final sourceLeft = tile.coord.x * tileSize + dx;
    final sourceTop = tile.coord.y * tileSize + dy;
    for (var row = 0; row < tileSize; row += 1) {
      final worldY = sourceTop + row;
      if (worldY < 0) {
        continue;
      }
      final tileY = worldY ~/ tileSize;
      final localY = worldY - tileY * tileSize;
      // The row lands in up to two horizontal output tiles.
      var worldX = sourceLeft;
      var sourceOffset = row * rowBytes;
      var remaining = tileSize;
      while (remaining > 0) {
        if (worldX < 0) {
          final skip = -worldX;
          final clipped = skip > remaining ? remaining : skip;
          worldX += clipped;
          sourceOffset += clipped * BitmapTile.bytesPerPixel;
          remaining -= clipped;
          continue;
        }
        final tileX = worldX ~/ tileSize;
        final localX = worldX - tileX * tileSize;
        final span = (tileSize - localX) < remaining
            ? (tileSize - localX)
            : remaining;
        final target = bufferFor(tileX, tileY);
        if (target != null) {
          target.setRange(
            (localY * tileSize + localX) * BitmapTile.bytesPerPixel,
            (localY * tileSize + localX + span) * BitmapTile.bytesPerPixel,
            pixels,
            sourceOffset,
          );
        }
        worldX += span;
        sourceOffset += span * BitmapTile.bytesPerPixel;
        remaining -= span;
      }
    }
  }

  final tiles = <TileCoord, BitmapTile>{};
  for (final entry in buffers.entries) {
    final tile = BitmapTile(
      coord: entry.key,
      size: tileSize,
      pixels: entry.value,
    );
    if (!tile.isFullyTransparent) {
      tiles[entry.key] = tile;
    }
  }
  return BitmapSurface(
    canvasSize: canvasSize,
    tileSize: tileSize,
    tiles: tiles,
  );
}
