import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import 'brush_tip_mask_cache.dart';

/// Mutable state of the in-progress stroke overlay.
///
/// A lightweight editor-local [ChangeNotifier]: the interactive view appends
/// dabs and notifies, and the overlay painter listens through the
/// `CustomPainter.repaint` hook — so pointer moves repaint the overlay layer
/// directly without rebuilding any widgets.
class ActiveStrokeOverlayModel extends ChangeNotifier {
  final List<BrushDab> dabs = <BrushDab>[];

  /// Pre-rendered stamps for `dabs[0..paintFrom)`; older stamps are folded
  /// into this image so repaints and flattens never re-touch the whole
  /// stroke.
  ui.Image? flattened;
  int paintFrom = 0;

  /// Notifies listeners after the owner mutated [dabs]/[flattened].
  void markChanged() => notifyListeners();

  /// Clears the overlay and disposes the flattened image.
  void reset() {
    flattened?.dispose();
    flattened = null;
    paintFrom = 0;
    dabs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    flattened?.dispose();
    flattened = null;
    super.dispose();
  }
}

/// Paints the in-progress stroke as sequential tip-mask stamps.
///
/// Each dab draws its cached tip alpha mask (soft round / hard square —
/// matching the commit rasterizer's coverage, including the dab's subpixel
/// phase) tinted with the dab color at `alpha * opacity * flow`. Because the
/// committed rasterizer also blends dabs sequentially with source-over, this
/// preview visually matches the committed result and is replaced by the
/// exact materialized bitmap once the commit's tiles are decoded. No bitmap
/// is baked while the pointer moves.
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.model,
    this.activeStrokeOverlay = const <BrushDab>[],
    BrushTipMaskCache? tipMaskCache,
  }) : tipMaskCache = tipMaskCache ?? BrushTipMaskCache.instance,
       super(repaint: model);

  /// Live overlay state; when set, pointer moves repaint this painter through
  /// the model's notifications without any widget rebuild.
  final ActiveStrokeOverlayModel? model;

  /// Static dab list used when no [model] is provided (tests, previews).
  final List<BrushDab> activeStrokeOverlay;

  final BrushTipMaskCache tipMaskCache;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayModel = model;
    if (overlayModel == null) {
      paintDabStamps(canvas, activeStrokeOverlay, tipMaskCache);
      return;
    }

    final flattened = overlayModel.flattened;
    if (flattened != null) {
      canvas.drawImage(flattened, Offset.zero, _imagePaint());
    }
    paintDabStamps(
      canvas,
      overlayModel.dabs,
      tipMaskCache,
      from: flattened == null ? 0 : overlayModel.paintFrom,
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
      // Draw at the floored anchor; the anchor's subpixel remainder is baked
      // into the mask itself so the stamped coverage matches the rasterizer's
      // pixel-center sampling of the true fractional dab center.
      final halfDimension = BrushTipMaskCache.dimensionFor(dab.size) / 2.0;
      final anchorX = dab.center.x - halfDimension;
      final anchorY = dab.center.y - halfDimension;
      final flooredX = anchorX.floorToDouble();
      final flooredY = anchorY.floorToDouble();
      final mask = tipMaskCache.maskFor(
        size: dab.size,
        hardness: dab.hardness,
        tipShape: dab.tipShape,
        phaseX: anchorX - flooredX,
        phaseY: anchorY - flooredY,
      );
      stampPaint.colorFilter = ColorFilter.mode(
        _tintForDab(dab),
        BlendMode.srcIn,
      );
      canvas.drawImage(mask, Offset(flooredX, flooredY), stampPaint);
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
    return !identical(oldDelegate.model, model) ||
        oldDelegate.activeStrokeOverlay != activeStrokeOverlay;
  }
}
