import '../models/bitmap_surface.dart';
import '../models/bitmap_tile.dart';
import '../models/brush_dab_sequence.dart';
import '../models/rgba_color.dart';
import '../models/tile_coord.dart';
import '../models/tile_delta.dart';
import '../models/tile_delta_command.dart';
import '../models/brush_pixel_blend_operation.dart';
import 'bitmap_tile_operation_delta.dart';
import 'bitmap_tile_rgba.dart';
import 'brush_dab_sequence_blend.dart';

TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapSurface({
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

  if (operationsByCoord.isEmpty) return null;

  final coords = operationsByCoord.keys.toList()
    ..sort((a, b) {
      final yComparison = a.y.compareTo(b.y);
      if (yComparison != 0) return yComparison;
      return a.x.compareTo(b.x);
    });

  final deltas = <TileDelta>[];
  for (final coord in coords) {
    final existingTile = surface.tileAt(coord);
    final tile =
        existingTile ?? BitmapTile.blank(coord: coord, size: surface.tileSize);
    final command = tileDeltaCommandForBitmapTileOperations(
      tile: tile,
      operations: operationsByCoord[coord]!,
    );
    if (command == null) continue;

    final delta = command.deltas.single;
    if (existingTile == null) {
      deltas.add(TileDelta.created(delta.after!));
    } else {
      deltas.add(delta);
    }
  }

  if (deltas.isEmpty) return null;
  return TileDeltaCommand(deltas: deltas);
}
