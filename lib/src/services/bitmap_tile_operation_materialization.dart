import '../models/bitmap_tile.dart';
import '../models/brush_pixel_blend_operation.dart';
import 'bitmap_tile_operation_apply.dart';

BitmapTile? materializedBitmapTileForOperations({
  required BitmapTile tile,
  required Iterable<BrushPixelBlendOperation> operations,
}) {
  final updatedTile = applyBrushPixelBlendOperationsToBitmapTile(
    tile: tile,
    operations: operations,
  );

  if (updatedTile == tile) return null;
  return updatedTile;
}
