import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'timeline_cell_style.dart' show timelineSelectedFrameBorderColor;
import 'timeline_frame_window.dart';

/// A frame ruler's MOVING layer: the current-frame tint and the green
/// cached-range bar, painted OVER the static header cells and driven by
/// [CustomPainter.repaint] — so a playhead tick, a warming frame or a cel
/// edit repaints this thin strip instead of re-recording the ruler's
/// labels and grid lines.
///
/// The split matters twice over:
///
/// - **Cost.** The static strip lays out a glyph per labeled frame. Keeping
///   the cursor tint in it meant every seek re-recorded all of that; here a
///   seek draws two rects.
/// - **Correctness.** Whether a frame is cached is DERIVED state — the
///   playback composite self-validates against a signature, so nothing
///   raises an "invalidated" event when a cel is edited. There is no token
///   a gated painter could compare. The only honest answer is to keep the
///   read cheap and repaint it on every signal that can change it, which is
///   what [repaintSignal] carries (warm progress + pixel edits) alongside
///   the playhead.
///
/// Shared by the storyboard ruler and the timeline ruler (it was the
/// storyboard's private painter first).
class TimelineRulerCursorOverlayPainter extends CustomPainter {
  TimelineRulerCursorOverlayPainter({
    required this.playhead,
    required Listenable? repaintSignal,
    required this.windowBucket,
    required this.viewportMainExtent,
    required this.renderedFrames,
    required this.contentFrames,
    required this.cellWidth,
    required this.isFrameCached,
    this.axis = Axis.horizontal,
  }) : super(
         repaint: Listenable.merge([?playhead, ?repaintSignal, windowBucket]),
       );

  /// The FRAME axis. Horizontal rulers (timeline, storyboard) run frames
  /// left-to-right and hug the bar to the bottom edge; the X-sheet rail runs
  /// them top-to-bottom with the cells to its right, so the bar hugs the
  /// right edge instead. One widget, both orientations (the Axis policy the
  /// rest of the timeline follows).
  final Axis axis;

  /// The frame the tint follows; a null VALUE draws no tint (the
  /// storyboard's "no playhead" state).
  final ValueListenable<int?>? playhead;

  /// UI-R15→R16 self-windowing: paint covers the bucket-derived slice of
  /// the full-bounds strip (repaint once per span crossing).
  final ValueListenable<int> windowBucket;
  final double viewportMainExtent;
  final int renderedFrames;
  final int contentFrames;
  final double cellWidth;
  final bool Function(int globalFrame)? isFrameCached;

  /// The AE-style cached-range green (the header cells' own strip color).
  static const Color cachedBarColor = Color(0xFF54B435);

  /// The strip's thickness along the ruler's bottom edge.
  static const double cachedBarThickness = 3;

  ({int startIndex, int endIndexExclusive}) _visibleWindow() {
    if (viewportMainExtent <= 0 || cellWidth <= 0) {
      return (startIndex: 0, endIndexExclusive: renderedFrames);
    }
    final window = timelineFrameWindowFor(
      bucket: windowBucket.value,
      cellExtent: cellWidth,
      viewportExtent: viewportMainExtent,
    );
    return (
      startIndex: math.max(0, window.startIndex),
      endIndexExclusive: math.min(renderedFrames, window.endIndexExclusive),
    );
  }

  /// The cached RUNS this overlay would draw — the probe surface tests read
  /// instead of scraping the canvas.
  List<({int startIndex, int endIndexExclusive})> cachedRuns() {
    final cached = isFrameCached;
    final runs = <({int startIndex, int endIndexExclusive})>[];
    if (cached == null) {
      return runs;
    }
    final window = _visibleWindow();
    final end = math.min(window.endIndexExclusive, contentFrames);
    var runStart = -1;
    for (var frame = window.startIndex; frame <= end; frame += 1) {
      if (frame < end && cached(frame)) {
        runStart = runStart < 0 ? frame : runStart;
        continue;
      }
      if (runStart >= 0) {
        runs.add((startIndex: runStart, endIndexExclusive: frame));
        runStart = -1;
      }
    }
    return runs;
  }

  /// The frame the tint marks, or null when it is outside the window (the
  /// probe surface for "which frame does the ruler show as current").
  int? tintedFrame() {
    final frame = playhead?.value;
    if (frame == null) {
      return null;
    }
    final window = _visibleWindow();
    return frame >= window.startIndex && frame < window.endIndexExclusive
        ? frame
        : null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final horizontal = axis == Axis.horizontal;
    final barPaint = Paint()..color = cachedBarColor;
    for (final run in cachedRuns()) {
      final start = run.startIndex * cellWidth;
      final extent = (run.endIndexExclusive - run.startIndex) * cellWidth;
      canvas.drawRect(
        horizontal
            ? Rect.fromLTWH(
                start,
                size.height - cachedBarThickness,
                extent,
                cachedBarThickness,
              )
            : Rect.fromLTWH(
                size.width - cachedBarThickness,
                start,
                cachedBarThickness,
                extent,
              ),
        barPaint,
      );
    }

    final frame = tintedFrame();
    if (frame != null) {
      // Matches the header cell's selected fill: the same tint over the
      // same surface the cell would have blended it onto.
      canvas.drawRect(
        horizontal
            ? Rect.fromLTWH(frame * cellWidth, 0, cellWidth, size.height)
            : Rect.fromLTWH(0, frame * cellWidth, size.width, cellWidth),
        Paint()
          ..color = timelineSelectedFrameBorderColor.withValues(alpha: 0.12),
      );
    }
  }

  @override
  bool shouldRepaint(TimelineRulerCursorOverlayPainter oldDelegate) =>
      !identical(oldDelegate.windowBucket, windowBucket) ||
      oldDelegate.viewportMainExtent != viewportMainExtent ||
      oldDelegate.renderedFrames != renderedFrames ||
      oldDelegate.contentFrames != contentFrames ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.axis != axis ||
      !identical(oldDelegate.playhead, playhead) ||
      // VALUE-compared, not identity: a method tear-off (`session.isCached`)
      // is a fresh object every build but compares EQUAL, so `identical`
      // here would repaint on every unrelated rebuild — the churn that hid
      // in the ruler painters.
      oldDelegate.isFrameCached != isFrameCached;
}

/// The overlay, mounted the way both rulers want it: pointer-transparent
/// and on its own raster layer, so its repaints never touch the static
/// strip underneath.
class TimelineRulerCursorOverlay extends StatelessWidget {
  const TimelineRulerCursorOverlay({
    super.key,
    required this.keyValue,
    required this.playhead,
    required this.repaintSignal,
    required this.windowBucket,
    required this.viewportMainExtent,
    required this.renderedFrames,
    required this.contentFrames,
    required this.cellWidth,
    required this.isFrameCached,
    this.axis = Axis.horizontal,
  });

  final Axis axis;
  final String keyValue;
  final ValueListenable<int?>? playhead;
  final Listenable? repaintSignal;
  final ValueListenable<int> windowBucket;
  final double viewportMainExtent;
  final int renderedFrames;
  final int contentFrames;
  final double cellWidth;
  final bool Function(int globalFrame)? isFrameCached;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          key: ValueKey<String>(keyValue),
          painter: TimelineRulerCursorOverlayPainter(
            playhead: playhead,
            repaintSignal: repaintSignal,
            windowBucket: windowBucket,
            viewportMainExtent: viewportMainExtent,
            renderedFrames: renderedFrames,
            contentFrames: contentFrames,
            cellWidth: cellWidth,
            isFrameCached: isFrameCached,
            axis: axis,
          ),
        ),
      ),
    );
  }
}
