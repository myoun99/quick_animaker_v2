import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/bitmap_tile.dart';

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
  static final Finalizer<ui.Image> _imageFinalizer = Finalizer<ui.Image>(
    (image) => image.dispose(),
  );

  /// The decoded image for [tile], or `null` while the decode is pending.
  ui.Image? imageFor(BitmapTile tile) => _images[tile];

  /// Starts decoding [tile] once; notifies listeners when the image is ready.
  void ensureDecoded(BitmapTile tile) {
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
        notifyListeners();
      },
    );
  }

  /// Skia's `SkMulDiv255Round`: round(value * alpha / 255) for bytes.
  static int _mul255Round(int value, int alpha) {
    final product = value * alpha + 128;
    return (product + (product >> 8)) >> 8;
  }
}
