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
    this.beatLines,
  });

  final Widget rowsBody;
  final double cutEndBoundaryLeft;
  final bool showPlayhead;
  final double playheadWidth;
  final Widget playhead;

  /// The 6f/24f beat-line overlay (UI-R13 #7): spans EVERY row — SE,
  /// camera, lanes — over the cells, under the cursor layer.
  final Widget? beatLines;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        rowsBody,
        if (beatLines != null)
          Positioned.fill(child: IgnorePointer(child: beatLines)),
        TimelineBodyCutEndBoundary(left: cutEndBoundaryLeft),
        if (showPlayhead)
          Positioned(left: 0, top: 0, width: playheadWidth, child: playhead),
      ],
    );
  }
}
