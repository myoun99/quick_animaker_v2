import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/bitmap_tile.dart';
import '../../models/tile_coord.dart';
import 'deferred_image_disposal.dart';

/// Identity-keyed cache converting immutable [BitmapTile] pixel bytes into
/// GPU-ready [ui.Image]s for display.
///
/// This is derived render data only — never source of truth. Tiles are
/// immutable and structurally shared across [BitmapSurface] versions, so the
/// tile object's identity is a stable cache key: an unchanged tile keeps its
/// decoded image across surface updates, and a changed tile is a new object
/// that decodes once.
///
/// Decoding is asynchronous; [BitmapSurfacePainter] falls back to its
/// per-pixel path for tiles whose image is not ready yet and repaints via the
/// [ChangeNotifier] interface when a decode completes. Entries never need
/// manual eviction: the [Expando] releases them with the tile, and a
/// [Finalizer] disposes the decoded image afterwards.
class BitmapTileImageCache extends ChangeNotifier {
  BitmapTileImageCache();

  /// Shared instance used by the display painter. A render cache, not app
  /// state: it holds no editing data and only accelerates repaints.
  static final BitmapTileImageCache instance = BitmapTileImageCache();

  final Expando<ui.Image> _images = Expando<ui.Image>('bitmapTileImages');
  final Expando<Object> _inFlight = Expando<Object>('bitmapTileImageDecodes');
  static const Object _inFlightMarker = Object();
  // Deferred, not direct, disposal: the finalizer runs at GC time — pen-up
  // commits allocate heavily and collect right when a replaced tile's image
  // is still referenced by the frame on screen. Disposing it there raced
  // the raster thread and intermittently flashed the tile as a black square
  // for one frame.
  static final Finalizer<ui.Image> _imageFinalizer = Finalizer<ui.Image>(
    (image) => DeferredImageDisposer.instance.retire(image),
  );

  /// Latest decoded tile per (scope, coordinate), held strongly so its image
  /// stays alive (the [Finalizer] only disposes an image once its tile is
  /// unreferenced everywhere). Lets the painter show slightly stale content
  /// for a just-changed tile instead of falling back to a per-pixel redraw,
  /// which froze the UI for large strokes.
  ///
  /// The scope isolates unrelated surfaces that share coordinates — e.g. two
  /// animation frames both have a tile at (0, 0), and without scoping the
  /// previous frame's artwork would briefly show through while the current
  /// frame's tile decodes.
  final Map<Object?, Map<TileCoord, BitmapTile>> _latestDecodedByScope =
      <Object?, Map<TileCoord, BitmapTile>>{};

  /// The decoded image for [tile], or `null` while the decode is pending.
  ui.Image? imageFor(BitmapTile tile) => _images[tile];

  /// The most recently decoded image at [coord] within [scope] (possibly for
  /// an older tile version), or `null` if nothing decoded there yet.
  ui.Image? latestImageForCoord(TileCoord coord, {Object? scope}) {
    final tile = _latestDecodedByScope[scope]?[coord];
    return tile == null ? null : _images[tile];
  }

  /// Starts decoding [tile] once; notifies listeners when the image is ready.
  ///
  /// [staleScope] identifies the logical surface lineage (e.g. a brush frame)
  /// so [latestImageForCoord] never leaks another lineage's artwork.
  void ensureDecoded(BitmapTile tile, {Object? staleScope}) {
    if (_images[tile] != null || _inFlight[tile] != null) {
      return;
    }
    _inFlight[tile] = _inFlightMarker;

    // Tile bytes are stored with straight (unpremultiplied) alpha, but the
    // engine interprets raw rgba8888 uploads as premultiplied. Premultiply on
    // the defensive copy using Skia's own mul-div-255 rounding so the result
    // matches what Skia produces when rasterizing straight-alpha colors.
    final pixels = tile.pixels;
    for (var offset = 0; offset < pixels.length; offset += 4) {
      final alpha = pixels[offset + 3];
      if (alpha == 255) {
        continue;
      }
      if (alpha == 0) {
        pixels[offset] = 0;
        pixels[offset + 1] = 0;
        pixels[offset + 2] = 0;
        continue;
      }
      pixels[offset] = _mul255Round(pixels[offset], alpha);
      pixels[offset + 1] = _mul255Round(pixels[offset + 1], alpha);
      pixels[offset + 2] = _mul255Round(pixels[offset + 2], alpha);
    }

    ui.decodeImageFromPixels(
      pixels,
      tile.size,
      tile.size,
      ui.PixelFormat.rgba8888,
      (image) {
        _images[tile] = image;
        _imageFinalizer.attach(tile, image);
        _latestDecodedByScope.putIfAbsent(
          staleScope,
          () => <TileCoord, BitmapTile>{},
        )[tile.coord] = tile;
        notifyListeners();
      },
    );
  }

  /// Whether every tile of [tiles] has a decoded image ready.
  bool allDecoded(Iterable<BitmapTile> tiles) {
    for (final tile in tiles) {
      if (_images[tile] == null) {
        return false;
      }
    }
    return true;
  }

  /// Skia's `SkMulDiv255Round`: round(value * alpha / 255) for bytes.
  static int _mul255Round(int value, int alpha) {
    final product = value * alpha + 128;
    return (product + (product >> 8)) >> 8;
  }
}
