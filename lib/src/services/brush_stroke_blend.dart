import 'dart:ffi' show Uint8Pointer;
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/bitmap_surface.dart';
import '../models/brush_blend_mode.dart';
import '../models/dirty_region.dart';
import '../models/tile_coord.dart';

/// BB-1 (R26 #9): the stroke-level blend kernel.
///
/// A brush blend applies ONCE per stroke: the live rasterizer's
/// straight-alpha stroke buffer blends against the cel's pixels within
/// the stroke bounds, and the RESULT lands through the ordinary stamp
/// kernels (an erase-rect pass then a source-over pass — see
/// `compositeStrokePixelsOntoBitmapSurface`). Never dab-by-dab:
/// overlapping dabs inside one stroke must not double-apply the mode.
///
/// Math: the W3C/Skia separable-blend equation on straight alpha —
///   αo = αs + αd(1-αs)
///   Co = [ αs(1-αd)Cs + αd(1-αs)Cd + αs·αd·B(Cs,Cd) ] / αo
/// in doubles per channel (softLight needs floats anyway; this is a
/// one-shot pen-up pass over stroke bounds, not a per-frame path). The
/// live overlay runs the SAME math per dirty tile (R27 #4,
/// [preBlendStrokeOverlayPixels]) — live and committed pixels are one
/// set of bytes, no GPU approximation anywhere.
///
/// Untouched pixels stay BYTE-EXACT: source alpha 0 copies the
/// destination verbatim (the erase-rect landing pass covers the whole
/// bounds, so any drift here would corrupt pixels the stroke never
/// touched).

/// The surface's straight-RGBA pixels within [bounds], BOUNDS-LOCAL
/// (row-major, stride = bounds width). Missing tiles read transparent.
Uint8List bitmapSurfaceRegionPixels(BitmapSurface surface, DirtyRegion bounds) {
  final width = bounds.rightExclusive - bounds.left;
  final height = bounds.bottomExclusive - bounds.top;
  final region = Uint8List(width * height * 4);
  if (width <= 0 || height <= 0) {
    return region;
  }
  final tileSize = surface.tileSize;
  final tileX0 = (bounds.left / tileSize).floor();
  final tileY0 = (bounds.top / tileSize).floor();
  final tileX1 = ((bounds.rightExclusive - 1) / tileSize).floor();
  final tileY1 = ((bounds.bottomExclusive - 1) / tileSize).floor();
  for (var tileY = tileY0; tileY <= tileY1; tileY += 1) {
    for (var tileX = tileX0; tileX <= tileX1; tileX += 1) {
      final tile = surface.tileAt(TileCoord(x: tileX, y: tileY));
      if (tile == null) {
        continue;
      }
      final tilePixels = tile.nativePixels.asTypedList(
        tileSize * tileSize * 4,
      );
      final worldLeft = tileX * tileSize;
      final worldTop = tileY * tileSize;
      final copyLeft = math.max(bounds.left, worldLeft);
      final copyTop = math.max(bounds.top, worldTop);
      final copyRight = math.min(bounds.rightExclusive, worldLeft + tileSize);
      final copyBottom = math.min(bounds.bottomExclusive, worldTop + tileSize);
      final rowBytes = (copyRight - copyLeft) * 4;
      for (var y = copyTop; y < copyBottom; y += 1) {
        final srcOffset =
            ((y - worldTop) * tileSize + (copyLeft - worldLeft)) * 4;
        final dstOffset =
            ((y - bounds.top) * width + (copyLeft - bounds.left)) * 4;
        region.setRange(dstOffset, dstOffset + rowBytes, tilePixels, srcOffset);
      }
    }
  }
  return region;
}

/// The C-side `QA_STROKE_BLEND_*` id for [mode] (BB-N1, ABI 22) — a fixed
/// FFI contract; both tables MUST stay in lockstep. color/erase never
/// reach the blend kernel (they ride the ordinary stamp path).
int strokeBlendModeNativeId(BrushBlendMode mode) {
  return switch (mode) {
    BrushBlendMode.behind => 0,
    BrushBlendMode.add => 1,
    BrushBlendMode.darken => 2,
    BrushBlendMode.multiply => 3,
    BrushBlendMode.colorBurn => 4,
    BrushBlendMode.lighten => 5,
    BrushBlendMode.screen => 6,
    BrushBlendMode.colorDodge => 7,
    BrushBlendMode.overlay => 8,
    BrushBlendMode.softLight => 9,
    BrushBlendMode.hardLight => 10,
    BrushBlendMode.difference => 11,
    BrushBlendMode.exclusion => 12,
    BrushBlendMode.color || BrushBlendMode.erase => throw ArgumentError.value(
      mode,
      'mode',
      'color/erase land through the ordinary stamp kernels',
    ),
  };
}

