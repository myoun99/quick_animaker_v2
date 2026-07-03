import 'package:flutter/material.dart';

import '../../models/bitmap_surface.dart';
import '../../models/brush_edit_session_state.dart';
import 'bitmap_surface_painter.dart';

class BrushEditCanvasView extends StatelessWidget {
  const BrushEditCanvasView({
    super.key,
    required this.sessionState,
    BitmapSurface? activeEditCompositeSurface,
    this.showTransparentBackground = true,
    this.activeStrokeTempSurface,
  }) : activeEditCompositeSurface =
           activeEditCompositeSurface ??
           sessionState.canvasState.currentSurface;

  final BrushEditSessionState sessionState;
  final bool showTransparentBackground;
  final BitmapSurface activeEditCompositeSurface;
  final BitmapSurface? activeStrokeTempSurface;

  @override
  Widget build(BuildContext context) {
    final surface = activeEditCompositeSurface;

    return RepaintBoundary(
      key: const ValueKey<String>('brush-edit-canvas-view-boundary'),
      child: SizedBox(
        width: surface.canvasSize.width.toDouble(),
        height: surface.canvasSize.height.toDouble(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              key: const ValueKey<String>('brush-edit-canvas-base-boundary'),
              child: CustomPaint(
                key: const ValueKey<String>(
                  'brush-edit-canvas-base-custom-paint',
                ),
                painter: BitmapSurfacePainter(
                  surface: surface,
                  showTransparentBackground: showTransparentBackground,
                ),
              ),
            ),
            if (activeStrokeTempSurface != null)
              RepaintBoundary(
                key: const ValueKey<String>('brush-edit-canvas-active-boundary'),
                child: CustomPaint(
                  key: const ValueKey<String>(
                    'brush-edit-canvas-active-custom-paint',
                  ),
                  painter: BitmapSurfacePainter(
                    surface: activeStrokeTempSurface!,
                    showTransparentBackground: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
