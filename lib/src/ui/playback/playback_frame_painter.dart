import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../models/camera_pose.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';

/// Paints one cached composite frame inside the canvas panel viewport.
///
/// Canvas mode ([cameraPose] null) draws the paper and the composite in
/// canvas space under the interactive [viewport] transform — the exact
/// framing the editing canvas uses, so panel zoom/pan keep working during
/// playback. A null [image] paints just the paper (the blank-canvas
/// placeholder reuses this).
///
/// Camera mode looks through the pose instead: the camera's output frame
/// takes the canvas's place under the SAME viewport transform (zoom/pan keep
/// working here too), everything outside it letterboxed dark, and the
/// canvas-space composite is projected with the transform the export
/// renderer uses — no re-render, camera moves are pure GPU transforms over
/// the cached image.
class PlaybackFramePainter extends CustomPainter {
  const PlaybackFramePainter({
    required this.image,
    required this.canvasSize,
    this.viewport,
    this.cameraPose,
    this.cameraFrameSize,
    this.fadeOpacity = 1,
    this.fadeColor = const Color(0xFF000000),
    this.letterboxColor = const Color(0xFF15191C),
    this.paperColor = const Color(0xFFEDEDED),
  }) : assert(
         cameraPose == null || cameraFrameSize != null,
         'Camera mode needs the camera frame size.',
       );

  /// The composite at any cached quality; drawn stretched to canvas size.
  final ui.Image? image;

  final CanvasSize canvasSize;

  /// Pan/zoom of the panel viewport; identity when null.
  final CanvasViewport? viewport;

  /// Non-null = look through the camera.
  final CameraPose? cameraPose;
  final CanvasSize? cameraFrameSize;

  /// The cut fade (Cut.fadeOpacityAt): paper and composite fade together
  /// toward [fadeColor]. 1 costs nothing.
  final double fadeOpacity;

  /// What the fade fades TO (cutFadeTargetColor: FO=black, WO=white) — an
  /// overlay at (1 − [fadeOpacity]) over the canvas rect, matching the MP4
  /// bake exactly.
  final Color fadeColor;

  final Color letterboxColor;
  final Color paperColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final pose = cameraPose;

    canvas.save();
    // CustomPaint does not clip: a zoomed/panned frame must never escape the
    // canvas viewport into neighboring panels.
    canvas.clipRect(Offset.zero & size);

    if (pose != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = letterboxColor);
    }
    final resolvedViewport = viewport;
    if (resolvedViewport != null) {
      canvas.translate(resolvedViewport.panX, resolvedViewport.panY);
      canvas.scale(resolvedViewport.zoom, resolvedViewport.zoom);
    }
    Rect? frameRect;
    if (pose != null) {
      // The camera's output frame takes the canvas's place in viewport
      // space; the projection inside it matches
      // CameraFrameRenderService.renderThroughCamera.
      final frameSize = cameraFrameSize!;
      frameRect = Rect.fromLTWH(
        0,
        0,
        frameSize.width.toDouble(),
        frameSize.height.toDouble(),
      );
      canvas.clipRect(frameRect);
      canvas.save();
      canvas.translate(frameSize.width / 2, frameSize.height / 2);
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
    if (pose != null) {
      canvas.restore();
    }
    if (fadeOpacity < 1) {
      // The picture fades TO the target color (FO=black / WO=white): a
      // plain overlay at (1 − fade) — cheaper than the old saveLayer and
      // it matches the MP4 bake pixel-for-pixel. Camera mode fades the
      // whole output frame (like the bake); canvas mode fades the paper.
      canvas.drawRect(
        frameRect ?? canvasRect,
        Paint()
          ..color = fadeColor.withValues(
            alpha: (1 - fadeOpacity).clamp(0.0, 1.0),
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PlaybackFramePainter oldDelegate) =>
      !identical(oldDelegate.image, image) ||
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.viewport != viewport ||
      oldDelegate.cameraPose != cameraPose ||
      oldDelegate.cameraFrameSize != cameraFrameSize ||
      oldDelegate.fadeOpacity != fadeOpacity ||
      oldDelegate.fadeColor != fadeColor ||
      oldDelegate.letterboxColor != letterboxColor ||
      oldDelegate.paperColor != paperColor;
}
