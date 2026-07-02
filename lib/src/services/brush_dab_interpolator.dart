import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/canvas_point.dart';

/// Lightweight Brush T2 dab spacing/interpolation.
///
/// This keeps input sampling independent from Flutter pointer types. The spacing
/// is intentionally simple: one quarter of brush size, clamped to at least one
/// canvas unit. It fills fast pointer gaps without generating duplicate dabs for
/// tiny movement below the spacing threshold.
class BrushDabInterpolator {
  const BrushDabInterpolator({this.spacingRatio = 0.25});

  final double spacingRatio;

  double spacingForBrushSize(double brushSize) {
    if (!brushSize.isFinite || brushSize <= 0) {
      return 1.0;
    }
    return math.max(1.0, brushSize * spacingRatio);
  }

  List<BrushDab> interpolate({
    required BrushDab? previous,
    required BrushDab nextRaw,
    required int firstSequence,
  }) {
    if (previous == null) {
      return [nextRaw.copyWith(sequence: firstSequence)];
    }

    final spacing = spacingForBrushSize(nextRaw.size);
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
