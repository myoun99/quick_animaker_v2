import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import 'brush_tip_mask_cache.dart';

/// Paints the in-progress stroke as sequential tip-mask stamps.
///
/// Each dab draws its cached tip alpha mask (soft round / hard square —
/// matching the commit rasterizer's coverage) tinted with the dab color at
/// `alpha * opacity * flow`. Because the committed rasterizer also blends
/// dabs sequentially with source-over, this preview visually matches the
/// committed result and is replaced by the exact materialized bitmap once
/// the commit's tiles are decoded. No bitmap is baked while the pointer
/// moves.
///
/// Long strokes stay O(1) per repaint: the interactive view periodically
/// flattens already-stamped dabs into [flattenedOverlay] (via
/// `Picture.toImageSync`), so this painter draws one image plus only the
/// dabs stamped since the last flatten ([paintFrom] onwards).
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.activeStrokeOverlay = const <BrushDab>[],
    this.flattenedOverlay,
    this.paintFrom = 0,
    this.overlayRevision = 0,
    BrushTipMaskCache? tipMaskCache,
  }) : tipMaskCache = tipMaskCache ?? BrushTipMaskCache.instance;

  final List<BrushDab> activeStrokeOverlay;

  /// Pre-rendered stamps for `activeStrokeOverlay[0..paintFrom)`, drawn at the
  /// canvas origin. Owned by the interactive view.
  final ui.Image? flattenedOverlay;

  /// Index of the first dab not yet included in [flattenedOverlay].
  final int paintFrom;

  /// Monotonic revision bumped by the view whenever the overlay content
  /// changes; used instead of deep/list-identity comparisons so the view can
  /// append into one growable list without copying it per pointer move.
  final int overlayRevision;

  final BrushTipMaskCache tipMaskCache;

  @override
  void paint(Canvas canvas, Size size) {
    final flattened = flattenedOverlay;
    if (flattened != null) {
      canvas.drawImage(flattened, Offset.zero, _imagePaint());
    }
    paintDabStamps(
      canvas,
      activeStrokeOverlay,
      tipMaskCache,
      from: flattened == null ? 0 : paintFrom,
    );
  }

  static Paint _imagePaint() => Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  /// Stamps `dabs[from..]` onto [canvas]. Shared by the live painter and the
  /// interactive view's flatten step so both produce identical pixels.
  static void paintDabStamps(
    Canvas canvas,
    List<BrushDab> dabs,
    BrushTipMaskCache tipMaskCache, {
    int from = 0,
  }) {
    final stampPaint = _imagePaint();
    for (var index = from; index < dabs.length; index += 1) {
      final dab = dabs[index];
      final mask = tipMaskCache.maskFor(
        size: dab.size,
        hardness: dab.hardness,
        tipShape: dab.tipShape,
      );
      stampPaint.colorFilter = ColorFilter.mode(
        _tintForDab(dab),
        BlendMode.srcIn,
      );
      // Integer-snapped offsets keep mask texels aligned with canvas pixels,
      // so edges stay stable while drawing instead of shimmering at subpixel
      // offsets, and match the rasterizer's pixel-center coverage grid.
      canvas.drawImage(
        mask,
        Offset(
          (dab.center.x - mask.width / 2.0).roundToDouble(),
          (dab.center.y - mask.height / 2.0).roundToDouble(),
        ),
        stampPaint,
      );
    }
  }

  static Color _tintForDab(BrushDab dab) {
    final argb = dab.color;
    final alpha = (argb >> 24) & 0xFF;
    // Same strength grouping as the commit rasterizer's
    // sourceAlpha = (alpha / 255) * opacity * flow; per-pixel coverage comes
    // from the mask's own alpha through the srcIn color filter.
    final effectiveAlpha = (alpha * dab.opacity * dab.flow).round().clamp(
      0,
      255,
    );
    return Color.fromARGB(
      effectiveAlpha,
      (argb >> 16) & 0xFF,
      (argb >> 8) & 0xFF,
      argb & 0xFF,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokeOverlayPainter oldDelegate) {
    return oldDelegate.overlayRevision != overlayRevision ||
        oldDelegate.activeStrokeOverlay != activeStrokeOverlay ||
        !identical(oldDelegate.flattenedOverlay, flattenedOverlay);
  }
}
