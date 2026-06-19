import 'dart:math' as math;

import 'package:flutter/material.dart';

class TimelineVerticalScrollbarSlot extends StatelessWidget {
  const TimelineVerticalScrollbarSlot({
    super.key = const ValueKey<String>('timeline-vertical-scrollbar-slot'),
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}

class TimelineVerticalScrollbarRail extends StatelessWidget {
  const TimelineVerticalScrollbarRail({
    super.key = const ValueKey<String>('timeline-vertical-scrollbar'),
    required this.controller,
    required this.viewportHeight,
    required this.contentHeight,
    required this.width,
  });

  static const double _minimumThumbHeight = 32;

  final ScrollController controller;
  final double viewportHeight;
  final double contentHeight;
  final double width;

  double get _maxScrollExtent {
    if (controller.hasClients && controller.position.hasContentDimensions) {
      return controller.position.maxScrollExtent;
    }
    return math.max(0, contentHeight - viewportHeight);
  }

  double get _scrollOffset {
    if (!controller.hasClients) {
      return 0;
    }
    return controller.offset.clamp(0.0, _maxScrollExtent).toDouble();
  }

  double get _thumbHeight {
    if (viewportHeight <= 0 || contentHeight <= 0) {
      return 0;
    }
    if (contentHeight <= viewportHeight) {
      return viewportHeight;
    }
    return (viewportHeight * viewportHeight / contentHeight)
        .clamp(_minimumThumbHeight, viewportHeight)
        .toDouble();
  }

  double get _thumbTop {
    final maxThumbTop = math.max(0.0, viewportHeight - _thumbHeight);
    final maxScrollExtent = _maxScrollExtent;
    if (maxScrollExtent <= 0 || maxThumbTop <= 0) {
      return 0;
    }
    return (_scrollOffset / maxScrollExtent * maxThumbTop)
        .clamp(0.0, maxThumbTop)
        .toDouble();
  }

  void _jumpToThumbTop(double thumbTop) {
    if (!controller.hasClients) {
      return;
    }
    final maxThumbTop = math.max(0.0, viewportHeight - _thumbHeight);
    final maxScrollExtent = _maxScrollExtent;
    if (maxThumbTop <= 0 || maxScrollExtent <= 0) {
      controller.jumpTo(0);
      return;
    }
    final offset =
        (thumbTop.clamp(0.0, maxThumbTop) / maxThumbTop) * maxScrollExtent;
    controller.jumpTo(offset.clamp(0.0, maxScrollExtent).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final thumbHeight = _thumbHeight;
          final thumbTop = _thumbTop;

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _jumpToThumbTop(details.localPosition.dy - thumbHeight / 2);
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-track',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      border: Border(
                        left: BorderSide(color: colorScheme.outlineVariant),
                        right: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 2,
                right: 2,
                top: thumbTop,
                height: thumbHeight,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    _jumpToThumbTop(_thumbTop + (details.primaryDelta ?? 0));
                  },
                  child: Container(
                    key: const ValueKey<String>(
                      'timeline-vertical-scrollbar-thumb',
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(width),
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
