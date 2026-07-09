import 'package:flutter/material.dart';

import '../../models/canvas_point.dart';
import '../../models/canvas_viewport.dart';
import '../../models/transform_track.dart';
import '../theme/app_theme.dart';

/// The on-canvas Position drag gizmo: a crosshair handle at the active
/// layer's posed center. Dragging it moves the layer's Position — the
/// handle ghosts along during the drag and the release commits ONE key at
/// the playhead (AE semantics, one undo). Shown only while the layer's
/// Transform lanes are twirled open, so the handle never sits in the way
/// of ordinary drawing.
class LayerPositionGizmo extends StatefulWidget {
  const LayerPositionGizmo({
    super.key,
    required this.pose,
    required this.viewport,
    required this.onPositionCommitted,
  });

  /// The layer's resolved pose at the playhead (identity pose while the
  /// track is empty — dragging then creates the first Position key).
  final TransformPose pose;

  final CanvasViewport viewport;

  /// The dragged Position in canvas coordinates, fired once on release.
  final ValueChanged<CanvasPoint> onPositionCommitted;

  @override
  State<LayerPositionGizmo> createState() => _LayerPositionGizmoState();
}

class _LayerPositionGizmoState extends State<LayerPositionGizmo> {
  Offset _dragDelta = Offset.zero;
  bool _dragging = false;

  static const double _handleSize = 22;

  Offset get _screenCenter => Offset(
    widget.viewport.panX + widget.viewport.zoom * widget.pose.center.x,
    widget.viewport.panY + widget.viewport.zoom * widget.pose.center.y,
  );

  void _endDrag() {
    final canvasDelta = _dragDelta / widget.viewport.zoom;
    final committed = CanvasPoint(
      x: widget.pose.center.x + canvasDelta.dx,
      y: widget.pose.center.y + canvasDelta.dy,
    );
    setState(() {
      _dragging = false;
      _dragDelta = Offset.zero;
    });
    if (canvasDelta != Offset.zero) {
      widget.onPositionCommitted(committed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _screenCenter + _dragDelta;
    return Stack(
      children: [
        Positioned(
          left: center.dx - _handleSize / 2,
          top: center.dy - _handleSize / 2,
          width: _handleSize,
          height: _handleSize,
          child: GestureDetector(
            key: const ValueKey<String>('layer-position-gizmo'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (details) =>
                setState(() => _dragDelta += details.delta),
            onPanEnd: (_) => _endDrag(),
            onPanCancel: () => setState(() {
              _dragging = false;
              _dragDelta = Offset.zero;
            }),
            child: MouseRegion(
              cursor: SystemMouseCursors.move,
              child: CustomPaint(
                painter: _GizmoHandlePainter(
                  color: AppColors.accent,
                  active: _dragging,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GizmoHandlePainter extends CustomPainter {
  const _GizmoHandlePainter({required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2 : 1.5
      ..color = color;
    canvas.drawCircle(center, size.width / 2 - 2, stroke);
    // Crosshair ticks (AE-style move handle).
    for (final direction in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      canvas.drawLine(
        center + direction * (size.width / 2 - 6),
        center + direction * (size.width / 2 - 1),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GizmoHandlePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}
