import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsProperties;

import 'timeline_cell_style.dart';
import 'timeline_grid_metrics.dart';

/// The resolved per-header model — THE probe surface for ruler tests
/// (labels, states and colors live here, not in widget trees), the ruler
/// counterpart of the cells painter's model (UI-R9 #12b → UI-R13 #1).
class TimelineRulerHeaderModel {
  const TimelineRulerHeaderModel({
    required this.frameIndex,
    required this.label,
    required this.secondsLabel,
    required this.selected,
    required this.outsidePlaybackRange,
    required this.cached,
    required this.background,
  });

  final int frameIndex;

  /// The bottom-line number ('' when the cell is unlabeled at this zoom).
  final String label;

  /// The top-line second index ('' off second boundaries).
  final String secondsLabel;

  final bool selected;
  final bool outsidePlaybackRange;
  final bool cached;
  final Color background;
}

/// The frame ruler strip as ONE CustomPainter (UI-R13 #1 — the same
/// painterization the drawing rows got in UI-R9 #12b): header cell
/// backgrounds/borders, the two-line labels (UI-R10 #27) and the cached
/// green strip paint in a single pass; the per-frame header widgets are
/// gone. Shared by the timeline header and the storyboard ruler (which
/// already share [TimelineFrameHeaderRow]); scrubbing stays on the
/// viewport-level listeners (G8) — the strip itself is passive.
class TimelineFrameRulerPainter extends CustomPainter {
  TimelineFrameRulerPainter({
    required this.frameStartIndex,
    required this.frameEndIndexExclusive,
    required this.currentFrameIndex,
    required this.playbackFrameCount,
    required this.leadingFrameSpacerWidth,
    required this.metrics,
    required this.colorScheme,
    this.framesPerSecond = 24,
    this.showSeconds = false,
    this.isFrameCached,
  });

  final int frameStartIndex;
  final int frameEndIndexExclusive;
  final int currentFrameIndex;
  final int playbackFrameCount;
  final double leadingFrameSpacerWidth;
  final TimelineGridMetrics metrics;
  final ColorScheme colorScheme;
  final int framesPerSecond;
  final bool showSeconds;
  final bool Function(int frameIndex)? isFrameCached;

  /// The header cell's rect in the strip's local coordinates (the probe
  /// geometry tests and taps share).
  Rect headerRectFor(int frameIndex) => Rect.fromLTWH(
    leadingFrameSpacerWidth +
        (frameIndex - frameStartIndex) * metrics.frameCellWidth,
    0,
    metrics.frameCellWidth,
    metrics.layerRowHeight,
  );

  String _frameNumberLabel(int frameIndex) {
    if (!showSeconds) {
      return '${frameIndex + 1}';
    }
    final safeFps = framesPerSecond > 0 ? framesPerSecond : 24;
    return '${frameIndex % safeFps + 1}';
  }

