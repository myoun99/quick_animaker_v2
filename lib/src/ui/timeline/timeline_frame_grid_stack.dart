import 'package:flutter/material.dart';

import 'timeline_body_cut_end_boundary.dart';

class TimelineFrameGridStack extends StatelessWidget {
  const TimelineFrameGridStack({
    super.key,
    required this.rowsBody,
    required this.cutEndBoundaryLeft,
    required this.showPlayhead,
    required this.playheadWidth,
    required this.playhead,
  });

  final Widget rowsBody;
  final double cutEndBoundaryLeft;
  final bool showPlayhead;
  final double playheadWidth;
  final Widget playhead;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        rowsBody,
        TimelineBodyCutEndBoundary(left: cutEndBoundaryLeft),
        if (showPlayhead)
          Positioned(left: 0, top: 0, width: playheadWidth, child: playhead),
      ],
    );
  }
}
