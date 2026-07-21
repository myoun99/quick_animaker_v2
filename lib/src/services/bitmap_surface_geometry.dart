import 'dart:typed_data';

import '../core/floor_math.dart';
import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/canvas_size.dart';
import '../models/pasteboard_bounds.dart';
import '../models/tile_coord.dart';

/// Raster geometry ops for baked surfaces (R19 bake-only): canvas resize
/// and anchored-content translation operate on PIXELS now — the raster
/// is the truth. A resize is top-left anchored: in-bounds tiles keep
/// their coords, tiles beyond the new PASTEBOARD drop (raster crop, PS
/// semantics — the pasteboard shrinks with the canvas). The resize
/// COMMAND keeps a reference snapshot of the pre-resize baked surfaces,
/// so its undo restores cropped pixels exactly.
BitmapSurface resizeBitmapSurfaceCanvas(
  BitmapSurface surface,
  CanvasSize canvasSize,
) {
  if (surface.canvasSize == canvasSize) {
    return surface;
  }
  final tileSize = surface.tileSize;
  final tileXMin = canvasSize.pasteboardTileXMin(tileSize);
  final tileYMin = canvasSize.pasteboardTileYMin(tileSize);
  final tileXEnd = canvasSize.pasteboardTileXEndExclusive(tileSize);
  final tileYEnd = canvasSize.pasteboardTileYEndExclusive(tileSize);
  return BitmapSurface(
    canvasSize: canvasSize,
    tileSize: tileSize,
    tiles: {
      for (final entry in surface.tiles.entries)
        if (entry.key.x >= tileXMin &&
            entry.key.y >= tileYMin &&
            entry.key.x < tileXEnd &&
            entry.key.y < tileYEnd)
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

  // The output is bounded by the TARGET canvas's pasteboard; pixels
  // shifted beyond it clip — the anchored-resize command snapshots baked
  // references for its undo, so nothing is lost across an undo round
  // trip.
  final outTileXMin = canvasSize.pasteboardTileXMin(tileSize);
  final outTileYMin = canvasSize.pasteboardTileYMin(tileSize);
  final outTileXEnd = canvasSize.pasteboardTileXEndExclusive(tileSize);
  final outTileYEnd = canvasSize.pasteboardTileYEndExclusive(tileSize);
  final pasteboardLeft = canvasSize.pasteboardLeft;
  final pasteboardTop = canvasSize.pasteboardTop;
  Uint8List? bufferFor(int tileX, int tileY) {
    if (tileX < outTileXMin ||
        tileY < outTileYMin ||
        tileX >= outTileXEnd ||
        tileY >= outTileYEnd) {
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
      if (worldY < pasteboardTop) {
        continue;
      }
      final tileY = floorDiv(worldY, tileSize);
      final localY = worldY - tileY * tileSize;
      // The row lands in up to two horizontal output tiles.
      var worldX = sourceLeft;
      var sourceOffset = row * rowBytes;
      var remaining = tileSize;
      while (remaining > 0) {
        if (worldX < pasteboardLeft) {
          final skip = pasteboardLeft - worldX;
          final clipped = skip > remaining ? remaining : skip;
          worldX += clipped;
          sourceOffset += clipped * BitmapTile.bytesPerPixel;
          remaining -= clipped;
          continue;
        }
        final tileX = floorDiv(worldX, tileSize);
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
