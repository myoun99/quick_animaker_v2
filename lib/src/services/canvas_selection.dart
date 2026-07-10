import 'dart:math' as math;

import '../models/brush_dab.dart';
import '../models/brush_paint_command.dart';
import '../models/brush_paint_command_id.dart';
import '../models/canvas_point.dart';

/// A selection region in canvas coordinates (P9): a closed polygon — the
/// rectangle marquee is its 4-corner special case, the lasso is the
/// freehand path as drawn.
class CanvasSelectionShape {
  CanvasSelectionShape(List<CanvasPoint> points)
    : points = List<CanvasPoint>.unmodifiable(points),
      assert(points.length >= 3, 'a selection polygon needs 3+ points');

  factory CanvasSelectionShape.rect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) {
    final minX = math.min(left, right);
    final maxX = math.max(left, right);
    final minY = math.min(top, bottom);
    final maxY = math.max(top, bottom);
    return CanvasSelectionShape([
      CanvasPoint(x: minX, y: minY),
      CanvasPoint(x: maxX, y: minY),
      CanvasPoint(x: maxX, y: maxY),
      CanvasPoint(x: minX, y: maxY),
    ]);
  }

  final List<CanvasPoint> points;

  /// Even-odd ray cast (the polygon closes implicitly).
  bool containsPoint(CanvasPoint point) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i, i += 1) {
      final a = points[i];
      final b = points[j];
      final crosses =
          (a.y > point.y) != (b.y > point.y) &&
          point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x;
      if (crosses) {
        inside = !inside;
      }
    }
    return inside;
  }

  CanvasSelectionShape translated({required double dx, required double dy}) {
    return CanvasSelectionShape([
      for (final point in points) CanvasPoint(x: point.x + dx, y: point.y + dy),
    ]);
  }
}

/// The commands a selection shape captures (P9 backend rule): a command
/// joins when at least [threshold] of its dabs' CENTERS fall inside the
/// shape — stroke-level selection, deliberately not a raster cut-stamp.
Set<BrushPaintCommandId> selectCommandIdsInShape({
  required List<BrushPaintCommand> commands,
  required CanvasSelectionShape shape,
  double threshold = 0.6,
}) {
  final selected = <BrushPaintCommandId>{};
  for (final command in commands) {
    if (command.sourceDabs.isEmpty) {
      continue;
    }
    var inside = 0;
    for (final dab in command.sourceDabs) {
      if (shape.containsPoint(dab.center)) {
        inside += 1;
      }
    }
    if (inside / command.sourceDabs.length >= threshold) {
      selected.add(command.id);
    }
  }
  return selected;
}

/// The selected dabs translated by (dx, dy) — the P9 move. Only geometry
/// moves; every brush property (size, masks, dynamics) rides along
/// untouched so the re-render is stroke-identical elsewhere.
List<BrushDab> translateDabs(
  List<BrushDab> dabs, {
  required double dx,
  required double dy,
}) {
  return [
    for (final dab in dabs)
      dab.copyWith(
        center: CanvasPoint(x: dab.center.x + dx, y: dab.center.y + dy),
      ),
  ];
}
