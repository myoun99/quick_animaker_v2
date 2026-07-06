import '../models/brush_tip_mask.dart';

/// Bilinear coverage sample of a sampled brush tip at a tip-space offset.
///
/// [tipU]/[tipV] are the pixel-center offset rotated onto the tip axes with
/// the minor axis already stretched by `1/roundness` (the same tip-space
/// transform the parametric elliptical tips use), so the mask always maps
/// onto the square `[-radius, radius]^2`. Texels outside the mask read as
/// zero, so coverage fades out cleanly at the tip border.
///
/// This is THE single coverage implementation for sampled tips: the commit
/// rasterizer, the live rasterizer, and the per-pixel oracle all call it, so
/// live and committed pixels stay byte-identical by construction.
double sampleBrushTipMaskCoverage({
  required BrushTipMask mask,
  required double tipU,
  required double tipV,
  required double radius,
}) {
  final scale = mask.size / (2.0 * radius);
  final maskX = (tipU + radius) * scale - 0.5;
  final maskY = (tipV + radius) * scale - 0.5;
  final x0 = maskX.floor();
  final y0 = maskY.floor();
  final fractionX = maskX - x0;
  final fractionY = maskY - y0;

  final size = mask.size;
  final alpha = mask.alpha;
  double texel(int x, int y) {
    if (x < 0 || y < 0 || x >= size || y >= size) {
      return 0.0;
    }
    return alpha[y * size + x] / 255.0;
  }

  final top =
      texel(x0, y0) * (1.0 - fractionX) + texel(x0 + 1, y0) * fractionX;
  final bottom =
      texel(x0, y0 + 1) * (1.0 - fractionX) +
      texel(x0 + 1, y0 + 1) * fractionX;
  return (top * (1.0 - fractionY) + bottom * fractionY).clamp(0.0, 1.0);
}

/// Tiled (wrapping) bilinear coverage sample — the dual-brush texture.
///
/// [dx]/[dy] are the pixel-center offset from the dab center in canvas
/// pixels, [period] the tile size in canvas pixels, and [offsetU]/[offsetV]
/// the dab's random phase in tile fractions. Like [sampleBrushTipMaskCoverage]
/// this is THE single implementation all rasterizers call, keeping live and
/// committed pixels byte-identical.
double sampleBrushTipMaskTiledCoverage({
  required BrushTipMask mask,
  required double dx,
  required double dy,
  required double period,
  required double offsetU,
  required double offsetV,
}) {
  final size = mask.size;
  final alpha = mask.alpha;
  var u = dx / period + offsetU;
  var v = dy / period + offsetV;
  u -= u.floorToDouble();
  v -= v.floorToDouble();
  final maskX = u * size - 0.5;
  final maskY = v * size - 0.5;
  final x0 = maskX.floor();
  final y0 = maskY.floor();
  final fractionX = maskX - x0;
  final fractionY = maskY - y0;

  double texel(int x, int y) {
    final wrappedX = ((x % size) + size) % size;
    final wrappedY = ((y % size) + size) % size;
    return alpha[wrappedY * size + wrappedX] / 255.0;
  }

  final top =
      texel(x0, y0) * (1.0 - fractionX) + texel(x0 + 1, y0) * fractionX;
  final bottom =
      texel(x0, y0 + 1) * (1.0 - fractionX) +
      texel(x0 + 1, y0 + 1) * fractionX;
  return (top * (1.0 - fractionY) + bottom * fractionY).clamp(0.0, 1.0);
}
