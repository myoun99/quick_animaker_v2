import 'package:flutter/material.dart';

/// The 6f/24f beat-line system (UI-R10 #26 → UI-R13 #7): a medium line
/// every 6 frames and a strong one on second boundaries, spanning the
/// WHOLE frame grid — every row and column (SE, camera, lanes, the
/// storyboard strip), not just the painterized drawing rows. One overlay
/// per grid replaces the old per-row painting.
///
/// The painter lives in the scroll CONTENT's coordinate space (its size
/// is the full built content), so lines land on absolute frame
/// boundaries; painting is a handful of `drawLine`s — no windowing
/// needed.
class TimelineBeatLinesPainter extends CustomPainter {
  TimelineBeatLinesPainter({
    required this.frameCellExtent,
    required this.framesPerSecond,
    required this.colorScheme,
    this.axis = Axis.horizontal,
  });

  final double frameCellExtent;
  final int framesPerSecond;
  final ColorScheme colorScheme;

  /// The FRAME axis' direction: horizontal (timeline, storyboard) draws
  /// vertical lines; vertical (X-sheet) draws horizontal ones.
  final Axis axis;

  @override
  void paint(Canvas canvas, Size size) {
    if (frameCellExtent <= 0) {
      return;
    }
    final sixPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;
    final secondPaint = Paint()
      ..color = colorScheme.onSurfaceVariant
      ..strokeWidth = 1.5;
    final mainExtent = axis == Axis.horizontal ? size.width : size.height;
    final crossExtent = axis == Axis.horizontal ? size.height : size.width;
    // 6f is the sheet convention regardless of fps.
    const beatPeriod = 6;
    for (
      var frame = beatPeriod;
      frame * frameCellExtent <= mainExtent;
      frame += beatPeriod
    ) {
      final position = frame * frameCellExtent;
      final paint = framesPerSecond > 0 && frame % framesPerSecond == 0
          ? secondPaint
          : sixPaint;
      if (axis == Axis.horizontal) {
        canvas.drawLine(
          Offset(position, 0),
          Offset(position, crossExtent),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(0, position),
          Offset(crossExtent, position),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant TimelineBeatLinesPainter oldDelegate) =>
      oldDelegate.frameCellExtent != frameCellExtent ||
      oldDelegate.framesPerSecond != framesPerSecond ||
      oldDelegate.colorScheme != colorScheme ||
      oldDelegate.axis != axis;
}
