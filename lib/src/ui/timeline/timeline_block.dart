import 'package:flutter/material.dart';

import 'timeline_cell_style.dart';

/// R26 #8: the resting edge color for a block sitting on [brightness]
/// lanes — the single place both states are defined. Dark lanes get a
/// LIGHT edge, light lanes a DARK one; the old one-color grey vanished
/// against the near-black track background.
Color timelineBlockRestingEdgeColor(
  ColorScheme colorScheme,
  Brightness brightness,
) => brightness == Brightness.dark
    ? colorScheme.onSurface.withValues(alpha: 0.60)
    : colorScheme.onSurface.withValues(alpha: 0.45);

/// The hovered edge (R26 #8): the resting color pushed toward full ink,
/// so a pointer resting on a block reads before any click.
Color timelineBlockHoverEdgeColor(ColorScheme colorScheme) =>
    colorScheme.onSurface.withValues(alpha: 0.95);

class TimelineBlock extends StatefulWidget {
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
  State<TimelineBlock> createState() => _TimelineBlockState();
}

class _TimelineBlockState extends State<TimelineBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(
      TimelineBlock.borderRadiusValue,
    );
    final baseColor = widget.isActive
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;

    // R26 #8: the ACTIVE accent edge stays exactly as it was; the resting
    // edge follows the background's brightness and a hover brightens it.
    final borderColor = widget.isActive
        ? colorScheme.primary
        : _hovered
        ? timelineBlockHoverEdgeColor(colorScheme)
        : timelineBlockRestingEdgeColor(colorScheme, theme.brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        mouseCursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onTap: widget.onTap,
        onHover: (hovered) => setState(() => _hovered = hovered),
        child: Container(
          width: widget.width,
          constraints: BoxConstraints(minHeight: widget.minHeight),
          padding: widget.padding,
          decoration: timelineBlockDecoration(
            backgroundColor: widget.isRangeSelected
                ? Color.alphaBlend(
                    timelineSelectedFrameBorderColor.withValues(alpha: 0.28),
                    baseColor,
                  )
                : baseColor,
            borderColor: borderColor,
            borderWidth: widget.isActive ? 2 : 1,
            borderRadius: borderRadius,
          ),
          child: widget.child,
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
