import 'package:flutter/material.dart';

class TimelineBlock extends StatelessWidget {
  const TimelineBlock({
    super.key,
    required this.width,
    required this.isActive,
    required this.child,
    this.onTap,
    this.minHeight = 64,
    this.padding = const EdgeInsets.all(6),
  });

  final double width;
  final bool isActive;
  final VoidCallback? onTap;
  final Widget child;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  static const double borderRadiusValue = 8;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(borderRadiusValue);

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
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isActive ? colorScheme.primary : colorScheme.outline,
              width: isActive ? 2 : 1,
            ),
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
