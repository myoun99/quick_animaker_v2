import 'package:flutter/widgets.dart';

import '../../models/canvas_viewport.dart';

/// The ONE way painters take canvas-space geometry to the screen (P8):
/// translate · scale · rotate · flip — the exact matrix
/// [CanvasViewport.canvasToViewport] speaks, so painted pixels and pointer
/// math can never disagree. Painters call this instead of hand-rolling
/// translate/scale pairs; a viewport feature added here reaches every
/// painter at once.
void applyViewportTransform(Canvas canvas, CanvasViewport viewport) {
  canvas.translate(viewport.panX, viewport.panY);
  canvas.scale(viewport.zoom, viewport.zoom);
  if (viewport.rotationDegrees != 0) {
    canvas.rotate(viewport.rotationRadians);
  }
  if (viewport.flipHorizontal || viewport.flipVertical) {
    canvas.scale(
      viewport.flipHorizontal ? -1 : 1,
      viewport.flipVertical ? -1 : 1,
    );
  }
}

/// [applyViewportTransform] as a matrix — for Transform widgets and the
/// layer-pose viewport wrap.
Matrix4 viewportTransformMatrix(CanvasViewport viewport) {
  final matrix = Matrix4.translationValues(viewport.panX, viewport.panY, 0)
    ..multiply(Matrix4.diagonal3Values(viewport.zoom, viewport.zoom, 1));
  if (viewport.rotationDegrees != 0) {
    matrix.multiply(Matrix4.rotationZ(viewport.rotationRadians));
  }
  if (viewport.flipHorizontal || viewport.flipVertical) {
    matrix.multiply(
      Matrix4.diagonal3Values(
        viewport.flipHorizontal ? -1 : 1,
        viewport.flipVertical ? -1 : 1,
        1,
      ),
    );
  }
  return matrix;
}

/// The exact inverse of [viewportTransformMatrix], built analytically
/// (flip⁻¹ · rotate⁻¹ · scale⁻¹ · translate⁻¹) instead of a numeric
/// inversion.
Matrix4 viewportInverseTransformMatrix(CanvasViewport viewport) {
  final matrix = Matrix4.identity();
  if (viewport.flipHorizontal || viewport.flipVertical) {
    matrix.multiply(
      Matrix4.diagonal3Values(
        viewport.flipHorizontal ? -1 : 1,
        viewport.flipVertical ? -1 : 1,
        1,
      ),
    );
  }
  if (viewport.rotationDegrees != 0) {
    matrix.multiply(Matrix4.rotationZ(-viewport.rotationRadians));
  }
  matrix
    ..multiply(Matrix4.diagonal3Values(1 / viewport.zoom, 1 / viewport.zoom, 1))
    ..multiply(Matrix4.translationValues(-viewport.panX, -viewport.panY, 0));
  return matrix;
}
