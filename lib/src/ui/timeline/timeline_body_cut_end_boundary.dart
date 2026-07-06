import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TimelineBodyCutEndBoundary extends StatelessWidget {
  const TimelineBodyCutEndBoundary({
    super.key = const ValueKey<String>('timeline-cut-end-boundary'),
    required this.left,
    this.axis = Axis.horizontal,
  });

  /// Main-axis offset of the boundary line (x when horizontal, y when
  /// vertical) — the shared `timelineCutEndBoundaryX` result.
  final double left;

  /// The frame axis direction: a vertical line in the horizontal timeline,
  /// a horizontal line in the X-sheet.
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    const line = IgnorePointer(
      child: DecoratedBox(decoration: BoxDecoration(color: AppColors.danger)),
    );
    if (axis == Axis.vertical) {
      return Positioned(top: left, left: 0, right: 0, height: 2, child: line);
    }
    return Positioned(left: left, top: 0, bottom: 0, width: 2, child: line);
  }
}
