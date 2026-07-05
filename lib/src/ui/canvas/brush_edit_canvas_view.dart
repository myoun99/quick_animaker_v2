import 'package:flutter/material.dart';

import '../../models/brush_edit_session_state.dart';
import 'active_stroke_overlay_painter.dart';
import 'bitmap_surface_painter.dart';

class BrushEditCanvasView extends StatelessWidget {
  const BrushEditCanvasView({
    super.key,
    required this.sessionState,
    this.showTransparentBackground = true,
    this.overlayModel,
    this.staleScope,
  });

  final BrushEditSessionState sessionState;
  final bool showTransparentBackground;

  /// Live overlay state owned by the interactive view; pointer moves repaint
  /// the overlay layer through this model without rebuilding widgets.
  final ActiveStrokeOverlayModel? overlayModel;

  /// Surface lineage identity for the stale tile fallback; see
  /// [BitmapSurfacePainter.staleScope].
  final Object? staleScope;

  @override
  Widget build(BuildContext context) {
    final surface = sessionState.canvasState.currentSurface;

    return RepaintBoundary(
      key: const ValueKey<String>('brush-edit-canvas-view-boundary'),
      child: SizedBox(
        width: surface.canvasSize.width.toDouble(),
        height: surface.canvasSize.height.toDouble(),
        child: ClipRect(
          key: const ValueKey<String>('brush-edit-canvas-cut-size-clip'),
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
                    staleScope: staleScope,
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey<String>('brush-edit-canvas-bounds'),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blueGrey, width: 1.5),
                    ),
                  ),
                ),
              ),
              RepaintBoundary(
                key: const ValueKey<String>(
                  'brush-edit-canvas-active-boundary',
                ),
                child: CustomPaint(
                  key: const ValueKey<String>(
                    'brush-edit-canvas-active-custom-paint',
                  ),
                  painter: ActiveStrokeOverlayPainter(model: overlayModel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
