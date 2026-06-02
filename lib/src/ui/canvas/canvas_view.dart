import 'package:flutter/material.dart';

import '../../controllers/canvas_controller.dart';
import 'stroke_painter.dart';

class CanvasView extends StatefulWidget {
  const CanvasView({super.key, required this.controller});

  final CanvasController controller;

  @override
  State<CanvasView> createState() => _CanvasViewState();
}

class _CanvasViewState extends State<CanvasView> {
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        setState(() {
          widget.controller.beginStroke(event.localPosition);
        });
      },
      onPointerMove: (event) {
        setState(() {
          widget.controller.updateStroke(event.localPosition);
        });
      },
      onPointerUp: (_) {
        setState(widget.controller.endStroke);
      },
      onPointerCancel: (_) {
        setState(widget.controller.cancelStroke);
      },
      child: CustomPaint(
        painter: StrokePainter(
          strokes: widget.controller.strokes,
          activePoints: widget.controller.activePoints,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
