import '../models/bitmap_tile.dart';
import '../models/rgba_color.dart';

RgbaColor readRgbaColorFromBitmapTile({
  required BitmapTile tile,
  required int x,
  required int y,
}) {
  final offset = tile.byteOffsetForPixel(x: x, y: y);
  final pixels = tile.pixels;
  return RgbaColor(
    r: pixels[offset],
    g: pixels[offset + 1],
    b: pixels[offset + 2],
    a: pixels[offset + 3],
  );
}

BitmapTile writeRgbaColorToBitmapTile({
  required BitmapTile tile,
  required int x,
  required int y,
  required RgbaColor color,
}) {
  final offset = tile.byteOffsetForPixel(x: x, y: y);
  final updatedPixels = tile.pixels;
  updatedPixels[offset] = color.r;
  updatedPixels[offset + 1] = color.g;
  updatedPixels[offset + 2] = color.b;
  updatedPixels[offset + 3] = color.a;
  return tile.copyWith(pixels: updatedPixels);
}
