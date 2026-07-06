import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/brush_pixel_coverage.dart';
import '../models/brush_tip_shape.dart';
import 'brush_dab_dirty_region.dart';
import 'brush_tip_mask_sampling.dart';

List<BrushPixelCoverage> brushPixelCoveragesForDab(BrushDab dab) {
  final dirtyRegion = dirtyRegionForBrushDab(dab);
  if (dirtyRegion == null) {
    return List<BrushPixelCoverage>.unmodifiable(const []);
  }

  final coverages = <BrushPixelCoverage>[];
  final radius = dab.size / 2.0;
  final hardRadius = radius * dab.hardness;

  // Elliptical / rotated tips evaluate coverage in tip space: rotate the
  // pixel offset onto the tip axes and stretch the minor axis by
  // 1/roundness, turning the ellipse test back into the circle test. The
  // classic circle (roundness == 1, rotation-invariant) and axis-aligned
  // square keep their original code path so existing strokes stay
  // byte-identical. Must match the commit and live rasterizers exactly.
  final isRound = dab.tipShape == BrushTipShape.round;
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

  // Dual-brush texture factor; must multiply coverage with the exact same
  // float grouping as the commit and live rasterizers.
  final dualMask = dab.dualMask;
  double dualFactorAt(int x, int y) {
    if (dualMask == null) {
      return 1.0;
    }
    return sampleBrushTipMaskTiledCoverage(
      mask: dualMask,
      dx: x + 0.5 - dab.center.x,
      dy: y + 0.5 - dab.center.y,
      period: dab.size * dab.dualMaskScale,
      offsetU: dab.dualOffsetU,
      offsetV: dab.dualOffsetV,
    );
  }

  for (var y = dirtyRegion.top; y < dirtyRegion.bottomExclusive; y += 1) {
    for (var x = dirtyRegion.left; x < dirtyRegion.rightExclusive; x += 1) {
      if (tipMask != null) {
        final dx = x + 0.5 - dab.center.x;
        final dy = y + 0.5 - dab.center.y;
        final tipU = dx * tipCos - dy * tipSin;
        final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
        if (tipU.abs() > radius || tipV.abs() > radius) {
          continue;
        }
        var coverage = sampleBrushTipMaskCoverage(
          mask: tipMask,
          tipU: tipU,
          tipV: tipV,
          radius: radius,
        );
        if (coverage <= 0.0) {
          continue;
        }
        coverage *= dualFactorAt(x, y);
        if (coverage <= 0.0) {
          continue;
        }
        coverages.add(BrushPixelCoverage(x: x, y: y, coverage: coverage));
        continue;
      }
      switch (dab.tipShape) {
        case BrushTipShape.square:
          if (isRotatedRect) {
            final dx = x + 0.5 - dab.center.x;
            final dy = y + 0.5 - dab.center.y;
            final tipU = dx * tipCos - dy * tipSin;
            final tipV = dx * tipSin + dy * tipCos;
            if (tipU.abs() > radius || tipV.abs() > minorRadius) {
              continue;
            }
          }
          var coverage = 1.0;
          coverage *= dualFactorAt(x, y);
          if (coverage <= 0.0) {
            continue;
          }
          coverages.add(BrushPixelCoverage(x: x, y: y, coverage: coverage));
        case BrushTipShape.round:
          final dx = x + 0.5 - dab.center.x;
          final dy = y + 0.5 - dab.center.y;
          double distance;
          if (isEllipse) {
            final tipU = dx * tipCos - dy * tipSin;
            final tipV = (dx * tipSin + dy * tipCos) * inverseRoundness;
            distance = math.sqrt(tipU * tipU + tipV * tipV);
          } else {
            distance = math.sqrt(dx * dx + dy * dy);
          }

          if (distance > radius) {
            continue;
          }

          var coverage = _roundCoverage(
            distance: distance,
            radius: radius,
            hardRadius: hardRadius,
          );
          if (coverage <= 0.0) {
            continue;
          }
          coverage *= dualFactorAt(x, y);
          if (coverage <= 0.0) {
            continue;
          }

          coverages.add(BrushPixelCoverage(x: x, y: y, coverage: coverage));
      }
    }
  }

  return List<BrushPixelCoverage>.unmodifiable(coverages);
}

double _roundCoverage({
  required double distance,
  required double radius,
  required double hardRadius,
}) {
  if (distance <= hardRadius) {
    return 1.0;
  }

  final edgeSpan = radius - hardRadius;
  if (edgeSpan <= 0.0) {
    return 1.0;
  }

  return (1.0 - ((distance - hardRadius) / edgeSpan)).clamp(0.0, 1.0);
}
