import 'package:flutter/material.dart';

import 'timeline_cell_style.dart';

class TimelineBlock extends StatelessWidget {
  const TimelineBlock({
    super.key,
    required this.width,
    required this.isActive,
    required this.child,
    this.onTap,
    this.isRangeSelected = false,
    this.minHeight = 64,
    this.padding = const EdgeInsets.all(6),
  });

  final double width;
  final bool isActive;

  /// Inside a live range selection: an accent tint blends over the
  /// background — COLOR ONLY, the border stays as-is (the selection
  /// language, UI-R18 #5).
  final bool isRangeSelected;
  final VoidCallback? onTap;
  final Widget child;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  static const double borderRadiusValue = 8;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(borderRadiusValue);
    final baseColor = isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        mouseCursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onTap: onTap,
        child: Container(
          width: width,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: timelineBlockDecoration(
            backgroundColor: isRangeSelected
                ? Color.alphaBlend(
                    timelineSelectedFrameBorderColor.withValues(alpha: 0.28),
                    baseColor,
                  )
                : baseColor,
            // Blocks sit on dark track lanes: a brighter inactive edge
            // keeps cut boundaries readable.
            borderColor: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            borderWidth: isActive ? 2 : 1,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}

BoxDecoration timelineBlockDecoration({
  required Color backgroundColor,
  required Color borderColor,
  required double borderWidth,
  BorderRadiusGeometry? borderRadius,
}) {
  return BoxDecoration(
    color: backgroundColor,
    border: Border.all(color: borderColor, width: borderWidth),
    borderRadius: borderRadius,
  );
}
