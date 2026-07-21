import 'package:flutter/widgets.dart';

import '../../models/canvas_size.dart';
import '../../models/canvas_viewport.dart';
import '../../models/pasteboard_bounds.dart';
import 'viewport_canvas_transform.dart';

/// The pasteboard scrim: ONE even-odd ring over everything outside the
/// canvas rect, drawn above the whole editing layer stack (below, active
/// and above layers alike) so off-stage artwork reads as parked, not part
/// of the shot — and the dim never stacks per layer.
class PasteboardDimOverlay extends StatelessWidget {
  const PasteboardDimOverlay({
    super.key,
    required this.canvasSize,
    required this.viewport,
  });

  /// Scrim color over pasteboard content outside the canvas rect.
  static const Color dimColor = Color(0x8C000000);

  final CanvasSize canvasSize;
  final CanvasViewport viewport;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PasteboardDimPainter(
          canvasSize: canvasSize,
          viewport: viewport,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PasteboardDimPainter extends CustomPainter {
  const _PasteboardDimPainter({
    required this.canvasSize,
    required this.viewport,
  });

  final CanvasSize canvasSize;
  final CanvasViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    applyViewportTransform(canvas, viewport);
    final dimPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(
        Rect.fromLTRB(
          canvasSize.pasteboardLeft.toDouble(),
          canvasSize.pasteboardTop.toDouble(),
          canvasSize.pasteboardRightExclusive.toDouble(),
          canvasSize.pasteboardBottomExclusive.toDouble(),
        ),
      )
      ..addRect(
        Rect.fromLTWH(
          0,
          0,
          canvasSize.width.toDouble(),
          canvasSize.height.toDouble(),
        ),
      );
    canvas.drawPath(
      dimPath,
      Paint()..color = PasteboardDimOverlay.dimColor,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PasteboardDimPainter oldDelegate) {
    return oldDelegate.canvasSize != canvasSize ||
        oldDelegate.viewport != viewport;
  }
}
