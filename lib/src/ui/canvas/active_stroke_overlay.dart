import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/brush_dab.dart';
import '../../models/dirty_region.dart';
import '../../models/tile_coord.dart';
import '../../services/brush_live_stroke_rasterizer.dart'
    show ActiveStrokePixelSource;
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

  /// Whether the current stroke ERASES: the painter then draws the overlay
  /// tiles destination-out so the preview removes committed pixels exactly
  /// where the commit will. Set by the interactive view at stroke start and
  /// kept through settling (the commit needs the same mode until the
  /// committed tiles decode).
  bool erase = false;

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

  /// Snapshots the overlay tiles that [region] touches from the live
  /// stroke [source] and re-decodes them.
  ///
  /// Decoding is asynchronous; a tile touched again while its decode is in
  /// flight is re-snapshotted from the (newer) stroke content as soon as
  /// the running decode lands, so the newest state always wins and
  /// per-frame work stays bounded to one decode per touched tile.
  void updateRegion({
    required ActiveStrokePixelSource source,
    required DirtyRegion region,
  }) {
    for (final coord in region.toTileCoords(tileSize: tileSize)) {
      _decodeTile(coord, source);
    }
  }

  void _decodeTile(TileCoord coord, ActiveStrokePixelSource source) {
    if (_decoding.contains(coord)) {
      _dirtyWhileDecoding.add(coord);
      return;
    }
    _decoding.add(coord);
    _pendingDecodeCount += 1;

    final left = coord.x * tileSize;
    final top = coord.y * tileSize;
    final width = math.min(tileSize, source.canvasWidth - left);
    final height = math.min(tileSize, source.canvasHeight - top);

    // Snapshot the straight-alpha rows, then premultiply in place with the
    // same per-pixel branches/rounding as before: the engine interprets
    // rgba8888 uploads as premultiplied, and Skia's mul-div-255 rounding
    // keeps the overlay byte-identical to the committed tile images. The
    // alpha==0 case must ZERO the color bytes — a straight-alpha stroke
    // pixel can round to alpha 0 while keeping non-zero color, which would
    // be invalid premultiplied data.
    final bytes = Uint8List(width * height * 4);
    for (var y = 0; y < height; y += 1) {
      source.copyRow(left, top + y, width, bytes, y * width * 4);
    }
    for (var offset = 0; offset < bytes.length; offset += 4) {
      final alpha = bytes[offset + 3];
      if (alpha == 255) {
        continue;
      }
      if (alpha == 0) {
        bytes[offset] = 0;
        bytes[offset + 1] = 0;
        bytes[offset + 2] = 0;
        continue;
      }
      bytes[offset] = _mul255Round(bytes[offset], alpha);
      bytes[offset + 1] = _mul255Round(bytes[offset + 1], alpha);
      bytes[offset + 2] = _mul255Round(bytes[offset + 2], alpha);
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
        _decodeTile(coord, source);
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
