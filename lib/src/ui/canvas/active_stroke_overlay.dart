import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../models/bitmap_surface.dart';
import '../../models/bitmap_tile.dart';
import '../../models/brush_blend_mode.dart';
import '../../models/brush_dab.dart';
import '../../models/canvas_size.dart';
import '../../models/dirty_region.dart';
import '../../models/pasteboard_bounds.dart';
import '../../models/tile_coord.dart';
import '../../native/qa_native_engine.dart' show QaStampScratch;
import '../../services/brush_live_stroke_rasterizer.dart'
    show ActiveStrokePixelSource, BrushLiveStrokeRasterizer;
import '../../services/brush_stroke_blend.dart'
    show bitmapSurfaceRegionPixels, preBlendStrokeOverlayPixels;
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
  ActiveStrokeOverlayModel({int tileSize = 256}) : _tileSize = tileSize;

  int _tileSize;

  /// Edge length of an overlay tile in canvas pixels.
  ///
  /// PROMOTION round: the interactive view aligns this with the
  /// committed surface's tile size at stroke start ([configureTileSize])
  /// so a pre-blended result tile REPLACES the committed tile at the
  /// same coordinate in the painter's base pass — no clips, no
  /// isolation layer, and the per-frame draw count stays the idle
  /// frame's. A mismatched grid still displays through the isolation
  /// fallback, just without the replacement economics.
  int get tileSize => _tileSize;

  /// Aligns the overlay grid with the surface about to be stroked. Only
  /// legal while the overlay is empty (call after [reset]) — images are
  /// keyed by tile coordinate, which changes meaning with the grid.
  void configureTileSize(int tileSize) {
    assert(
      _tileImages.isEmpty && _decoding.isEmpty,
      'configureTileSize requires an empty overlay',
    );
    _tileSize = tileSize;
  }

  /// Dabs of the current stroke, kept for observability and tests; rendering
  /// uses [tileImages], which carry the exact rasterized pixels.
  final List<BrushDab> dabs = <BrushDab>[];

  /// Whether the current stroke ERASES: the painter then draws the overlay
  /// tiles destination-out so the preview removes committed pixels exactly
  /// where the commit will. Set by the interactive view at stroke start and
  /// kept through settling (the commit needs the same mode until the
  /// committed tiles decode).
  bool erase = false;

  /// The stroke's BRUSH blend (BB-1, R26 #9). With [preBlendBase] set the
  /// mode feeds the CPU pre-blend below and the GPU never blends at all;
  /// only plain color-mode strokes still preview through ui.BlendMode.
  BrushBlendMode blendMode = BrushBlendMode.color;

  /// R27 #4: the cel's committed surface at stroke start — non-null puts
  /// the overlay in PRE-BLEND mode: every tile decode runs the COMMIT's
  /// own per-pixel math (stroke against these base bytes) and uploads the
  /// finished result, which the painter draws as a plain REPLACEMENT
  /// (BlendMode.src inside the cel isolation layer). The GPU's float
  /// approximation of the blend — the BB-1 ±1/255 honest limit — is out
  /// of the loop entirely: what settles at pen-up is byte-for-byte what
  /// was already on screen.
  ///
  /// Set for every non-plain mode (erase included); null keeps the classic
  /// stroke-only tiles for color-mode strokes. Immutable surface: holding
  /// it across async decodes is safe, and mid-stroke the cel cannot
  /// change under it (commits happen at pen-up only).
  BitmapSurface? preBlendBase;

  /// Whether tiles carry PRE-BLENDED result pixels (replacement
  /// semantics) rather than stroke-only pixels the painter must blend.
  bool get preBlended => preBlendBase != null;

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
  bool get hasStrokeContent => _tileImages.isNotEmpty || _stampImage != null;

  ui.Image? _stampImage;
  ui.Offset _stampOffset = ui.Offset.zero;

  /// R23: a FILL tap's overlay is ONE pre-decoded image at its stamp
  /// rect. The flood already produced the full stamp RGBA, so blending
  /// it into the live-raster tiles only to re-snapshot and re-decode
  /// thousands of 128px overlay tiles (the 8K settle-frame stall) was
  /// pure waste — one image, one decode, one draw.
  ui.Image? get stampImage => _stampImage;

  /// Canvas-space top-left of [stampImage] (the commit's exact
  /// `(center - size/2).round()` placement, so overlay and committed
  /// pixels land identically).
  ui.Offset get stampOffset => _stampOffset;

  /// Shows [image] as the whole overlay (fills never erase, tiles and
  /// stamp never coexist — [reset] runs before every fill tap).
  void setStampOverlay(ui.Image image, ui.Offset offset) {
    final previous = _stampImage;
    if (previous != null) {
      DeferredImageDisposer.instance.retire(previous);
    }
    _stampImage = image;
    _stampOffset = offset;
    notifyListeners();
  }

  Map<TileCoord, BitmapTile?>? _settleHoldTiles;

  /// PRE-stroke committed tiles pinned for display while the stroke settles
  /// (a null value = that coordinate was empty before the stroke).
  ///
  /// While non-null, the painter draws these beneath the overlay INSTEAD of
  /// the committed surface's tiles at the same coordinates. Without the
  /// pin, post-commit tile decodes land one by one and each freshly decoded
  /// tile (already containing the stroke) gets the still-visible overlay
  /// blended on top — the stroke flashed at double density in tile-shaped
  /// patches until the last decode dropped the overlay. Pinning keeps every
  /// settling frame pixel-identical to the live stroke, and [reset] clears
  /// the pin and the overlay in one notification: an atomic swap to the
  /// committed pixels.
  Map<TileCoord, BitmapTile?>? get settleHoldTiles => _settleHoldTiles;

  /// Pins [tiles] (keyed by committed-grid coordinate) until [reset].
  /// Holding the immutable pre-stroke [BitmapTile] objects keeps their
  /// decoded images alive in the tile image cache — no image cloning or
  /// disposal bookkeeping is needed here.
  void holdPreStrokeTiles(Map<TileCoord, BitmapTile?> tiles) {
    _settleHoldTiles = Map<TileCoord, BitmapTile?>.unmodifiable(tiles);
    notifyListeners();
  }

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
    // Snapshot clamps at the PASTEBOARD edge, not the canvas — live
    // strokes paint (and must display) past the canvas rect.
    final sourceCanvasSize = CanvasSize(
      width: source.canvasWidth,
      height: source.canvasHeight,
    );
    final width = math.min(
      tileSize,
      sourceCanvasSize.pasteboardRightExclusive - left,
    );
    final height = math.min(
      tileSize,
      sourceCanvasSize.pasteboardBottomExclusive - top,
    );

    // R25 fast path: a FULL interior tile of a native-backed live
    // rasterizer shares this model's 128px grid, so snapshot +
    // premultiply collapse into one C call (per 2000px move that is
    // ~256 tiles — the Dart loops below were the big-brush stall and
    // the visible pre-stroke tiles). Same bytes: the C premultiply is
    // parity-pinned against this exact rounding. Pre-blend strokes skip
    // it — the kernel needs the STRAIGHT stroke bytes, not premultiplied.
    final preBlend = preBlendBase;
    QaStampScratch? scratch;
    Uint8List? fused;
    if (width == tileSize &&
        height == tileSize &&
        source is BrushLiveStrokeRasterizer &&
        BrushLiveStrokeRasterizer.tileSize == tileSize) {
      // R27 #4 native route first: stage base + blend + premultiply all
      // in C (the commit's own kernels — user rule: "무조건 네이티브").
      // Falls to the Dart path below when the engine or the native tile
      // is absent; both routes are parity-pinned to the same bytes.
      scratch = preBlend != null
          ? source.preBlendedOverlayTile(
              tileX: coord.x,
              tileY: coord.y,
              base: preBlend,
              mode: blendMode,
              erase: erase,
            )
          : source.premultipliedOverlayTile(coord.x, coord.y);
      fused = scratch?.view;
    }
    // Snapshot the straight-alpha rows, then premultiply in place with the
    // same per-pixel branches/rounding as before: the engine interprets
    // rgba8888 uploads as premultiplied, and Skia's mul-div-255 rounding
    // keeps the overlay byte-identical to the committed tile images. The
    // alpha==0 case must ZERO the color bytes — a straight-alpha stroke
    // pixel can round to alpha 0 while keeping non-zero color, which would
    // be invalid premultiplied data.
    final Uint8List bytes;
    if (fused != null) {
      bytes = fused;
    } else {
      var straight = Uint8List(width * height * 4);
      for (var y = 0; y < height; y += 1) {
        source.copyRow(left, top + y, width, straight, y * width * 4);
      }
      if (preBlend != null) {
        // R27 #4: the tile shows the COMMIT's result, computed by the
        // commit's own math against the cel's committed bytes — the
        // painter replaces the base with it, and pen-up lands the exact
        // same bytes. (This forgoes the fused C snapshot: correctness is
        // the rule here; the giant-brush + blend-mode combo pays some
        // Dart time and is flagged for a native lift if it ever shows.)
        straight = preBlendStrokeOverlayPixels(
          dst: bitmapSurfaceRegionPixels(
            preBlend,
            DirtyRegion(
              left: left,
              top: top,
              rightExclusive: left + width,
              bottomExclusive: top + height,
            ),
          ),
          src: straight,
          mode: blendMode,
          erase: erase,
          pixelCount: width * height,
        );
      }
      bytes = straight;
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
    }

    final generation = _generation;
    ui.decodeImageFromPixels(bytes, width, height, ui.PixelFormat.rgba8888, (
      image,
    ) {
      scratch?.free();
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

  /// Clears the overlay (stroke tiles AND the settle pin) and disposes its
  /// tile images; the single notification makes the handoff to the
  /// committed tiles atomic.
  void reset() {
    _generation += 1;
    _clearTiles();
    _settleHoldTiles = null;
    preBlendBase = null;
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _generation += 1;
    _clearTiles();
    _settleHoldTiles = null;
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
    final stamp = _stampImage;
    if (stamp != null) {
      DeferredImageDisposer.instance.retire(stamp);
      _stampImage = null;
    }
  }

  /// Skia's `SkMulDiv255Round`: round(value * alpha / 255) for bytes.
  static int _mul255Round(int value, int alpha) {
    final product = value * alpha + 128;
    return (product + (product >> 8)) >> 8;
  }
}
