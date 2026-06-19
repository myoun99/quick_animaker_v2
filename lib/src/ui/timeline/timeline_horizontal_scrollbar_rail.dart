import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimelineHorizontalScrollbarRail extends StatelessWidget {
  const TimelineHorizontalScrollbarRail({
    super.key,
    required this.controller,
    required this.viewportWidth,
    required this.contentWidth,
    required this.height,
  });

  static const double _minimumThumbWidth = 32;

  final ScrollController controller;
  final double viewportWidth;
  final double contentWidth;
  final double height;

  double get _maxScrollExtent {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.position.maxScrollExtent;
    }
    return math.max(0, contentWidth - viewportWidth);
  }

  double get _scrollOffset {
    if (!controller.hasClients) {
      return 0;
    }
    return controller.offset.clamp(0.0, _maxScrollExtent).toDouble();
  }

  double get _thumbWidth {
    if (viewportWidth <= 0 || contentWidth <= 0) {
      return 0;
    }
    if (contentWidth <= viewportWidth) {
      return viewportWidth;
    }
    return (viewportWidth * viewportWidth / contentWidth)
        .clamp(_minimumThumbWidth, viewportWidth)
        .toDouble();
  }

  double get _thumbLeft {
    final maxThumbLeft = math.max(0.0, viewportWidth - _thumbWidth);
    final maxScrollExtent = _maxScrollExtent;
    if (maxScrollExtent <= 0 || maxThumbLeft <= 0) {
      return 0;
    }
    return (_scrollOffset / maxScrollExtent * maxThumbLeft)
        .clamp(0.0, maxThumbLeft)
        .toDouble();
  }

  void _jumpToThumbLeft(double thumbLeft) {
    if (!controller.hasClients) {
      return;
    }
    final maxThumbLeft = math.max(0.0, viewportWidth - _thumbWidth);
    final maxScrollExtent = _maxScrollExtent;
    if (maxThumbLeft <= 0 || maxScrollExtent <= 0) {
      controller.jumpTo(0);
      return;
    }
    final offset =
        (thumbLeft.clamp(0.0, maxThumbLeft) / maxThumbLeft) * maxScrollExtent;
    controller.jumpTo(offset.clamp(0.0, maxScrollExtent).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey<String>('timeline-bottom-scrollbar-rail'),
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final thumbWidth = _thumbWidth;
          final thumbLeft = _thumbLeft;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: (height - math.max(4, height / 3)) / 2,
                height: math.max(4, height / 3),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _jumpToThumbLeft(details.localPosition.dx - thumbWidth / 2);
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-horizontal-scrollbar-track',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(height),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: thumbLeft,
                top: 2,
                bottom: 2,
                width: thumbWidth,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    _jumpToThumbLeft(_thumbLeft + (details.primaryDelta ?? 0));
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-horizontal-scrollbar-thumb',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(height),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
