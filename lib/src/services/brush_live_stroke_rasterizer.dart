import 'dart:ffi' show Uint8Pointer;
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/floor_math.dart';
import '../models/bitmap_surface.dart';
import '../models/brush_blend_mode.dart';
import '../models/brush_dab.dart';
import '../models/brush_tip_shape.dart';
import '../models/canvas_size.dart';
import '../models/dirty_region.dart';
import '../models/pasteboard_bounds.dart';
import '../models/tile_coord.dart';
import '../native/qa_native_engine.dart';
import 'brush_dab_dirty_region.dart';
import 'brush_stroke_blend.dart' show strokeBlendModeNativeId;
import 'brush_tip_mask_sampling.dart';

/// Read access to the in-progress stroke's straight-alpha pixels — what
/// the live overlay snapshots its tile images from.
abstract interface class ActiveStrokePixelSource {
  int get canvasWidth;
  int get canvasHeight;

  /// Copies [count] straight-alpha RGBA pixels starting at canvas (x, y)
  /// into [target] at [targetOffset]. Unpainted pixels read as transparent
  /// zeros.
  void copyRow(int x, int y, int count, Uint8List target, int targetOffset);
}

/// Rasterizes the in-progress stroke incrementally into SPARSE
/// straight-alpha RGBA tiles allocated on demand.
///
/// Storage is tile-sparse so the cost of a stroke scales with the region
/// it actually paints, never with the canvas: the old canvas-sized buffer
/// made big logical surfaces (the timesheet ink planes at high resolution)
/// pay tens/hundreds of MB per stroke.
///
/// This runs the exact blend math of the commit rasterizer
/// (`materializeBrushDabSequenceOnBitmapSurface`) — same coverage sampling of
/// pixel centers against the true fractional dab center, same floating-point
/// grouping, same rounding — so the pixels painted while drawing are
/// byte-identical to the committed result. The live display and the commit
/// fast-path both consume these pixels, which is what unifies the on-screen
/// stroke with the committed artwork. Equivalence with the commit rasterizer
/// is locked by `active_stroke_overlay_parity_test.dart` (byte-exact).
class BrushLiveStrokeRasterizer implements ActiveStrokePixelSource {
  BrushLiveStrokeRasterizer({required this.canvasSize});

  /// Edge length of a sparse stroke tile in canvas pixels.
  static const int tileSize = 128;

  final CanvasSize canvasSize;

  @override
  int get canvasWidth => canvasSize.width;

  @override
  int get canvasHeight => canvasSize.height;

  /// Straight-alpha RGBA tile buffers keyed by `tileY * tilesPerRow +
  /// tileX`, allocated (zeroed) the first time a dab touches the tile.
  ///
  /// R21: with the engine loaded the buffers are NATIVE-backed (the map
  /// holds asTypedList views; [_nativeBuffers] the raw pointers) and the
  /// per-dab blend fans through the SAME C kernel as the commit — a
  /// 1000px dab is ~1M pixels, and the pure-Dart loop below was the
  /// reported big-brush stall on the UI thread. Dart stays the reference
  /// and the fallback; the kernel is parity-pinned byte-for-byte.
  final Map<int, Uint8List> _tiles = <int, Uint8List>{};
  final Map<int, QaNativeTileBuffer> _nativeBuffers =
      <int, QaNativeTileBuffer>{};
  final QaNativeEngine? _native = QaNativeEngine.instance;

  // The linear key grid spans the PASTEBOARD (strokes reach one canvas
  // size past every edge), offset so keys stay non-negative.
  late final int _tileXMin = canvasSize.pasteboardTileXMin(tileSize);
  late final int _tileYMin = canvasSize.pasteboardTileYMin(tileSize);
  late final int _tilesPerRow =
      canvasSize.pasteboardTileXEndExclusive(tileSize) - _tileXMin;

  int _tileKey(int tileX, int tileY) =>
      (tileY - _tileYMin) * _tilesPerRow + (tileX - _tileXMin);

  DirtyRegion? _strokeBounds;
  int _blendedDabCount = 0;

