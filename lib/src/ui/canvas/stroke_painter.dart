import 'package:flutter/material.dart';

import '../../models/brush_settings.dart';
import '../../models/stroke.dart';
import '../../models/stroke_point.dart';

class StrokePainter extends CustomPainter {
  const StrokePainter({
    required this.strokes,
    this.activePoints = const <StrokePoint>[],
  });

  final List<Stroke> strokes;
  final List<StrokePoint> activePoints;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    for (final stroke in strokes) {
      _paintPoints(canvas, stroke.points, stroke.brushSettings);
    }

    _paintPoints(canvas, activePoints, const BrushSettings(opacity: 0.6));

    final borderPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Offset.zero & size, borderPaint);
  }

  @override
  bool shouldRepaint(covariant StrokePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.activePoints != activePoints;
  }

  void _paintPoints(
    Canvas canvas,
    List<StrokePoint> points,
    BrushSettings brushSettings,
  ) {
    if (points.isEmpty) {
      return;
    }

    final paint = Paint()
      ..color = _colorForBrush(brushSettings)
      ..strokeWidth = brushSettings.size
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (points.length == 1) {
      final point = points.first;
      canvas.drawCircle(
        Offset(point.x, point.y),
        brushSettings.size / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(points.first.x, points.first.y);
    for (final point in points.skip(1)) {
      path.lineTo(point.x, point.y);
    }
    canvas.drawPath(path, paint);
  }

  Color _colorForBrush(BrushSettings brushSettings) {
    final argb = brushSettings.color;
    final alpha = (argb >> 24) & 0xFF;
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    final opacity = brushSettings.opacity.clamp(0.0, 1.0);

    return Color.fromARGB((alpha * opacity).round(), red, green, blue);
  }
}
