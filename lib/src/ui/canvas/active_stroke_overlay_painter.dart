import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';

class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({this.activeStrokeOverlay = const <BrushDab>[]});

  final List<BrushDab> activeStrokeOverlay;

  final Paint _dabPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    _paintDabs(canvas, activeStrokeOverlay);
  }

  void _paintDabs(Canvas canvas, List<BrushDab> dabs) {
    if (dabs.isEmpty) {
      return;
    }

    for (final dab in dabs) {
      _dabPaint.color = _colorForDab(dab);
      _paintPixelGridStamp(canvas, _dabPaint, dab);
    }
  }

  void _paintPixelGridStamp(Canvas canvas, Paint paint, BrushDab dab) {
    final diameter = dab.size.clamp(1, double.infinity).ceilToDouble();
    final left = (dab.center.x - diameter / 2).roundToDouble();
    final top = (dab.center.y - diameter / 2).roundToDouble();
    canvas.drawRect(Rect.fromLTWH(left, top, diameter, diameter), paint);
  }

  Color _colorForDab(BrushDab dab) {
    final argb = dab.color;
    final alpha = (argb >> 24) & 0xFF;
    final red = (argb >> 16) & 0xFF;
    final green = (argb >> 8) & 0xFF;
    final blue = argb & 0xFF;
    return Color.fromARGB(
      (alpha * dab.opacity).clamp(0, 255).round(),
      red,
      green,
      blue,
    );
  }

  @override
  bool shouldRepaint(covariant ActiveStrokeOverlayPainter oldDelegate) {
    return oldDelegate.activeStrokeOverlay != activeStrokeOverlay;
  }
}
