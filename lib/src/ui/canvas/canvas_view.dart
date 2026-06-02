import 'package:flutter/material.dart';

import '../../controllers/canvas_controller.dart';
import '../../models/cut_id.dart';
import 'stroke_painter.dart';

class CanvasView extends StatefulWidget {
  const CanvasView({
    super.key,
    required this.controller,
    this.cutId,
    this.onChanged,
  });

  final CanvasController controller;
  final CutId? cutId;
  final VoidCallback? onChanged;

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
        widget.onChanged?.call();
      },
      onPointerCancel: (_) {
        setState(widget.controller.cancelStroke);
        widget.onChanged?.call();
      },
      child: CustomPaint(
        painter: StrokePainter(
          strokes: widget.controller.strokes,
          paintableLayers: _paintableLayers(),
          activePoints: widget.controller.activePoints,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  List<PaintableLayer> _paintableLayers() {
    final cutId = widget.cutId;
    if (cutId == null) {
      return const <PaintableLayer>[];
    }

    return widget.controller
        .layerFramesForCut(cutId)
        .map((layerFrame) {
          return PaintableLayer(
            layer: layerFrame.layer,
            frame: layerFrame.frame,
          );
        })
        .toList(growable: false);
  }
}
