import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import 'bitmap_surface_painter.dart';

class BrushEditCanvasView extends StatelessWidget {
  const BrushEditCanvasView({
    super.key,
    required this.sessionState,
    this.showTransparentBackground = true,
    this.committedSourceDabs = const <BrushDab>[],
    this.activeStrokeOverlay = const <BrushDab>[],
  });

  final BrushEditSessionState sessionState;
  final bool showTransparentBackground;
  final List<BrushDab> committedSourceDabs;
  final List<BrushDab> activeStrokeOverlay;

  @override
  Widget build(BuildContext context) {
    final surface = sessionState.canvasState.currentSurface;

    return RepaintBoundary(
      key: const ValueKey<String>('brush-edit-canvas-view-boundary'),
      child: SizedBox(
        width: surface.canvasSize.width.toDouble(),
        height: surface.canvasSize.height.toDouble(),
        child: CustomPaint(
          key: const ValueKey<String>('brush-edit-canvas-view-custom-paint'),
          painter: BitmapSurfacePainter(
            surface: surface,
            showTransparentBackground: showTransparentBackground,
            committedSourceDabs: committedSourceDabs,
            activeStrokeOverlay: activeStrokeOverlay,
          ),
        ),
      ),
    );
  }
}
