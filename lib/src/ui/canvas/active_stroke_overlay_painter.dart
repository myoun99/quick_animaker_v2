import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import 'bitmap_surface_painter.dart';

/// Deprecated compatibility wrapper. Active brush display now uses a raster
/// bitmap temp surface, never smooth path/vector painting.
class ActiveStrokeOverlayPainter extends CustomPainter {
  ActiveStrokeOverlayPainter({
    this.activeStrokeTempSurface,
    this.activeStrokePath,
    this.activeStrokePathDab,
    this.activeStrokePathVersion = 0,
    this.activeStrokeOverlay = const <Object>[],
  });

  final BitmapSurface? activeStrokeTempSurface;
  final Object activeStrokeOverlay;
  final Path? activeStrokePath;
  final Object? activeStrokePathDab;
  final int activeStrokePathVersion;

  @override
  void paint(Canvas canvas, Size size) {
    final surface = activeStrokeTempSurface;
    if (surface == null) return;
    BitmapSurfacePainter(
      surface: surface,
      showTransparentBackground: false,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant ActiveStrokeOverlayPainter oldDelegate) {
    return oldDelegate.activeStrokeTempSurface != activeStrokeTempSurface ||
        oldDelegate.activeStrokePathVersion != activeStrokePathVersion;
  }
}
