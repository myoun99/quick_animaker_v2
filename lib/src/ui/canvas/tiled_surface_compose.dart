import 'dart:async';
import 'dart:ui' as ui;

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../dev_profile.dart';
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
///
/// [shouldAbort] (R13-4, the warm path only): checked before every tile
/// decode and before the final full-canvas raster — the two cost centers —
/// so an interactive input stops an opportunistic compose within ~one tile
/// (1–2ms), not one canvas. Aborts return null with nothing cached and the
/// transient decodes disposed; without [shouldAbort] the result is never
/// null.
Future<ui.Image?> composeTiledSurfaceImage(
  BitmapSurface surface, {
  BitmapTileImageCache? reuse,
  bool Function()? shouldAbort,
}) async {
  final width = surface.canvasSize.width;
  final height = surface.canvasSize.height;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;
  final transient = <ui.Image>[];
  var recorderClosed = false;

  try {
    for (final tile in surface.tiles.values) {
      var image = reuse?.imageFor(tile);
      if (image == null) {
        if (shouldAbort?.call() ?? false) {
          recorder.endRecording().dispose();
          recorderClosed = true;
          return null;
        }
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
    recorderClosed = true;
    try {
      if (shouldAbort?.call() ?? false) {
        return null;
      }
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  } finally {
    if (!recorderClosed) {
      recorder.endRecording().dispose();
    }
    for (final image in transient) {
      image.dispose();
    }
  }
}

/// Synchronous variant for latency-critical swaps (the layer-switch
/// handoff): composes ONLY when every tile is already decoded in [reuse] —
/// the on-screen frame's tiles always are — via [ui.Picture.toImageSync]
/// (rasterization stays deferred on the GPU). Returns null when any tile
/// is missing so the caller falls back to the async path; byte parity
/// matches [composeTiledSurfaceImage] (same tile images, same 1:1
/// integer-offset draws). The caller owns the returned image.
ui.Image? composeTiledSurfaceImageSyncOrNull(
  BitmapSurface surface, {
  required BitmapTileImageCache reuse,
}) {
  return labProbe(
    'composeSync(${surface.tiles.length}t '
    '${surface.canvasSize.width}x${surface.canvasSize.height})',
    () => _composeTiledSurfaceImageSyncOrNull(surface, reuse: reuse),
  );
}

ui.Image? _composeTiledSurfaceImageSyncOrNull(
  BitmapSurface surface, {
  required BitmapTileImageCache reuse,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  for (final tile in surface.tiles.values) {
    final image = reuse.imageFor(tile);
    if (image == null) {
      recorder.endRecording().dispose();
      return null;
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
    return picture.toImageSync(
      surface.canvasSize.width,
      surface.canvasSize.height,
    );
  } finally {
    picture.dispose();
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
