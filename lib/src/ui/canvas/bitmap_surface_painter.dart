import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';

class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
    this.committedSourceDabs = const <BrushDab>[],
    this.committedSourceDabStrokes = const <List<BrushDab>>[],
    this.activeStrokeOverlay = const <BrushDab>[],
    this.activeStrokePath,
    this.activeStrokePathDab,
    this.activeStrokePathVersion = 0,
  });

  final BitmapSurface surface;
  final bool showTransparentBackground;
  final List<BrushDab> committedSourceDabs;
  final List<List<BrushDab>> committedSourceDabStrokes;
  final List<BrushDab> activeStrokeOverlay;
  final Path? activeStrokePath;
  final BrushDab? activeStrokePathDab;
  final int activeStrokePathVersion;

  @override
  void paint(Canvas canvas, Size size) {
    if (showTransparentBackground) {
      final backgroundPaint = Paint()..color = const Color(0xFFEDEDED);
      canvas.drawRect(Offset.zero & size, backgroundPaint);
    }

    final pixelPaint = Paint()..style = PaintingStyle.fill;
    for (final tile in surface.tiles.values) {
      final pixels = tile.pixels;
      final tileOriginX = tile.coord.x * tile.size;
      final tileOriginY = tile.coord.y * tile.size;

      for (var localY = 0; localY < tile.size; localY += 1) {
        final globalY = tileOriginY + localY;
        if (globalY < 0 || globalY >= surface.canvasSize.height) {
          continue;
        }

        for (var localX = 0; localX < tile.size; localX += 1) {
          final globalX = tileOriginX + localX;
          if (globalX < 0 || globalX >= surface.canvasSize.width) {
            continue;
          }

          final offset = (localY * tile.size + localX) * 4;
          final r = pixels[offset];
          final g = pixels[offset + 1];
          final b = pixels[offset + 2];
          final a = pixels[offset + 3];
          if (a == 0) {
            continue;
          }

          pixelPaint.color = Color.fromARGB(a, r, g, b);
          canvas.drawRect(
            Rect.fromLTWH(globalX.toDouble(), globalY.toDouble(), 1, 1),
            pixelPaint,
          );
        }
      }
    }

    _paintCommittedSourceDabs(canvas);
    _paintActiveStrokePath(canvas);
    _paintActiveStrokeOverlay(canvas);
  }

  void _paintCommittedSourceDabs(Canvas canvas) {
    if (committedSourceDabStrokes.isEmpty) {
      _paintDabs(canvas, committedSourceDabs, connectAdjacentDabs: false);
      return;
    }

    for (final stroke in committedSourceDabStrokes) {
      _paintDabs(canvas, stroke, connectAdjacentDabs: true);
    }
  }

  void _paintActiveStrokePath(Canvas canvas) {
    final path = activeStrokePath;
    final dab = activeStrokePathDab;
    if (path == null || dab == null) {
      return;
    }

    final paint = _paintForDab(dab)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = dab.size;
    canvas.drawPath(path, paint);
  }

  void _paintActiveStrokeOverlay(Canvas canvas) {
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

  Paint _paintForDab(BrushDab dab) {
    return Paint()..color = _colorForDab(dab);
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
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate) {
    return oldDelegate.surface != surface ||
        oldDelegate.showTransparentBackground != showTransparentBackground ||
        oldDelegate.committedSourceDabs != committedSourceDabs ||
        oldDelegate.committedSourceDabStrokes != committedSourceDabStrokes ||
        oldDelegate.activeStrokeOverlay != activeStrokeOverlay ||
        oldDelegate.activeStrokePath != activeStrokePath ||
        oldDelegate.activeStrokePathDab != activeStrokePathDab ||
        oldDelegate.activeStrokePathVersion != activeStrokePathVersion;
  }
}
