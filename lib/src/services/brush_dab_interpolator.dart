import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/canvas_point.dart';

/// Lightweight Brush T2 dab spacing/interpolation.
///
/// This keeps input sampling independent from Flutter pointer types. The spacing
/// interval is based on the materialized brush size and editor-session spacing
/// ratio, clamped to at least one canvas unit to prevent excessive dab counts.
class BrushDabInterpolator {
  const BrushDabInterpolator();

  double spacingForBrushSize(double brushSize, double spacingRatio) {
    if (!brushSize.isFinite || brushSize <= 0 || !spacingRatio.isFinite) {
      return 1.0;
    }
    return math.max(1.0, brushSize * spacingRatio);
  }

  List<BrushDab> interpolate({
    required BrushDab? previous,
    required BrushDab nextRaw,
    required int firstSequence,
    double spacingRatio = 0.25,
  }) {
    if (previous == null) {
      return [nextRaw.copyWith(sequence: firstSequence)];
    }

    final spacing = spacingForBrushSize(nextRaw.size, spacingRatio);
    final dx = nextRaw.center.x - previous.center.x;
    final dy = nextRaw.center.y - previous.center.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < spacing) {
      return const <BrushDab>[];
    }

    final stepCount = math.max(1, (distance / spacing).ceil());
    return List<BrushDab>.generate(stepCount, (index) {
      final fraction = (index + 1) / stepCount;
      return nextRaw.copyWith(
        center: CanvasPoint(
          x: previous.center.x + dx * fraction,
          y: previous.center.y + dy * fraction,
        ),
        sequence: firstSequence + index,
      );
    });
  }
}
