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
    _paintDabs(canvas, activeStrokeOverlay, connectAdjacentDabs: true);
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
      ..isAntiAlias = false;

    BrushDab? previous;
    for (final dab in dabs) {
      paint.color = _colorForDab(dab);
      if (connectAdjacentDabs && previous != null) {
        _paintPixelGridSegment(canvas, paint, previous, dab);
      }
      _paintPixelGridStamp(canvas, paint, dab);
      previous = dab;
    }
  }

  void _paintPixelGridSegment(
    Canvas canvas,
    Paint paint,
    BrushDab previous,
    BrushDab next,
  ) {
    final dx = next.center.x - previous.center.x;
    final dy = next.center.y - previous.center.y;
    final steps = dx.abs() > dy.abs() ? dx.abs().ceil() : dy.abs().ceil();
    if (steps <= 0) {
      return;
    }
    for (var i = 1; i <= steps; i += 1) {
      final t = i / steps;
      final dab = next.copyWith(
        center: previous.center.copyWith(
          x: previous.center.x + dx * t,
          y: previous.center.y + dy * t,
        ),
        size: previous.size + (next.size - previous.size) * t,
      );
      _paintPixelGridStamp(canvas, paint, dab);
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
    return oldDelegate.activeStrokeOverlay != activeStrokeOverlay ||
        oldDelegate.activeStrokePath != activeStrokePath ||
        oldDelegate.activeStrokePathDab != activeStrokePathDab ||
        oldDelegate.activeStrokePathVersion != activeStrokePathVersion;
  }
}
