import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/camera_pose.dart';
import '../../models/canvas_point.dart';
import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';

/// The TVPaint-style camera view drawn over the canvas: everything outside
/// the camera frame is dimmed and the frame silhouette gets a blue outline.
///
/// When [interactive] (the camera layer is active) dragging anywhere moves
/// the camera; the moved pose is committed once on release via
/// [onPoseCommitted] (one undo entry per drag). When not interactive the
/// overlay ignores pointers so canvas panning/drawing still works below it.
class CameraFrameOverlay extends StatefulWidget {
  const CameraFrameOverlay({
    super.key,
    required this.pose,
    required this.cameraFrameSize,
    required this.viewport,
    required this.dimOpacity,
    this.interactive = false,
    this.onPoseCommitted,
  });

  static const Color outlineColor = Color(0xFF40C4FF);

  final CameraPose pose;

  /// The camera's output picture size; the view rect on canvas is this
  /// divided by the pose zoom.
  final CanvasSize cameraFrameSize;

  final CanvasViewport viewport;

  /// 0 = no dim, 1 = fully black outside the camera frame.
  final double dimOpacity;

  final bool interactive;
  final ValueChanged<CameraPose>? onPoseCommitted;

  @override
  State<CameraFrameOverlay> createState() => _CameraFrameOverlayState();
}

class _CameraFrameOverlayState extends State<CameraFrameOverlay> {
  CameraPose? _dragPose;

  CameraPose get _displayPose => _dragPose ?? widget.pose;

  void _dragUpdate(DragUpdateDetails details) {
    final pose = _displayPose;
    setState(() {
      _dragPose = pose.copyWith(
        center: CanvasPoint(
          x: pose.center.x + details.delta.dx / widget.viewport.zoom,
          y: pose.center.y + details.delta.dy / widget.viewport.zoom,
        ),
      );
    });
  }

  void _dragEnd() {
    final dragPose = _dragPose;
    setState(() => _dragPose = null);
    if (dragPose != null && dragPose != widget.pose) {
      widget.onPoseCommitted?.call(dragPose);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      key: const ValueKey<String>('camera-frame-overlay'),
      painter: CameraFramePainter(
        pose: _displayPose,
        cameraFrameSize: widget.cameraFrameSize,
        viewport: widget.viewport,
        dimOpacity: widget.dimOpacity,
        outlineColor: CameraFrameOverlay.outlineColor,
      ),
      // A bare CustomPaint sizes to zero under loose constraints; the overlay
      // must always cover (and hit-test across) the whole viewport.
      child: const SizedBox.expand(),
    );

    if (!widget.interactive) {
      return IgnorePointer(child: paint);
    }

    return GestureDetector(
      key: const ValueKey<String>('camera-frame-overlay-gesture'),
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _dragUpdate,
      onPanEnd: (_) => _dragEnd(),
      onPanCancel: _dragEnd,
      child: paint,
    );
  }
}

class CameraFramePainter extends CustomPainter {
  const CameraFramePainter({
    required this.pose,
    required this.cameraFrameSize,
    required this.viewport,
    required this.dimOpacity,
    required this.outlineColor,
  });

  final CameraPose pose;
  final CanvasSize cameraFrameSize;
  final CanvasViewport viewport;
  final double dimOpacity;
  final Color outlineColor;

  /// The camera frame's corners in viewport (screen) coordinates:
  /// top-left, top-right, bottom-right, bottom-left.
  List<Offset> frameCornersInViewport() {
    final halfWidth = cameraFrameSize.width / pose.zoom / 2;
    final halfHeight = cameraFrameSize.height / pose.zoom / 2;
    final radians = pose.rotationDegrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);

    Offset corner(double dx, double dy) {
      // Clockwise rotation in y-down screen space, then canvas → viewport.
      final x = pose.center.x + dx * cos - dy * sin;
      final y = pose.center.y + dx * sin + dy * cos;
      return Offset(
        x * viewport.zoom + viewport.panX,
        y * viewport.zoom + viewport.panY,
      );
    }

    return [
      corner(-halfWidth, -halfHeight),
      corner(halfWidth, -halfHeight),
      corner(halfWidth, halfHeight),
      corner(-halfWidth, halfHeight),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    // CustomPaint does not clip: the frame silhouette must never escape the
    // canvas viewport into neighboring panels.
    canvas.clipRect(Offset.zero & size);
    final corners = frameCornersInViewport();
    final framePath = Path()..addPolygon(corners, true);

    if (dimOpacity > 0) {
      final dimPath = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addPath(framePath, Offset.zero);
      canvas.drawPath(
        dimPath,
        Paint()..color = Colors.black.withValues(alpha: dimOpacity),
      );
    }

    canvas.drawPath(
      framePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = outlineColor,
    );

    // Small center cross so the pivot reads at a glance.
    final center = Offset(
      pose.center.x * viewport.zoom + viewport.panX,
      pose.center.y * viewport.zoom + viewport.panY,
    );
    final crossPaint = Paint()
      ..strokeWidth = 1
      ..color = outlineColor;
    canvas.drawLine(
      center - const Offset(6, 0),
      center + const Offset(6, 0),
      crossPaint,
    );
    canvas.drawLine(
      center - const Offset(0, 6),
      center + const Offset(0, 6),
      crossPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CameraFramePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.cameraFrameSize != cameraFrameSize ||
      oldDelegate.viewport != viewport ||
      oldDelegate.dimOpacity != dimOpacity ||
      oldDelegate.outlineColor != outlineColor;
}
