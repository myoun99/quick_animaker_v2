import 'package:flutter/material.dart';

class TimelineLayerFrameBodyLayout extends StatelessWidget {
  const TimelineLayerFrameBodyLayout({
    super.key,
    required this.layerControlsRail,
    required this.verticalScrollbarSlot,
    required this.frameGridArea,
  });

  final Widget layerControlsRail;
  final Widget verticalScrollbarSlot;
  final Widget frameGridArea;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        layerControlsRail,
        verticalScrollbarSlot,
        frameGridArea,
      ],
    );
  }
}
