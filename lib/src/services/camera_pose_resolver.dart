import '../models/camera_pose.dart';
import '../models/canvas_point.dart';
import '../models/canvas_size.dart';
import '../models/cut_camera.dart';

/// The camera pose used when a cut has no keyframes: centered on the canvas,
/// zoom 1, no rotation.
CameraPose defaultCameraPoseFor(CanvasSize canvasSize) {
  return CameraPose(
    center: CanvasPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
  );
}

/// Resolves the camera pose at [frameIndex].
///
/// Semantics follow the usual keyframe rules: exact keyframes win; frames
/// before the first keyframe hold the first pose and frames after the last
/// hold the last; frames between two keyframes interpolate linearly (center,
/// zoom and rotation each lerped component-wise). An empty [CutCamera] yields
/// [defaultCameraPoseFor].
CameraPose resolveCameraPoseAt({
  required CutCamera camera,
  required CanvasSize canvasSize,
  required int frameIndex,
}) {
  if (camera.isEmpty) {
    return defaultCameraPoseFor(canvasSize);
  }

  final keyframes = camera.keyframes;
  final exact = keyframes[frameIndex];
  if (exact != null) {
    return exact;
  }

  final previousIndex = keyframes.lastKeyBefore(frameIndex);
  final nextIndex = keyframes.firstKeyAfter(frameIndex);
  if (previousIndex == null) {
    return keyframes[nextIndex!]!;
  }
  if (nextIndex == null) {
    return keyframes[previousIndex]!;
  }

  final previous = keyframes[previousIndex]!;
  final next = keyframes[nextIndex]!;
  final t = (frameIndex - previousIndex) / (nextIndex - previousIndex);
  return CameraPose(
    center: CanvasPoint(
      x: _lerp(previous.center.x, next.center.x, t),
      y: _lerp(previous.center.y, next.center.y, t),
    ),
    zoom: _lerp(previous.zoom, next.zoom, t),
    rotationDegrees: _lerp(previous.rotationDegrees, next.rotationDegrees, t),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
