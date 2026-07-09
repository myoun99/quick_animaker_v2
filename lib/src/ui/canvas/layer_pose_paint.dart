import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/transform_track.dart';

/// A layer's resolved GEOMETRIC transform at one frame: the shared pose
/// (position/scale/rotation) plus the optional anchor point (null = the
/// canvas center, the historical default). Animated opacity rides
/// separately — it multiplies paint alpha, not geometry.
typedef LayerPoseSample = ({TransformPose pose, CanvasPoint? anchorPoint});

/// The matrix [applyLayerPoseTransform] applies — artwork space → posed
/// canvas space: the artwork's ANCHOR POINT (canvas center unless the
/// anchor-point lane keys one) lands on `pose.center`, scaled by
/// `pose.zoom` and rotated clockwise by `pose.rotationDegrees` about that
/// point. The identity pose maps to the identity matrix by construction.
/// [rasterScale] adapts the same canvas-space pose to a scaled raster
/// (playback quality tiers).
Matrix4 layerPoseMatrix(
  TransformPose pose,
  CanvasSize canvasSize, {
  CanvasPoint? anchorPoint,
  double rasterScale = 1,
}) {
  final anchorX = (anchorPoint?.x ?? canvasSize.width / 2) * rasterScale;
  final anchorY = (anchorPoint?.y ?? canvasSize.height / 2) * rasterScale;
  return Matrix4.translationValues(
      pose.center.x * rasterScale,
      pose.center.y * rasterScale,
      0,
    ).multiplied(Matrix4.rotationZ(pose.rotationDegrees * math.pi / 180))
    ..multiply(Matrix4.diagonal3Values(pose.zoom, pose.zoom, 1))
    ..multiply(Matrix4.translationValues(-anchorX, -anchorY, 0));
}

/// Applies a layer's transform pose to [canvas] before its image draws at
/// the origin — see [layerPoseMatrix] for the mapping.
///
/// EVERY composite route shares this one function — playback composites,
/// camera renders (export/thumbnails) and the editing canvas's layer
/// stack — so a transformed layer looks byte-identical everywhere
/// (three-route parity discipline).
void applyLayerPoseTransform(
  Canvas canvas,
  TransformPose pose,
  CanvasSize canvasSize, {
  CanvasPoint? anchorPoint,
  double rasterScale = 1,
}) {
  canvas.transform(
    layerPoseMatrix(
      pose,
      canvasSize,
      anchorPoint: anchorPoint,
      rasterScale: rasterScale,
    ).storage,
  );
}

/// The SCREEN-space wrap matrix for a widget that already renders artwork
/// under [viewport]: `V · P · V⁻¹` — wrapping the interactive brush view in
/// `Transform(transform: ...)` with this matrix shows the active layer
/// POSED exactly like every composite route, while Flutter's hit testing
/// routes pointers through the inverse, so strokes record in original
/// artwork coordinates (draw-through: drawing on what you see lands where
/// the composite shows it).
Matrix4 layerPoseViewportWrapMatrix(
  TransformPose pose,
  CanvasSize canvasSize,
  CanvasViewport viewport, {
  CanvasPoint? anchorPoint,
}) {
  final view = Matrix4.translationValues(viewport.panX, viewport.panY, 0)
    ..multiply(Matrix4.diagonal3Values(viewport.zoom, viewport.zoom, 1));
  final viewInverse = Matrix4.diagonal3Values(
    1 / viewport.zoom,
    1 / viewport.zoom,
    1,
  )..multiply(Matrix4.translationValues(-viewport.panX, -viewport.panY, 0));
  return view.multiplied(
    layerPoseMatrix(pose, canvasSize, anchorPoint: anchorPoint),
  )..multiply(viewInverse);
}