  /// Union of every blended dab's dirty region, or `null` when nothing has
  /// been painted yet.
  DirtyRegion? get strokeBounds => _strokeBounds;

  /// Number of dabs blended so far.
  int get blendedDabCount => _blendedDabCount;

  /// Number of allocated stroke tiles (test/debug oracle for sparseness).
  int get allocatedTileCount => _tiles.length;

  /// Drops the stroke's tiles so the rasterizer can host the next stroke
  /// (native buffers return to the engine's free list).
  void clear() {
    final native = _native;
    if (native != null) {
      for (final buffer in _nativeBuffers.values) {
        native.releaseTileBuffer(buffer);
      }
    }
    _nativeBuffers.clear();
    _tiles.clear();
    _strokeBounds = null;
    _blendedDabCount = 0;
  }

  /// R25: the overlay's FUSED display path. Overlay tiles are the same
  /// 128px grid as the stroke tiles, so a full tile's snapshot +
  /// premultiply collapses into ONE C call over the native buffer (the
  /// per-move Dart row-copy + pixel loop across ~256 tiles was the
  /// 2000px-brush stall and the visible pre-stroke tiles). Null when
  /// the tile is untouched (transparent — caller's copyRow path reads
  /// zeros) or the engine/native backing is absent.
  QaStampScratch? premultipliedOverlayTile(int tileX, int tileY) {
    final native = _native;
    if (native == null) {
      return null;
    }
    final buffer = _nativeBuffers[_tileKey(tileX, tileY)];
    if (buffer == null) {
      return null;
    }
    return native.premultipliedTileScratch(
      buffer.pointer,
      tileSize * tileSize,
    );
  }

  /// R27 #4 native route: pre-blends this stroke tile against [base]'s
  /// bytes through the COMMIT'S OWN C KERNELS and returns the
  /// premultiplied upload — stage base rect, blend in place
  /// (stamp srcOver / stamp erase / stroke-blend, exactly the calls the
  /// pen-up commit makes), premultiply in C. The stroke tile is already
  /// a native pointer, so nothing uploads. Null when the native route
  /// cannot serve (no engine, Dart-buffer mode, or an untouched tile) —
  /// the caller's Dart pre-blend path produces the same bytes (both
  /// sides parity-pinned against the commit).
  QaStampScratch? preBlendedOverlayTile({
    required int tileX,
    required int tileY,
    required BitmapSurface base,
    required BrushBlendMode mode,
    required bool erase,
  }) {
    final native = _native;
    if (native == null) {
      return null;
    }
    final stroke = _nativeBuffers[_tileKey(tileX, tileY)];
    if (stroke == null) {
      return null;
    }
    final tileLeft = tileX * tileSize;
    final tileTop = tileY * tileSize;
    final byteLength = tileSize * tileSize * 4;
    // R27 #4c: the memset is only needed where the base cannot fill the
    // rect — with every overlapped base tile present, the row copies
    // overwrite the whole buffer anyway.
    final staged = native.acquireTileBuffer(
      byteLength,
      zeroed: !_baseCoversRect(base, tileLeft, tileTop),
    );
    try {
      _copyBaseRectInto(staged.view, base, tileLeft, tileTop);
      native.ensureTileSpanBatch(1);
      native.setTileSpan(
        0,
        tilePixels: staged.pointer,
        tileLeft: tileLeft,
        tileTop: tileTop,
        spanLeft: tileLeft,
        spanRightExclusive: tileLeft + tileSize,
        spanTop: tileTop,
        spanBottomExclusive: tileTop + tileSize,
      );
      if (erase || mode == BrushBlendMode.erase) {
        native.stampBlendTiles(
          count: 1,
          tileSize: tileSize,
          stampBytes: stroke.pointer,
          stampWidth: tileSize,
          stampLeft: tileLeft,
          stampTop: tileTop,
          opacity: 1.0,
          erase: true,
        );
      } else if (mode == BrushBlendMode.color) {
        native.stampBlendTiles(
          count: 1,
          tileSize: tileSize,
          stampBytes: stroke.pointer,
          stampWidth: tileSize,
          stampLeft: tileLeft,
          stampTop: tileTop,
          opacity: 1.0,
          erase: false,
        );
      } else {
        native.strokeBlendTiles(
          count: 1,
          tileSize: tileSize,
          strokeBytes: stroke.pointer,
          strokeWidth: tileSize,
          strokeLeft: tileLeft,
          strokeTop: tileTop,
          mode: strokeBlendModeNativeId(mode),
        );
      }
      return native.premultipliedTileScratch(
        staged.pointer,
        tileSize * tileSize,
      );
    } finally {
      native.releaseTileBuffer(staged);
    }
  }

