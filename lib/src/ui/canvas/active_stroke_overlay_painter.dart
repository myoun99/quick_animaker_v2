import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';

class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.activeStrokeOverlay = const <BrushDab>[],
    this.activeStrokePath,
    this.activeStrokePathDab,
    this.activeStrokePathVersion = 0,
  });

  final List<BrushDab> activeStrokeOverlay;
  final Path? activeStrokePath;
  final BrushDab? activeStrokePathDab;
  final int activeStrokePathVersion;

  @override
  void paint(Canvas canvas, Size size) {
    _paintActiveStrokePath(canvas);
    _paintDabs(canvas, activeStrokeOverlay, connectAdjacentDabs: true);
  }

  void _paintActiveStrokePath(Canvas canvas) {
    final path = activeStrokePath;
    final dab = activeStrokePathDab;
    if (path == null || dab == null) {
      return;
    }

    final paint = Paint()
      ..color = _colorForDab(dab)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = dab.size;
    canvas.drawPath(path, paint);
  }

  void _paintDabs(
    Canvas canvas,
    List<BrushDab> dabs, {
    required bool connectAdjacentDabs,
  }) {
    if (dabs.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    BrushDab? previous;
    for (final dab in dabs) {
      paint.color = _colorForDab(dab);
      final center = Offset(dab.center.x, dab.center.y);
      if (connectAdjacentDabs && previous != null) {
        final previousCenter = Offset(previous.center.x, previous.center.y);
        paint.strokeWidth = (previous.size + dab.size) / 2;
        canvas.drawLine(previousCenter, center, paint);
      }
      canvas.drawCircle(center, dab.size / 2, paint);
      previous = dab;
    }
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
    return oldDelegate.activeStrokeOverlay != activeStrokeOverlay ||
        oldDelegate.activeStrokePath != activeStrokePath ||
        oldDelegate.activeStrokePathDab != activeStrokePathDab ||
        oldDelegate.activeStrokePathVersion != activeStrokePathVersion;
  }
}
