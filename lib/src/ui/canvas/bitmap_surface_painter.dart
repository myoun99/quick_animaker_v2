import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_dab.dart';
import '../../models/brush_paint_command.dart';

class BitmapSurfacePainter extends CustomPainter {
  BitmapSurfacePainter({
    required this.surface,
    this.showTransparentBackground = true,
    this.committedSourceDabs = const <BrushDab>[],
    this.committedSourceDabStrokes = const <List<BrushDab>>[],
    this.committedSourceCommands = const <BrushPaintCommand>[],
  });

  final BitmapSurface surface;
  final bool showTransparentBackground;
  final List<BrushDab> committedSourceDabs;
  final List<List<BrushDab>> committedSourceDabStrokes;
  final List<BrushPaintCommand> committedSourceCommands;

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

    _paintCommittedSourceCommands(canvas, size);
  }

  void _paintCommittedSourceCommands(Canvas canvas, Size size) {
    if (committedSourceCommands.isEmpty) {
      _paintCommittedSourceDabs(canvas);
      return;
    }

    canvas.saveLayer(Offset.zero & size, Paint());
    for (final command in committedSourceCommands) {
      _paintDabs(
        canvas,
        command.sourceDabs,
        isErase: command.kind == BrushPaintCommandKind.eraseStroke,
      );
    }
    canvas.restore();
  }

  void _paintCommittedSourceDabs(Canvas canvas) {
    if (committedSourceDabStrokes.isEmpty) {
      _paintDabs(canvas, committedSourceDabs);
      return;
    }

    for (final stroke in committedSourceDabStrokes) {
      _paintDabs(canvas, stroke);
    }
  }

  void _paintDabs(
    Canvas canvas,
    List<BrushDab> dabs, {
    bool isErase = false,
  }) {
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
  bool shouldRepaint(covariant BitmapSurfacePainter oldDelegate) {
    return oldDelegate.surface != surface ||
        oldDelegate.showTransparentBackground != showTransparentBackground ||
        oldDelegate.committedSourceDabs != committedSourceDabs ||
        oldDelegate.committedSourceDabStrokes != committedSourceDabStrokes ||
        oldDelegate.committedSourceCommands != committedSourceCommands;
  }
}