  /// Whether every base tile overlapping the 128-rect at ([left], [top])
  /// exists — the row copies then fill the whole staged buffer.
  bool _baseCoversRect(BitmapSurface base, int left, int top) {
    final baseTileSize = base.tileSize;
    final tileX0 = floorDiv(left, baseTileSize);
    final tileY0 = floorDiv(top, baseTileSize);
    final tileX1 = floorDiv(left + tileSize - 1, baseTileSize);
    final tileY1 = floorDiv(top + tileSize - 1, baseTileSize);
    for (var tileY = tileY0; tileY <= tileY1; tileY += 1) {
      for (var tileX = tileX0; tileX <= tileX1; tileX += 1) {
        if (base.tileAt(TileCoord(x: tileX, y: tileY)) == null) {
          return false;
        }
      }
    }
    return true;
  }

  /// Copies [base]'s straight bytes for the 128-rect at ([left], [top])
  /// into [target] (stride [tileSize]); missing base tiles stay zero.
  /// The base grid is the surface's own tile size — a stroke tile can
  /// overlap up to four base tiles.
  void _copyBaseRectInto(Uint8List target, BitmapSurface base, int left, int top) {
    final baseTileSize = base.tileSize;
    final right = left + tileSize;
    final bottom = top + tileSize;
    final tileX0 = floorDiv(left, baseTileSize);
    final tileY0 = floorDiv(top, baseTileSize);
    final tileX1 = floorDiv(right - 1, baseTileSize);
    final tileY1 = floorDiv(bottom - 1, baseTileSize);
    for (var tileY = tileY0; tileY <= tileY1; tileY += 1) {
      for (var tileX = tileX0; tileX <= tileX1; tileX += 1) {
        final tile = base.tileAt(TileCoord(x: tileX, y: tileY));
        if (tile == null) {
          continue;
        }
        final tilePixels = tile.nativePixels.asTypedList(
          baseTileSize * baseTileSize * 4,
        );
        final worldLeft = tileX * baseTileSize;
        final worldTop = tileY * baseTileSize;
        final copyLeft = math.max(left, worldLeft);
        final copyTop = math.max(top, worldTop);
        final copyRight = math.min(right, worldLeft + baseTileSize);
        final copyBottom = math.min(bottom, worldTop + baseTileSize);
        final rowBytes = (copyRight - copyLeft) * 4;
        for (var y = copyTop; y < copyBottom; y += 1) {
          final srcOffset =
              ((y - worldTop) * baseTileSize + (copyLeft - worldLeft)) * 4;
          final dstOffset = ((y - top) * tileSize + (copyLeft - left)) * 4;
          target.setRange(
            dstOffset,
            dstOffset + rowBytes,
            tilePixels,
            srcOffset,
          );
        }
      }
    }
  }

  Uint8List _tileBuffer(int tileX, int tileY) {
    return _tiles.putIfAbsent(_tileKey(tileX, tileY), () {
      final native = _native;
      if (native != null) {
        final buffer = native.acquireTileBuffer(
          tileSize * tileSize * 4,
          zeroed: true,
        );
        _nativeBuffers[_tileKey(tileX, tileY)] = buffer;
        return buffer.view;
      }
      return Uint8List(tileSize * tileSize * 4);
    });
  }

