import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/brush_settings.dart';
import '../../models/brush_tip_mask.dart';
import '../../models/brush_tip_shape.dart';

/// A small synchronous preview of a brush tip for preset lists.
///
/// Sampled tips render as a coarse grid averaged from the mask's alpha
/// bytes (no async image decode, so it is deterministic in widget tests);
/// parametric tips render their ellipse/square shape with roundness, angle,
/// and a soft outer ring when hardness is low. This is a shape hint, not a
/// rasterizer-accurate rendering.
class BrushTipPreview extends StatelessWidget {
  const BrushTipPreview({super.key, required this.settings});

  final BrushSettings settings;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BrushTipPreviewPainter(settings: settings, color: color),
        size: Size.infinite,
      ),
    );
  }
}

class _BrushTipPreviewPainter extends CustomPainter {
  const _BrushTipPreviewPainter({required this.settings, required this.color});

  final BrushSettings settings;
  final Color color;

  /// Preview raster resolution for sampled tips (cells per edge).
  static const int _maskGrid = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final mask = settings.tipMask;
    if (mask != null) {
      _paintMask(canvas, size, mask);
    } else {
      _paintParametric(canvas, size);
    }
  }

  void _paintMask(Canvas canvas, Size size, BrushTipMask mask) {
    final cell = size.shortestSide / _maskGrid;
    final texelsPerCell = math.max(1, mask.size ~/ _maskGrid);
    final paint = Paint();
    for (var row = 0; row < _maskGrid; row += 1) {
      for (var col = 0; col < _maskGrid; col += 1) {
        final startX = col * mask.size ~/ _maskGrid;
        final startY = row * mask.size ~/ _maskGrid;
        var total = 0;
        var count = 0;
        for (var dy = 0; dy < texelsPerCell; dy += 1) {
          final y = startY + dy;
          if (y >= mask.size) {
            break;
          }
          for (var dx = 0; dx < texelsPerCell; dx += 1) {
            final x = startX + dx;
            if (x >= mask.size) {
              break;
            }
            total += mask.alpha[y * mask.size + x];
            count += 1;
          }
        }
        if (count == 0 || total == 0) {
          continue;
        }
        final alpha = (total / count) / 255;
        paint.color = color.withValues(alpha: alpha);
        canvas.drawRect(
          Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
          paint,
        );
      }
    }
  }

  void _paintParametric(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.32;
    final roundness = settings.roundness.clamp(0.05, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // Negative because angleDegrees is visual-CCW in y-down coordinates.
    canvas.rotate(-settings.angleDegrees * math.pi / 180);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * 2,
      height: radius * 2 * roundness,
    );
    final soft = settings.hardness < 0.85;
    final corePaint = Paint()..color = color.withValues(alpha: soft ? 0.8 : 1);
    if (settings.tipShape == BrushTipShape.square) {
      if (soft) {
        canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.3));
        canvas.drawRect(rect.deflate(radius * 0.25), corePaint);
      } else {
        canvas.drawRect(rect, corePaint);
      }
    } else {
      if (soft) {
        canvas.drawOval(rect, Paint()..color = color.withValues(alpha: 0.3));
        canvas.drawOval(rect.deflate(radius * 0.25), corePaint);
      } else {
        canvas.drawOval(rect, corePaint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrushTipPreviewPainter oldDelegate) {
    return oldDelegate.settings != settings || oldDelegate.color != color;
  }
}
