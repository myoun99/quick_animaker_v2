import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/brush_dab_sequence.dart';
import '../models/dirty_tile_set.dart';
import '../models/rgba_color.dart';
import '../models/tile_coord.dart';
import '../models/brush_pixel_blend_operation.dart';
import 'bitmap_tile_operation_materialization.dart';
import 'bitmap_tile_rgba.dart';
import 'brush_dab_sequence_blend.dart';

class BrushSurfaceMaterialization {
  const BrushSurfaceMaterialization({
    required this.surface,
    required this.dirtyTiles,
  });

  final BitmapSurface surface;
  final DirtyTileSet dirtyTiles;

  bool get hasChanges => dirtyTiles.isNotEmpty;
}

BrushSurfaceMaterialization materializeBrushDabSequenceOnBitmapSurface({
  required BitmapSurface surface,
  required BrushDabSequence sequence,
}) {
  final transparent = RgbaColor(r: 0, g: 0, b: 0, a: 0);

  RgbaColor destinationAt(int x, int y) {
    if (x < 0 ||
        y < 0 ||
        x >= surface.canvasSize.width ||
        y >= surface.canvasSize.height) {
      return transparent;
    }

    final tileX = x ~/ surface.tileSize;
    final tileY = y ~/ surface.tileSize;
    final coord = TileCoord(x: tileX, y: tileY);
    final tile = surface.tileAt(coord);
    if (tile == null) return transparent;

    return readRgbaColorFromBitmapTile(
      tile: tile,
      x: x - tileX * surface.tileSize,
      y: y - tileY * surface.tileSize,
    );
  }

  final operations = brushPixelBlendOperationsForDabSequence(
    sequence: sequence,
    destinationAt: destinationAt,
  );

  final operationsByCoord = <TileCoord, List<BrushPixelBlendOperation>>{};
  for (final operation in operations) {
    if (operation.x < 0 ||
        operation.y < 0 ||
        operation.x >= surface.canvasSize.width ||
        operation.y >= surface.canvasSize.height) {
      continue;
    }

    final coord = TileCoord(
      x: operation.x ~/ surface.tileSize,
      y: operation.y ~/ surface.tileSize,
    );
    operationsByCoord.putIfAbsent(coord, () => []).add(operation);
  }

  if (operationsByCoord.isEmpty) {
    return BrushSurfaceMaterialization(
      surface: surface,
      dirtyTiles: DirtyTileSet.empty(),
    );
  }

  final coords = operationsByCoord.keys.toList()
    ..sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return a.x.compareTo(b.x);
    });

  var updatedSurface = surface;
  var dirtyTiles = DirtyTileSet.empty();
  for (final coord in coords) {
    final existingTile = surface.tileAt(coord);
    final tile =
        existingTile ?? BitmapTile.blank(coord: coord, size: surface.tileSize);
    final updatedTile = materializedBitmapTileForOperations(
      tile: tile,
      operations: operationsByCoord[coord]!,
    );
    if (updatedTile == null) continue;
    updatedSurface = updatedSurface.putTile(updatedTile);
    dirtyTiles = dirtyTiles.add(coord);
  }

  return BrushSurfaceMaterialization(
    surface: updatedSurface,
    dirtyTiles: dirtyTiles,
  );
}