  @override
  void copyRow(int x, int y, int count, Uint8List target, int targetOffset) {
    var remaining = count;
    var sourceX = x;
    var writeOffset = targetOffset;
    final tileY = floorDiv(y, tileSize);
    final localRowOffset = (y - tileY * tileSize) * tileSize;
    while (remaining > 0) {
      final tileX = floorDiv(sourceX, tileSize);
      final tileLeft = tileX * tileSize;
      final spanCount = math.min(remaining, tileLeft + tileSize - sourceX);
      final buffer = _tiles[_tileKey(tileX, tileY)];
      if (buffer == null) {
        target.fillRange(writeOffset, writeOffset + spanCount * 4, 0);
      } else {
        final sourceOffset = (localRowOffset + (sourceX - tileLeft)) * 4;
        target.setRange(
          writeOffset,
          writeOffset + spanCount * 4,
          buffer,
          sourceOffset,
        );
      }
      remaining -= spanCount;
      sourceX += spanCount;
      writeOffset += spanCount * 4;
    }
  }

  /// Materializes the stroke's pixels within [strokeBounds] as one
  /// row-major straight-alpha buffer (stride = bounds width) — the pen-up
  /// commit fast path's input. Allocation scales with the STROKE, not the
  /// canvas.
  Uint8List? strokePixelsWithinBounds() {
    final bounds = _strokeBounds;
    if (bounds == null) {
      return null;
    }
    final boundsWidth = bounds.rightExclusive - bounds.left;
    final boundsHeight = bounds.bottomExclusive - bounds.top;
    final buffer = Uint8List(boundsWidth * boundsHeight * 4);
    for (var row = 0; row < boundsHeight; row += 1) {
      copyRow(
        bounds.left,
        bounds.top + row,
        boundsWidth,
        buffer,
        row * boundsWidth * 4,
      );
    }
    return buffer;
  }

  /// Blends `dabs[from..]` into the stroke tiles and returns the union of
  /// the newly touched region (clamped to the canvas), or `null` if nothing
  /// changed.
  DirtyRegion? blendFrom(List<BrushDab> dabs, {int? from}) {
    final start = from ?? _blendedDabCount;
    DirtyRegion? touched;

    for (var index = start; index < dabs.length; index += 1) {
      final region = _blendDab(dabs[index]);
      if (region != null) {
        touched = touched == null ? region : touched.union(region);
      }
    }
    _blendedDabCount = math.max(_blendedDabCount, dabs.length);
    if (touched != null) {
      _strokeBounds = _strokeBounds == null
          ? touched
          : _strokeBounds!.union(touched);
    }
    return touched;
  }

