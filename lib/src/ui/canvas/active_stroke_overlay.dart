import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/brush_dab.dart';
import '../../models/dirty_region.dart';
import '../../models/tile_coord.dart';
import 'deferred_image_disposal.dart';

/// Mutable state of the in-progress stroke overlay.
///
/// A lightweight editor-local [ChangeNotifier]: the interactive view blends
/// new dabs into its live CPU stroke buffer and hands the touched region to
/// [updateRegion]; decode completions notify the canvas painter through the
/// `CustomPainter.repaint` hook, so strokes repaint without rebuilding any
/// widgets.
///
/// The overlay displays through the EXACT pipeline the committed tiles use:
/// straight-alpha buffer bytes are premultiplied and decoded with
/// `decodeImageFromPixels` into tile images that the painter draws with
/// nearest sampling. One rasterization path means live and committed pixels
/// cannot diverge at any zoom — replaying the stroke as rect geometry (a
/// previous representation) rasterized differently from nearest-sampled
/// images at fractional zoom, visibly shifting the active stroke's pixels
/// against committed strokes. Decode-based images also survive GPU context
/// events (e.g. app focus switches) that corrupted synchronously created
/// picture-to-image textures for a frame.
class ActiveStrokeOverlayModel extends ChangeNotifier {
  ActiveStrokeOverlayModel({this.tileSize = 128});

  /// Edge length of an overlay tile in canvas pixels. Independent of the
  /// committed surface's tile size; smaller tiles bound the per-move
  /// snapshot/upload cost.
  final int tileSize;

  /// Dabs of the current stroke, kept for observability and tests; rendering
  /// uses [tileImages], which carry the exact rasterized pixels.
  final List<BrushDab> dabs = <BrushDab>[];

  final Map<TileCoord, ui.Image> _tileImages = <TileCoord, ui.Image>{};
  final Set<TileCoord> _decoding = <TileCoord>{};
  final Set<TileCoord> _dirtyWhileDecoding = <TileCoord>{};
  int _generation = 0;
  int _pendingDecodeCount = 0;
  Completer<void>? _decodesSettled;

  /// Decoded overlay tile images by tile coordinate. Tiles never overlap, so
  /// the painter draws each with plain source-over at
  /// `(coord * tileSize)`, exactly like the committed tile images.
  late final Map<TileCoord, ui.Image> tileImages = UnmodifiableMapView(
    _tileImages,
  );

  /// Whether the overlay currently has stroke content to draw.
  bool get hasStrokeContent => _tileImages.isNotEmpty;

  /// Snapshots the overlay tiles that [region] touches from the live stroke
  /// buffer and re-decodes them.
  ///
  /// Decoding is asynchronous; a tile touched again while its decode is in
  /// flight is re-snapshotted from the (newer) buffer content as soon as the
  /// running decode lands, so the newest state always wins and per-frame
  /// work stays bounded to one decode per touched tile.
  void updateRegion({
    required Uint8List pixels,
    required int canvasWidth,
    required int canvasHeight,
    required DirtyRegion region,
  }) {
    for (final coord in region.toTileCoords(tileSize: tileSize)) {
      _decodeTile(coord, pixels, canvasWidth, canvasHeight);
    }
  }

  void _decodeTile(
    TileCoord coord,
    Uint8List pixels,
    int canvasWidth,
    int canvasHeight,
  ) {
    if (_decoding.contains(coord)) {
      _dirtyWhileDecoding.add(coord);
      return;
    }
    _decoding.add(coord);
    _pendingDecodeCount += 1;

    final left = coord.x * tileSize;
    final top = coord.y * tileSize;
    final width = math.min(tileSize, canvasWidth - left);
    final height = math.min(tileSize, canvasHeight - top);

    // Snapshot and premultiply in one pass: the engine interprets rgba8888
    // uploads as premultiplied, and Skia's mul-div-255 rounding keeps the
    // overlay byte-identical to the committed tile images.
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y += 1) {
      var source = ((top + y) * canvasWidth + left) * 4;
      var target = y * width * 4;
      for (var x = 0; x < width; x += 1) {
        final alpha = pixels[source + 3];
        if (alpha == 255) {
          bytes[target] = pixels[source];
          bytes[target + 1] = pixels[source + 1];
          bytes[target + 2] = pixels[source + 2];
          bytes[target + 3] = 255;
        } else if (alpha != 0) {
          bytes[target] = _mul255Round(pixels[source], alpha);
          bytes[target + 1] = _mul255Round(pixels[source + 1], alpha);
          bytes[target + 2] = _mul255Round(pixels[source + 2], alpha);
          bytes[target + 3] = alpha;
        }
        source += 4;
        target += 4;
      }
    }

    final generation = _generation;
    ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      if (generation != _generation) {
        // The stroke was reset or the model disposed while decoding. This
        // image was never painted, so no frame can reference it: direct
        // disposal is safe.
        image.dispose();
        _finishDecode();
        return;
      }
      _decoding.remove(coord);
      final previous = _tileImages[coord];
      if (previous != null) {
        // The on-screen frame may still reference the replaced image;
        // disposing it in step with the swap intermittently flashed the
        // tile black for one frame.
        DeferredImageDisposer.instance.retire(previous);
      }
      _tileImages[coord] = image;
      notifyListeners();
      if (_dirtyWhileDecoding.remove(coord)) {
        _decodeTile(coord, pixels, canvasWidth, canvasHeight);
      }
      _finishDecode();
    });
  }

  void _finishDecode() {
    _pendingDecodeCount -= 1;
    if (_pendingDecodeCount == 0) {
      _decodesSettled?.complete();
      _decodesSettled = null;
    }
  }

  /// Completes once no tile decode is in flight, including decodes chained
  /// by mid-decode updates.
  @visibleForTesting
  Future<void> waitForPendingDecodes() {
    if (_pendingDecodeCount == 0) {
      return Future<void>.value();
    }
    return (_decodesSettled ??= Completer<void>()).future;
  }

  /// Clears the overlay and disposes its tile images.
  void reset() {
    _generation += 1;
    _clearTiles();
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation += 1;
    _clearTiles();
    super.dispose();
  }

  void _clearTiles() {
    for (final image in _tileImages.values) {
      // The overlay being cleared is what the on-screen frame currently
      // shows (e.g. the settling stroke at commit); defer disposal past the
      // frames that may still reference it.
      DeferredImageDisposer.instance.retire(image);
    }
    _tileImages.clear();
    _decoding.clear();
    _dirtyWhileDecoding.clear();
  }

  /// Skia's `SkMulDiv255Round`: round(value * alpha / 255) for bytes.
  static int _mul255Round(int value, int alpha) {
    final product = value * alpha + 128;
    return (product + (product >> 8)) >> 8;
  }
}