double _blendChannel(BrushBlendMode mode, double cs, double cd) {
  switch (mode) {
    case BrushBlendMode.darken:
      return math.min(cs, cd);
    case BrushBlendMode.multiply:
      return cs * cd;
    case BrushBlendMode.colorBurn:
      if (cd >= 1) {
        return 1;
      }
      if (cs <= 0) {
        return 0;
      }
      return 1 - math.min(1, (1 - cd) / cs);
    case BrushBlendMode.lighten:
      return math.max(cs, cd);
    case BrushBlendMode.screen:
      return cs + cd - cs * cd;
    case BrushBlendMode.colorDodge:
      if (cd <= 0) {
        return 0;
      }
      if (cs >= 1) {
        return 1;
      }
      return math.min(1, cd / (1 - cs));
    case BrushBlendMode.overlay:
      return _blendChannel(BrushBlendMode.hardLight, cd, cs);
    case BrushBlendMode.softLight:
      if (cs <= 0.5) {
        return cd - (1 - 2 * cs) * cd * (1 - cd);
      }
      final d = cd <= 0.25
          ? ((16 * cd - 12) * cd + 4) * cd
          : math.sqrt(cd);
      return cd + (2 * cs - 1) * (d - cd);
    case BrushBlendMode.hardLight:
      // multiply(2cs, cd) below the pivot, screen(2cs-1, cd) above.
      return cs <= 0.5
          ? 2 * cs * cd
          : (2 * cs - 1) + cd - (2 * cs - 1) * cd;
    case BrushBlendMode.difference:
      return (cs - cd).abs();
    case BrushBlendMode.exclusion:
      return cs + cd - 2 * cs * cd;
    case BrushBlendMode.color ||
        BrushBlendMode.behind ||
        BrushBlendMode.erase ||
        BrushBlendMode.add:
      throw ArgumentError.value(mode, 'mode', 'not a separable channel blend');
  }
}

int _clampByte(double value) {
  final rounded = (value * 255).round();
  return rounded < 0 ? 0 : (rounded > 255 ? 255 : rounded);
}

/// R27 #4: the live overlay's PRE-BLEND — the exact bytes the pen-up
/// commit will land for the region, computed the moment the tile shows.
///
/// The GPU preview approximated non-plain modes within ±1/255 because it
/// re-derived the blend in float; the user's rule is ZERO drift in every
/// mode. So the overlay stops handing the GPU anything to blend: this
/// runs the SAME per-pixel math the commit runs — [blendStrokeRegionPixels]
/// for the kernel modes, and for erase a byte-exact mirror of the stamp
/// kernel's destination-out at opacity 1 (the erase landing IS one stamp
/// of the stroke buffer — see `compositeStrokePixelsOntoBitmapSurface`).
/// The result draws as a plain REPLACEMENT tile, so pen-up cannot move a
/// byte: identical bytes flow into identical composites.
///
/// [dst]/[src] are BOUNDS-LOCAL straight RGBA; [erase] covers both the
/// eraser tool and the 소거 blend mode (the tool locks the mode, so the
/// two arrive together). [BrushBlendMode.color] never comes here — plain
/// srcOver previews directly and stays on the GPU path.
Uint8List preBlendStrokeOverlayPixels({
  required Uint8List dst,
  required Uint8List src,
  required BrushBlendMode mode,
  required bool erase,
  required int pixelCount,
}) {
  if (erase || mode == BrushBlendMode.erase) {
    // Mirror of the stamp-ERASE per-pixel path at dabOpacity 1
    // (bitmap_surface_brush_commit): sa==0 leaves the pixel verbatim,
    // sa==255 zeroes it byte-hard, and the general case scales alpha
    // through the same double expression — the parity test pins this
    // against the real commit, native kernel included.
    final result = Uint8List(pixelCount * 4);
    for (var i = 0; i < pixelCount; i += 1) {
      final o = i * 4;
      final sa = src[o + 3];
      if (sa == 0) {
        result[o] = dst[o];
        result[o + 1] = dst[o + 1];
        result[o + 2] = dst[o + 2];
        result[o + 3] = dst[o + 3];
        continue;
      }
      if (sa == 255) {
        continue; // Already zeroed.
      }
      final sourceAlpha = sa / 255.0;
      final outAlpha = (dst[o + 3] / 255.0) * (1.0 - sourceAlpha);
      if (outAlpha == 0.0) {
        continue; // Already zeroed.
      }
      result[o] = dst[o];
      result[o + 1] = dst[o + 1];
      result[o + 2] = dst[o + 2];
      result[o + 3] = (outAlpha * 255.0).round().clamp(0, 255);
    }
    return result;
  }
  assert(
    mode != BrushBlendMode.color,
    'color previews srcOver directly — no pre-blend',
  );
  final result = blendStrokeRegionPixels(
    dst: dst,
    src: src,
    mode: mode,
    pixelCount: pixelCount,
  );
  // Mirror the LANDING normalization: the commit lands the kernel result
  // through an erase-clear + srcOver stamp, whose srcOver skips α==0
  // pixels — a fully transparent result pixel therefore lands as
  // (0,0,0,0) whatever RGB the kernel's verbatim-copy rule carried (the
  // native kernel mirrors the same rule). Without this the straight
  // bytes differ where the base held α==0 junk RGB, even though both
  // display identically after premultiply.
  for (var i = 0; i < pixelCount; i += 1) {
    final o = i * 4;
    if (result[o + 3] == 0) {
      result[o] = 0;
      result[o + 1] = 0;
      result[o + 2] = 0;
    }
  }
  return result;
}

