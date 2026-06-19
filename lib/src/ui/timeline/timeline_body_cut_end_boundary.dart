import 'package:flutter/material.dart';

class TimelineBodyCutEndBoundary extends StatelessWidget {
  const TimelineBodyCutEndBoundary({
    super.key = const ValueKey<String>('timeline-cut-end-boundary'),
    required this.left,
  });

  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: 2,
      child: const IgnorePointer(
        child: DecoratedBox(decoration: BoxDecoration(color: Colors.red)),
      ),
    );
  }
}
