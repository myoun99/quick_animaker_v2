import 'dart:async';
import 'dart:ui' as ui;

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import 'bitmap_tile_image_cache.dart';

/// Composes a tiled [BitmapSurface] into one full-resolution [ui.Image] by
/// drawing per-tile GPU images — the editing canvas's display route, reused
/// for playback/preview rendering.
///
/// Tiles already decoded in [reuse] (typically [BitmapTileImageCache.instance],
/// which the editing canvas keeps warm for the frame on screen) are drawn
/// as-is, so rebuilding the ACTIVE frame after a stroke uploads nothing:
/// cost scales with the changed tiles, not the canvas. Missing tiles decode
/// transiently and are disposed right after the compose — cold frames pay
/// one upload per stored tile without pinning GPU copies of every frame's
/// artwork.
///
/// Byte-parity with the CPU assembly path ([bitmapSurfaceToImage]): tile
/// bytes premultiply through the SAME mul-div-255 rounding
/// ([BitmapTileImageCache.premultipliedTilePixels]) and are drawn 1:1 at
/// integer offsets with [ui.FilterQuality.none] over a transparent base, so
/// srcOver passes the premultiplied bytes through unchanged.
///
/// The caller owns (and must dispose) the returned image.
Future<ui.Image> composeTiledSurfaceImage(
  BitmapSurface surface, {
  BitmapTileImageCache? reuse,
}) async {
  final width = surface.canvasSize.width;
  final height = surface.canvasSize.height;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final transient = <ui.Image>[];

  try {
    for (final tile in surface.tiles.values) {
      var image = reuse?.imageFor(tile);
      if (image == null) {
        image = await _decodeTile(tile);
        transient.add(image);
      }
      canvas.drawImage(
        image,
        ui.Offset(
          (tile.coord.x * tile.size).toDouble(),
          (tile.coord.y * tile.size).toDouble(),
        ),
        paint,
      );
    }

    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  } finally {
    for (final image in transient) {
      image.dispose();
    }
  }
}

Future<ui.Image> _decodeTile(BitmapTile tile) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    BitmapTileImageCache.premultipliedTilePixels(tile),
    tile.size,
    tile.size,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
