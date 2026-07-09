import 'dart:math' as math;
import 'dart:ui';

import '../../models/canvas_size.dart';
import '../../models/transform_track.dart';

/// Applies a layer's transform pose to [canvas] before its image draws at
/// the origin: the artwork's CENTER lands on `pose.center`, scaled by
/// `pose.zoom` and rotated clockwise by `pose.rotationDegrees` about that
/// point (the anchor is the canvas center until the anchor-point lane
/// joins). The identity pose (canvas-centered, zoom 1, no rotation) is a
/// no-op by construction.
///
/// EVERY composite route shares this one function — playback composites,
/// camera renders (export/thumbnails) and the editing canvas's layer
/// stack — so a transformed layer looks byte-identical everywhere
/// (three-route parity discipline). [rasterScale] adapts the same
/// canvas-space pose to a scaled raster (playback quality tiers).
void applyLayerPoseTransform(
  Canvas canvas,
  TransformPose pose,
  CanvasSize canvasSize, {
  double rasterScale = 1,
}) {
  canvas.translate(pose.center.x * rasterScale, pose.center.y * rasterScale);
  canvas.rotate(pose.rotationDegrees * math.pi / 180);
  canvas.scale(pose.zoom);
  canvas.translate(
    -canvasSize.width * rasterScale / 2,
    -canvasSize.height * rasterScale / 2,
  );
}
