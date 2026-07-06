import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../models/camera_pose.dart';
import '../../models/canvas_size.dart';

/// Paints one cached composite frame like a program monitor: the content
/// rect (canvas, or camera output frame) is fit-scaled and centered in the
/// view over a dark letterbox.
///
/// Canvas mode paints the paper and the composite 1:1 in canvas space.
/// Camera mode looks through the pose instead: the camera's output frame
/// fills the fitted rect and the canvas-space composite is projected with
/// the same transform the export renderer uses — no re-render, camera moves
/// are pure GPU transforms over the cached image.
class PlaybackFramePainter extends CustomPainter {
  const PlaybackFramePainter({
    required this.image,
    required this.canvasSize,
    this.cameraPose,
    this.cameraFrameSize,
    this.letterboxColor = const Color(0xFF15191C),
    this.paperColor = const Color(0xFFEDEDED),
  }) : assert(
         cameraPose == null || cameraFrameSize != null,
         'Camera mode needs the camera frame size.',
       );

  /// The composite at any cached quality; drawn stretched to canvas size.
  final ui.Image? image;

  final CanvasSize canvasSize;

  /// Non-null = look through the camera.
  final CameraPose? cameraPose;
  final CanvasSize? cameraFrameSize;

  final Color letterboxColor;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = letterboxColor);
    if (size.isEmpty) {
      return;
    }

    final pose = cameraPose;
    final contentSize = pose == null ? canvasSize : cameraFrameSize!;
    final fitScale = math.min(
      size.width / contentSize.width,
      size.height / contentSize.height,
    );

    canvas.save();
    canvas.translate(
      (size.width - contentSize.width * fitScale) / 2,
      (size.height - contentSize.height * fitScale) / 2,
    );
    canvas.scale(fitScale);
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        contentSize.width.toDouble(),
        contentSize.height.toDouble(),
      ),
    );

    if (pose != null) {
      // Same projection as CameraFrameRenderService.renderThroughCamera.
      canvas.translate(contentSize.width / 2, contentSize.height / 2);
      canvas.scale(pose.zoom);
      canvas.rotate(-pose.rotationDegrees * math.pi / 180);
      canvas.translate(-pose.center.x, -pose.center.y);
    }

    final canvasRect = Rect.fromLTWH(
      0,
      0,
      canvasSize.width.toDouble(),
      canvasSize.height.toDouble(),
    );
    canvas.drawRect(canvasRect, Paint()..color = paperColor);
    final composite = image;
    if (composite != null) {
      canvas.drawImageRect(
        composite,
        Rect.fromLTWH(
          0,
          0,
          composite.width.toDouble(),
          composite.height.toDouble(),
        ),
        // The dst upscale is what shows Half/Quarter caches at canvas size.
        canvasRect,
        Paint()..filterQuality = FilterQuality.low,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlaybackFramePainter oldDelegate) =>
      !identical(oldDelegate.image, image) ||
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.cameraPose != cameraPose ||
      oldDelegate.cameraFrameSize != cameraFrameSize ||
      oldDelegate.letterboxColor != letterboxColor ||
      oldDelegate.paperColor != paperColor;
}