  DirtyRegion? _blendDab(BrushDab dab) {
    final region = dirtyRegionForBrushDab(dab);
    if (region == null) {
      return null;
    }

    final sourceArgb = dab.color;
    final sourceA = (sourceArgb >> 24) & 0xFF;
    if (sourceA == 0 || dab.opacity == 0.0 || dab.flow == 0.0) {
      return null;
    }
    final sourceR = (sourceArgb >> 16) & 0xFF;
    final sourceG = (sourceArgb >> 8) & 0xFF;
    final sourceB = sourceArgb & 0xFF;
    final sourceAlphaNorm = sourceA / 255.0;

    final radius = dab.size / 2.0;
    final hardRadius = radius * dab.hardness;
    final edgeSpan = radius - hardRadius;
    final isRound = dab.tipShape == BrushTipShape.round;
    // Elliptical / rotated tips evaluate coverage in tip space: rotate the
    // pixel offset onto the tip axes and stretch the minor axis by
    // 1/roundness, turning the ellipse test back into the circle test. The
    // classic circle (roundness == 1, rotation-invariant) and axis-aligned
    // square keep their original code path so existing strokes stay
    // byte-identical.
    final tipMask = dab.tipMask;
    final isEllipse = tipMask == null && isRound && dab.roundness < 1.0;
    final isRotatedRect =
        tipMask == null &&
        !isRound &&
        (dab.roundness < 1.0 || dab.angleDegrees != 0.0);
    var tipCos = 1.0;
    var tipSin = 0.0;
    var inverseRoundness = 1.0;
    if (isEllipse || isRotatedRect || tipMask != null) {
      final angleRadians = dab.angleDegrees * (math.pi / 180.0);
      tipCos = math.cos(angleRadians);
      tipSin = math.sin(angleRadians);
      inverseRoundness = 1.0 / dab.roundness;
    }
    final minorRadius = radius * dab.roundness;
    final centerX = dab.center.x;
    final centerY = dab.center.y;
    final dabOpacity = dab.opacity;
    final dabFlow = dab.flow;
    // Pasteboard clip — must mirror the commit rasterizer exactly
    // (live == commit byte parity).
    final top = math.max(region.top, canvasSize.pasteboardTop);
    final bottomExclusive = math.min(
      region.bottomExclusive,
      canvasSize.pasteboardBottomExclusive,
    );
    final left = math.max(region.left, canvasSize.pasteboardLeft);
    final rightExclusive = math.min(
      region.rightExclusive,
      canvasSize.pasteboardRightExclusive,
    );
    if (rightExclusive <= left || bottomExclusive <= top) {
      return null;
    }
    final columnCount = rightExclusive - left;
    final rowCount = bottomExclusive - top;

    // Per-dab hoists and axis lattices (see brush_tip_mask_sampling.dart):
    // unrotated tips and the never-rotating tiled masks sample through
    // per-axis precomputes with the scalar samplers' exact arithmetic, so
    // the resulting bytes are unchanged — the parity suites pin this.
    final dualMask = dab.dualMask;
    final textureMask = dab.textureMask;
    final textureDensity = dab.textureDensity;
    final textureOneMinusDensity = 1.0 - textureDensity;
    final unrotatedTip = tipMask != null && dab.angleDegrees == 0.0;
    // Conservative squared-distance cull for plain round tips: only pixels
    // PROVABLY outside the radius skip the sqrt; anything within the float
    // margin still runs the exact scalar test.
    final radiusSqSkip = radius * radius * (1.0 + 1e-12);

    final tipULattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: left,
            count: columnCount,
            center: centerX,
          )
        : null;
    final tipVLattice = unrotatedTip
        ? BrushTipMaskAxisLattice.compute(
            mask: tipMask,
            radius: radius,
            start: top,
            count: rowCount,
            center: centerY,
            inverseRoundness: inverseRoundness,
          )
        : null;
    final dualULattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: left,
            count: columnCount,
            originOffset: -centerX,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetU,
          );
    final dualVLattice = dualMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: dualMask,
            start: top,
            count: rowCount,
            originOffset: -centerY,
            period: dab.size * dab.dualMaskScale,
            offset: dab.dualOffsetV,
          );
    final textureULattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: left,
            count: columnCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );
    final textureVLattice = textureMask == null
        ? null
        : TiledMaskAxisLattice.compute(
            mask: textureMask,
            start: top,
            count: rowCount,
            originOffset: 0.0,
            period: textureMask.size * dab.textureScale,
            offset: 0.0,
          );

    final tileXStart = floorDiv(left, tileSize);
    final tileXEnd = floorDiv(rightExclusive - 1, tileSize);

    // R21: the C kernel runs the live blend exactly like the commit —
    // same spec, same lattices, srcOver only (the live overlay never
    // carries the erase flag; erase strokes composite at display time).
    // Byte-identical to the Dart loop below (parity-pinned).
    final native = _native;
    if (native != null && dab.stamp == null) {
      native.prepareDab(
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        hardRadius: hardRadius,
        edgeSpan: edgeSpan,
        minorRadius: minorRadius,
        tipCos: tipCos,
        tipSin: tipSin,
        inverseRoundness: inverseRoundness,
        dabOpacity: dabOpacity,
        dabFlow: dabFlow,
        sourceAlphaNorm: sourceAlphaNorm,
        radiusSqSkip: radiusSqSkip,
        textureDensity: textureDensity,
        textureOneMinusDensity: textureOneMinusDensity,
        sourceR: sourceR,
        sourceG: sourceG,
        sourceB: sourceB,
        flags:
            (isRound ? QaNativeEngine.dabFlagRound : 0) |
            (isEllipse ? QaNativeEngine.dabFlagEllipse : 0) |
            (isRotatedRect ? QaNativeEngine.dabFlagRotatedRect : 0) |
            (unrotatedTip ? QaNativeEngine.dabFlagTipUnrotated : 0),
        regionLeft: left,
        regionTop: top,
        tipAlpha: tipMask?.alphaNormalized,
        tipSize: tipMask?.size ?? 0,
        tipUTexel0: tipULattice?.texel0,
        tipUFraction: tipULattice?.fraction,
        tipUOneMinus: tipULattice?.oneMinusFraction,
        tipUInRange: tipULattice?.inRange,
        tipVTexel0: tipVLattice?.texel0,
        tipVFraction: tipVLattice?.fraction,
        tipVOneMinus: tipVLattice?.oneMinusFraction,
        tipVInRange: tipVLattice?.inRange,
        dualAlpha: dualMask?.alphaNormalized,
        dualSize: dualMask?.size ?? 0,
        dualUTexel0: dualULattice?.texel0,
        dualUTexel1: dualULattice?.texel1,
        dualUFraction: dualULattice?.fraction,
        dualUOneMinus: dualULattice?.oneMinusFraction,
        dualVTexel0: dualVLattice?.texel0,
        dualVTexel1: dualVLattice?.texel1,
        dualVFraction: dualVLattice?.fraction,
        dualVOneMinus: dualVLattice?.oneMinusFraction,
        texAlpha: textureMask?.alphaNormalized,
        texSize: textureMask?.size ?? 0,
        texUTexel0: textureULattice?.texel0,
        texUTexel1: textureULattice?.texel1,
        texUFraction: textureULattice?.fraction,
        texUOneMinus: textureULattice?.oneMinusFraction,
        texVTexel0: textureVLattice?.texel0,
        texVTexel1: textureVLattice?.texel1,
        texVFraction: textureVLattice?.fraction,
        texVOneMinus: textureVLattice?.oneMinusFraction,
      );
      final tileYStart = floorDiv(top, tileSize);
      final tileYEnd = floorDiv(bottomExclusive - 1, tileSize);
      var spanCount = 0;
      native.ensureTileSpanBatch(
        (tileYEnd - tileYStart + 1) * (tileXEnd - tileXStart + 1),
      );
      for (var tileY = tileYStart; tileY <= tileYEnd; tileY += 1) {
        final tileTop = tileY * tileSize;
        final spanTop = math.max(top, tileTop);
        final spanBottomExclusive = math.min(
          bottomExclusive,
          tileTop + tileSize,
        );
        for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
          _tileBuffer(tileX, tileY);
          final buffer = _nativeBuffers[_tileKey(tileX, tileY)]!;
          final tileLeft = tileX * tileSize;
          native.setTileSpan(
            spanCount,
            tilePixels: buffer.pointer,
            tileLeft: tileLeft,
            tileTop: tileTop,
            spanLeft: math.max(left, tileLeft),
            spanRightExclusive: math.min(rightExclusive, tileLeft + tileSize),
            spanTop: spanTop,
            spanBottomExclusive: spanBottomExclusive,
          );
          spanCount += 1;
        }
      }
      native.dabBlendTiles(count: spanCount, tileSize: tileSize);
      return DirtyRegion(
        left: left,
        top: top,
        rightExclusive: rightExclusive,
        bottomExclusive: bottomExclusive,
      );
    }

    for (var y = top; y < bottomExclusive; y += 1) {
      final dy = y + 0.5 - centerY;
      final dySquared = dy * dy;
      final vIndex = y - top;
      if (tipVLattice != null && tipVLattice.inRange[vIndex] == 0) {
        // Same effect as the scalar |tipV| > radius per-pixel cull.
        continue;
      }
      final tileY = floorDiv(y, tileSize);
      final localRowOffset = (y - tileY * tileSize) * tileSize;

      for (var tileX = tileXStart; tileX <= tileXEnd; tileX += 1) {
        final buffer = _tileBuffer(tileX, tileY);
        final tileLeft = tileX * tileSize;
        final spanLeft = math.max(left, tileLeft);
        final spanRightExclusive = math.min(
          rightExclusive,
          tileLeft + tileSize,
        );

        for (var x = spanLeft; x < spanRightExclusive; x += 1) {
          double coverage;
          if (tipMask != null) {
            if (unrotatedTip) {
              final uIndex = x - left;
              if (tipULattice!.inRange[uIndex] == 0) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverageLattice(
                mask: tipMask,
                uAxis: tipULattice,
                uIndex: uIndex,
                vAxis: tipVLattice!,
                vIndex: vIndex,
              );
            } else {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              if (tipU.abs() > radius || tipV.abs() > radius) {
                continue;
              }
              coverage = sampleBrushTipMaskCoverage(
                mask: tipMask,
                tipU: tipU,
                tipV: tipV,
                radius: radius,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else if (isRound) {
            final dx = x + 0.5 - centerX;
            double distance;
            if (isEllipse) {
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
              distance = math.sqrt(tipU * tipU + tipV * tipV);
            } else {
              final dxSquared = dx * dx;
              if (dxSquared + dySquared > radiusSqSkip) {
                continue;
              }
              distance = math.sqrt(dxSquared + dySquared);
            }
            if (distance > radius) {
              continue;
            }
            if (distance <= hardRadius || edgeSpan <= 0.0) {
              coverage = 1.0;
            } else {
              coverage = (1.0 - ((distance - hardRadius) / edgeSpan)).clamp(
                0.0,
                1.0,
              );
            }
            if (coverage <= 0.0) {
              continue;
            }
          } else {
            if (isRotatedRect) {
              final dx = x + 0.5 - centerX;
              final tipU = dx * tipCos - dy * tipSin;
              final tipV = dx * tipSin + dy * tipCos;
              if (tipU.abs() > radius || tipV.abs() > minorRadius) {
                continue;
              }
            }
            coverage = 1.0;
          }

          // Dual-brush texture: a second tiled mask multiplies the coverage
          // (must match the commit rasterizer and oracle exactly).
          if (dualMask != null) {
            coverage *= sampleBrushTipMaskTiledCoverageLattice(
              mask: dualMask,
              uAxis: dualULattice!,
              uIndex: x - left,
              vAxis: dualVLattice!,
              vIndex: vIndex,
            );
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Paper texture: canvas-anchored tiled mask, blended in by density
          // (must match the commit rasterizer and oracle exactly).
          if (textureMask != null) {
            final textureSample = sampleBrushTipMaskTiledCoverageLattice(
              mask: textureMask,
              uAxis: textureULattice!,
              uIndex: x - left,
              vAxis: textureVLattice!,
              vIndex: vIndex,
            );
            coverage *= textureOneMinusDensity + textureDensity * textureSample;
            if (coverage <= 0.0) {
              continue;
            }
          }

          // Same grouping as the commit rasterizer:
          // effectiveOpacity = dab.opacity * coverage,
          // sourceAlpha = ((a/255) * effectiveOpacity) * flow.
          final effectiveOpacity = dabOpacity * coverage;
          if (effectiveOpacity == 0.0) {
            continue;
          }
          final sourceAlpha = sourceAlphaNorm * effectiveOpacity * dabFlow;

          final offset = (localRowOffset + (x - tileLeft)) * 4;
          final destR = buffer[offset];
          final destG = buffer[offset + 1];
          final destB = buffer[offset + 2];
          final destA = buffer[offset + 3];

          final destinationAlpha = destA / 255.0;
          final outAlpha = sourceAlpha + destinationAlpha * (1.0 - sourceAlpha);
          if (outAlpha == 0.0) {
            buffer[offset] = 0;
            buffer[offset + 1] = 0;
            buffer[offset + 2] = 0;
            buffer[offset + 3] = 0;
            continue;
          }

          final inverseSourceAlpha = 1.0 - sourceAlpha;
          buffer[offset] =
              ((sourceR * sourceAlpha +
                          destR * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 1] =
              ((sourceG * sourceAlpha +
                          destG * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 2] =
              ((sourceB * sourceAlpha +
                          destB * destinationAlpha * inverseSourceAlpha) /
                      outAlpha)
                  .round()
                  .clamp(0, 255);
          buffer[offset + 3] = (outAlpha * 255.0).round().clamp(0, 255);
        }
      }
    }

    return DirtyRegion(
      left: left,
      top: top,
      rightExclusive: rightExclusive,
      bottomExclusive: bottomExclusive,
    );
  }
}
