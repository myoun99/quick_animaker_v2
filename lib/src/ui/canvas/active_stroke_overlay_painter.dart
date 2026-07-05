import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import 'brush_tip_mask_cache.dart';

/// Paints the in-progress stroke as sequential tip-mask stamps.
///
/// Each dab draws its cached tip alpha mask (soft round / hard square —
/// matching the commit rasterizer's coverage) tinted with the dab color at
/// `alpha * opacity * flow`. Because the committed rasterizer also blends
/// dabs sequentially with source-over, this preview visually matches the
/// committed result and is replaced by the exact materialized bitmap on
/// pointer-up. No bitmap is baked while the pointer moves.
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.activeStrokeOverlay = const <BrushDab>[],
    BrushTipMaskCache? tipMaskCache,
  }) : tipMaskCache = tipMaskCache ?? BrushTipMaskCache.instance;

  final List<BrushDab> activeStrokeOverlay;
  final BrushTipMaskCache tipMaskCache;

  final Paint _stampPaint = Paint()
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.none;

  @override
  void paint(Canvas canvas, Size size) {
    for (final dab in activeStrokeOverlay) {
      final mask = tipMaskCache.maskFor(
        size: dab.size,
        hardness: dab.hardness,
        tipShape: dab.tipShape,
      );
      _stampPaint.colorFilter = ColorFilter.mode(
        _tintForDab(dab),
        BlendMode.srcIn,
      );
      canvas.drawImage(
        mask,
        Offset(
          dab.center.x - mask.width / 2.0,
          dab.center.y - mask.height / 2.0,
        ),
        _stampPaint,
      );
    }
  }

  Color _tintForDab(BrushDab dab) {
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
    return oldDelegate.activeStrokeOverlay != activeStrokeOverlay;
  }
}
