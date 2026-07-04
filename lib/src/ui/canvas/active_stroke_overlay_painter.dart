import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';

class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.activeStrokeOverlay = const <BrushDab>[],
    this.activeStrokePath,
    this.activeStrokePathDab,
    this.activeStrokePathVersion = 0,
    this.isErase = false,
  });

  final List<BrushDab> activeStrokeOverlay;
  final Path? activeStrokePath;
  final BrushDab? activeStrokePathDab;
  final int activeStrokePathVersion;
  final bool isErase;

  @override
  void paint(Canvas canvas, Size size) {
    if (isErase) {
      canvas.saveLayer(Offset.zero & size, Paint());
    }
    _paintDabs(canvas, activeStrokeOverlay);
    if (isErase) {
      canvas.restore();
    }
  }

  void _paintDabs(Canvas canvas, List<BrushDab> dabs) {
    if (dabs.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false
      ..blendMode = isErase ? BlendMode.clear : BlendMode.srcOver;

    for (final dab in dabs) {
      paint.color = isErase ? const Color(0xFFFFFFFF) : _colorForDab(dab);
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
        oldDelegate.activeStrokePathVersion != activeStrokePathVersion ||
        oldDelegate.isErase != isErase;
  }
}
