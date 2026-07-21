import 'dart:async';
import 'dart:ui' as ui;

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../dev_profile.dart';
import 'bitmap_tile_image_cache.dart';

/// A composed surface image plus the CANVAS-SPACE rect it covers.
///
/// For a surface whose tiles all sit inside the canvas, [worldRect] is
/// exactly the canvas rect and the image is canvas-sized — byte-identical
/// to [composeTiledSurfaceImage]. Pasteboard content grows the rect (and
/// the image) only as far as the stored tiles reach, so layers without
/// off-canvas artwork pay nothing.
class PositionedSurfaceImage {
  const PositionedSurfaceImage({required this.image, required this.worldRect});

  final ui.Image image;
  final ui.Rect worldRect;

  /// Whether this is the plain canvas-extent case (consumers keep their
  /// exact legacy draw path for it — byte parity).
  bool isCanvasExtent(BitmapSurface surface) =>
      worldRect ==
      ui.Rect.fromLTWH(
        0,
        0,
        surface.canvasSize.width.toDouble(),
        surface.canvasSize.height.toDouble(),
      );
}

/// The canvas rect UNIONED with every stored tile's rect — the extent a
/// positioned compose rasters. Integer-aligned by construction.
ui.Rect surfaceContentWorldRect(BitmapSurface surface) {
  var left = 0;
  var top = 0;
  var right = surface.canvasSize.width;
  var bottom = surface.canvasSize.height;
  for (final coord in surface.tiles.keys) {
    final tileLeft = coord.x * surface.tileSize;
    final tileTop = coord.y * surface.tileSize;
    if (tileLeft < left) left = tileLeft;
    if (tileTop < top) top = tileTop;
    if (tileLeft + surface.tileSize > right) right = tileLeft + surface.tileSize;
    if (tileTop + surface.tileSize > bottom) bottom = tileTop + surface.tileSize;
  }
  return ui.Rect.fromLTRB(
    left.toDouble(),
    top.toDouble(),
    right.toDouble(),
    bottom.toDouble(),
  );
}

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

/// The pasteboard-aware sibling of [composeTiledSurfaceImage]: rasters the
/// surface over [surfaceContentWorldRect] and returns the image WITH that
/// rect, so the editing layer stack can show off-canvas artwork at its
/// true position. Same tile pipeline, same premultiply, same 1:1 integer
/// offsets — only the raster origin/extent differ (and only when
/// pasteboard tiles exist).
Future<PositionedSurfaceImage?> composePositionedSurfaceImage(
  BitmapSurface surface, {
  BitmapTileImageCache? reuse,
  bool Function()? shouldAbort,
}) async {
  final worldRect = surfaceContentWorldRect(surface);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(-worldRect.left, -worldRect.top);
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
      return PositionedSurfaceImage(
        image: await picture.toImage(
          worldRect.width.round(),
          worldRect.height.round(),
        ),
        worldRect: worldRect,
      );
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

/// Synchronous positioned variant (the layer-switch handoff): composes
/// ONLY when every tile is already decoded in [reuse]; null otherwise.
PositionedSurfaceImage? composePositionedSurfaceImageSyncOrNull(
  BitmapSurface surface, {
  required BitmapTileImageCache reuse,
}) {
  final worldRect = surfaceContentWorldRect(surface);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.translate(-worldRect.left, -worldRect.top);
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
    return PositionedSurfaceImage(
      image: picture.toImageSync(
        worldRect.width.round(),
        worldRect.height.round(),
      ),
      worldRect: worldRect,
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
