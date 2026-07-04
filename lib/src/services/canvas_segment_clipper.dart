import '../models/canvas_point.dart';
import '../models/canvas_size.dart';

class ClippedCanvasSegment {
  const ClippedCanvasSegment({required this.start, required this.end, required this.startsNewVisibleSegment});

  final CanvasPoint start;
  final CanvasPoint end;
  final bool startsNewVisibleSegment;
}

class CanvasSegmentClipper {
  const CanvasSegmentClipper();

  ClippedCanvasSegment? clip({required CanvasPoint previous, required CanvasPoint current, required CanvasSize canvasSize}) {
    final xMin = 0.0;
    final yMin = 0.0;
    final xMax = canvasSize.width.toDouble();
    final yMax = canvasSize.height.toDouble();
    final dx = current.x - previous.x;
    final dy = current.y - previous.y;
    var t0 = 0.0;
    var t1 = 1.0;

    bool update(double p, double q) {
      if (p == 0) return q >= 0;
      final r = q / p;
      if (p < 0) {
        if (r > t1) return false;
        if (r > t0) t0 = r;
      } else {
        if (r < t0) return false;
        if (r < t1) t1 = r;
      }
      return true;
    }

    if (!update(-dx, previous.x - xMin) ||
        !update(dx, xMax - previous.x) ||
        !update(-dy, previous.y - yMin) ||
        !update(dy, yMax - previous.y) ||
        t0 > t1) {
      return null;
    }

    return ClippedCanvasSegment(
      start: CanvasPoint(x: previous.x + dx * t0, y: previous.y + dy * t0),
      end: CanvasPoint(x: previous.x + dx * t1, y: previous.y + dy * t1),
      startsNewVisibleSegment: t0 > 0 || !_inside(previous, canvasSize),
    );
  }

  bool _inside(CanvasPoint point, CanvasSize canvasSize) {
    return point.x >= 0 && point.y >= 0 && point.x <= canvasSize.width && point.y <= canvasSize.height;
  }
}
