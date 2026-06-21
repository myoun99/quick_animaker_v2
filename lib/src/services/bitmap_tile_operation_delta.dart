import '../models/bitmap_tile.dart';
import '../models/brush_pixel_blend_operation.dart';
import '../models/tile_delta.dart';
import '../models/tile_delta_command.dart';
import 'bitmap_tile_operation_apply.dart';

TileDeltaCommand? tileDeltaCommandForBitmapTileOperations({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
}) {
  final updatedTile = applyBrushPixelBlendOperationsToBitmapTile(
    tile: tile,
    operations: operations,
  );

  if (updatedTile == tile) return null;

  final delta = TileDelta.replaced(before: tile, after: updatedTile);
  return TileDeltaCommand(deltas: [delta]);
}
