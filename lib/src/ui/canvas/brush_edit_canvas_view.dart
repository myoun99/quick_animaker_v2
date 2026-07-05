import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/brush_dab.dart';
import '../../models/brush_edit_session_state.dart';
import 'active_stroke_overlay_painter.dart';
import 'bitmap_surface_painter.dart';

class BrushEditCanvasView extends StatelessWidget {
  const BrushEditCanvasView({
    super.key,
    required this.sessionState,
    this.showTransparentBackground = true,
    this.activeStrokeOverlay = const <BrushDab>[],
    this.activeOverlayFlattened,
    this.activeOverlayPaintFrom = 0,
    this.activeOverlayRevision = 0,
  });

  final BrushEditSessionState sessionState;
  final bool showTransparentBackground;
  final List<BrushDab> activeStrokeOverlay;

  /// Older overlay stamps pre-rendered by the interactive view; see
  /// [ActiveStrokeOverlayPainter.flattenedOverlay].
  final ui.Image? activeOverlayFlattened;
  final int activeOverlayPaintFrom;
  final int activeOverlayRevision;

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
                  painter: ActiveStrokeOverlayPainter(
                    activeStrokeOverlay: activeStrokeOverlay,
                    flattenedOverlay: activeOverlayFlattened,
                    paintFrom: activeOverlayPaintFrom,
                    overlayRevision: activeOverlayRevision,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
