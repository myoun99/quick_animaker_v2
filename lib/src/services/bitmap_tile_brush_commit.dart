import '../models/bitmap_tile.dart';
import '../models/brush_dab_sequence.dart';
import '../models/rgba_color.dart';
import '../models/tile_delta_command.dart';
import 'bitmap_tile_operation_delta.dart';
import 'bitmap_tile_rgba.dart';
import 'brush_dab_sequence_blend.dart';

TileDeltaCommand? tileDeltaCommandForBrushDabSequenceOnBitmapTile({
  required BitmapTile tile,
  required BrushDabSequence sequence,
}) {
  final tileGlobalLeft = tile.coord.x * tile.size;
  final tileGlobalTop = tile.coord.y * tile.size;
  final tileGlobalRightExclusive = tileGlobalLeft + tile.size;
  final tileGlobalBottomExclusive = tileGlobalTop + tile.size;

  RgbaColor destinationAt(int x, int y) {
    if (x < tileGlobalLeft ||
        x >= tileGlobalRightExclusive ||
        y < tileGlobalTop ||
        y >= tileGlobalBottomExclusive) {
      return RgbaColor(r: 0, g: 0, b: 0, a: 0);
    }

    return readRgbaColorFromBitmapTile(
      tile: tile,
      x: x - tileGlobalLeft,
      y: y - tileGlobalTop,
    );
  }

  final operations = brushPixelBlendOperationsForDabSequence(
    sequence: sequence,
    destinationAt: destinationAt,
  );

  return tileDeltaCommandForBitmapTileOperations(
    tile: tile,
    operations: operations,
  );
}