  /// The resolved per-header model — the probe surface.
  TimelineRulerHeaderModel headerModelAt(int frameIndex) {
    final selected = frameIndex == currentFrameIndex;
    final outside = frameIndex >= playbackFrameCount;
    final labeled = frameIndex % metrics.frameLabelEveryFrames == 0;
    final safeFps = framesPerSecond > 0 ? framesPerSecond : 24;
    return TimelineRulerHeaderModel(
      frameIndex: frameIndex,
      label: labeled ? _frameNumberLabel(frameIndex) : '',
      secondsLabel: frameIndex % safeFps == 0
          ? '${frameIndex ~/ safeFps + 1}'
          : '',
      selected: selected,
      outsidePlaybackRange: outside,
      cached:
          frameIndex < playbackFrameCount &&
          (isFrameCached?.call(frameIndex) ?? false),
      background: selected
          ? Color.alphaBlend(
              timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
              colorScheme.surface,
            )
          : outside
          ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.72)
          : colorScheme.surface,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final narrow = metrics.frameCellWidth < 16;
    final labelEveryFrames = metrics.frameLabelEveryFrames;
    final fillPaint = Paint();
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final linePaint = Paint()..strokeWidth = 1;

    for (
      var frameIndex = frameStartIndex;
      frameIndex < frameEndIndexExclusive;
      frameIndex += 1
    ) {
      final model = headerModelAt(frameIndex);
      final rect = headerRectFor(frameIndex);
      canvas.drawRect(rect, fillPaint..color = model.background);

      final borderColor = model.outsidePlaybackRange
          ? colorScheme.outlineVariant.withValues(alpha: 0.55)
          : colorScheme.outlineVariant;
      final labeled = frameIndex % labelEveryFrames == 0;
      if (narrow) {
        // Zoomed-out cells drop the per-cell border noise: the baseline
        // always draws, labeled cells keep a left tick (G8 contract).
        canvas.drawLine(
          Offset(rect.left, rect.bottom - 0.5),
          Offset(rect.right, rect.bottom - 0.5),
          linePaint..color = borderColor,
        );
        if (labeled) {
          canvas.drawLine(
            Offset(rect.left + 0.5, rect.top),
            Offset(rect.left + 0.5, rect.bottom),
            linePaint..color = borderColor,
          );
        }
      } else {
        canvas.drawRect(rect.deflate(0.5), borderPaint..color = borderColor);
      }

      // Bottom line: in-cell centered when every cell labels itself, the
      // every-Nth overlay style (left-anchored) otherwise (UI-R10 #27).
      if (model.label.isNotEmpty) {
        final style = labelEveryFrames == 1
            ? TextStyle(
                fontSize: 11,
                color: model.outsidePlaybackRange
                    ? colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                    : colorScheme.onSurface,
              )
            : TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant);
        final painter = _label(model.label, style);
        if (labelEveryFrames == 1) {
          painter.paint(
            canvas,
            Offset(
              rect.center.dx - painter.width / 2,
              rect.bottom - painter.height - 1,
            ),
          );
        } else {
          painter.paint(
            canvas,
            Offset(rect.left + 2, rect.bottom - painter.height - 1),
          );
        }
      }

      // Top line: the second index on fps boundaries (UI-R10 #27).
      if (model.secondsLabel.isNotEmpty) {
        final painter = _label(
          model.secondsLabel,
          TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        );
        painter.paint(canvas, Offset(rect.left + 2, rect.top + 1));
      }

      // The AE-style cached-range strip along the bottom edge.
      if (model.cached) {
        canvas.drawRect(
          Rect.fromLTWH(rect.left, rect.bottom - 3, rect.width, 3),
          fillPaint..color = const Color(0xFF54B435),
        );
      }
    }
  }

  TextPainter _label(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant TimelineFrameRulerPainter oldDelegate) =>
      oldDelegate.frameStartIndex != frameStartIndex ||
      oldDelegate.frameEndIndexExclusive != frameEndIndexExclusive ||
      oldDelegate.currentFrameIndex != currentFrameIndex ||
      oldDelegate.playbackFrameCount != playbackFrameCount ||
      oldDelegate.leadingFrameSpacerWidth != leadingFrameSpacerWidth ||
      oldDelegate.metrics != metrics ||
      oldDelegate.framesPerSecond != framesPerSecond ||
      oldDelegate.showSeconds != showSeconds ||
      !identical(oldDelegate.colorScheme, colorScheme) ||
      !identical(oldDelegate.isFrameCached, isFrameCached);

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    // One node per labeled header (the old per-cell widgets' surface).
    final nodes = <CustomPainterSemantics>[];
    for (
      var frameIndex = frameStartIndex;
      frameIndex < frameEndIndexExclusive;
      frameIndex += 1
    ) {
      final model = headerModelAt(frameIndex);
      if (model.label.isEmpty) {
        continue;
      }
      nodes.add(
        CustomPainterSemantics(
          rect: headerRectFor(frameIndex),
          properties: SemanticsProperties(
            label: 'frame ${frameIndex + 1}',
            textDirection: TextDirection.ltr,
          ),
        ),
      );
    }
    return nodes;
  };
}