/// Blends the stroke buffer [src] against the cel region [dst] (both
/// BOUNDS-LOCAL straight RGBA of [pixelCount] pixels) through [mode],
/// returning the RESULT region the landing pass writes verbatim.
Uint8List blendStrokeRegionPixels({
  required Uint8List dst,
  required Uint8List src,
  required BrushBlendMode mode,
  required int pixelCount,
}) {
  assert(mode != BrushBlendMode.color && mode != BrushBlendMode.erase,
      'color/erase land through the ordinary stamp kernels');
  final result = Uint8List(pixelCount * 4);
  for (var i = 0; i < pixelCount; i += 1) {
    final o = i * 4;
    final sa = src[o + 3];
    if (sa == 0) {
      result[o] = dst[o];
      result[o + 1] = dst[o + 1];
      result[o + 2] = dst[o + 2];
      result[o + 3] = dst[o + 3];
      continue;
    }
    final da = dst[o + 3];
    if (mode == BrushBlendMode.behind) {
      if (da == 255) {
        result[o] = dst[o];
        result[o + 1] = dst[o + 1];
        result[o + 2] = dst[o + 2];
        result[o + 3] = 255;
        continue;
      }
      if (da == 0) {
        result[o] = src[o];
        result[o + 1] = src[o + 1];
        result[o + 2] = src[o + 2];
        result[o + 3] = sa;
        continue;
      }
      // destination-over on straight alpha.
      final as_ = sa / 255.0, ad = da / 255.0;
      final ao = ad + as_ * (1 - ad);
      for (var c = 0; c < 3; c += 1) {
        result[o + c] = _clampByte(
          (ad * dst[o + c] / 255.0 + (1 - ad) * as_ * src[o + c] / 255.0) / ao,
        );
      }
      result[o + 3] = _clampByte(ao);
      continue;
    }
    if (da == 0) {
      result[o] = src[o];
      result[o + 1] = src[o + 1];
      result[o + 2] = src[o + 2];
      result[o + 3] = sa;
      continue;
    }
    final as_ = sa / 255.0, ad = da / 255.0;
    if (mode == BrushBlendMode.add) {
      // Skia plus: saturating premultiplied add.
      final ao = math.min(1.0, as_ + ad);
      for (var c = 0; c < 3; c += 1) {
        final premul = math.min(
          1.0,
          src[o + c] / 255.0 * as_ + dst[o + c] / 255.0 * ad,
        );
        result[o + c] = _clampByte(premul / ao);
      }
      result[o + 3] = _clampByte(ao);
      continue;
    }
    final ao = as_ + ad * (1 - as_);
    for (var c = 0; c < 3; c += 1) {
      final cs = src[o + c] / 255.0, cd = dst[o + c] / 255.0;
      final b = _blendChannel(mode, cs, cd);
      result[o + c] = _clampByte(
        (as_ * (1 - ad) * cs + ad * (1 - as_) * cd + as_ * ad * b) / ao,
      );
    }
    result[o + 3] = _clampByte(ao);
  }
  return result;
}
