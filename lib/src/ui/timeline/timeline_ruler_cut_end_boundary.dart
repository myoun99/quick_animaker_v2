import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TimelineRulerCutEndBoundary extends StatelessWidget {
  const TimelineRulerCutEndBoundary({
    super.key = const ValueKey<String>('timeline-cut-end-boundary-ruler'),
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
        child: DecoratedBox(decoration: BoxDecoration(color: AppColors.danger)),
      ),
    );
  }
}
