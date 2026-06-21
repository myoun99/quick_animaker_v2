import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/brush_pixel_coverage.dart';
import '../models/brush_tip_shape.dart';
import 'brush_dab_dirty_region.dart';

List<BrushPixelCoverage> brushPixelCoveragesForDab(BrushDab dab) {
  final dirtyRegion = dirtyRegionForBrushDab(dab);
  if (dirtyRegion == null) {
    return List<BrushPixelCoverage>.unmodifiable(const []);
  }

  final coverages = <BrushPixelCoverage>[];
  final radius = dab.size / 2.0;
  final hardRadius = radius * dab.hardness;

  for (var y = dirtyRegion.top; y < dirtyRegion.bottomExclusive; y += 1) {
    for (var x = dirtyRegion.left; x < dirtyRegion.rightExclusive; x += 1) {
      switch (dab.tipShape) {
        case BrushTipShape.square:
          coverages.add(BrushPixelCoverage(x: x, y: y, coverage: 1.0));
        case BrushTipShape.round:
          final dx = x + 0.5 - dab.center.x;
          final dy = y + 0.5 - dab.center.y;
          final distance = math.sqrt(dx * dx + dy * dy);

          if (distance > radius) {
            continue;
          }

          final coverage = _roundCoverage(
            distance: distance,
            radius: radius,
            hardRadius: hardRadius,
          );
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
