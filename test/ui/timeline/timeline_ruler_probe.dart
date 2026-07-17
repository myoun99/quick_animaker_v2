import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_ruler_painter.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart'
    show XSheetFrameRailPainter;

/// Probe surface for the PAINTERIZED frame ruler (UI-R13 #1): headers are
/// paint, not widgets — labels, states and geometry live on
/// [TimelineFrameRulerPainter], reached through the strip's
/// 'timeline-frame-ruler-paint' CustomPaint. The widget-key era
/// ('timeline-frame-header-N') is over.

Finder timelineRulerPaintFinder() =>
    find.byKey(const ValueKey<String>('timeline-frame-ruler-paint'));

TimelineFrameRulerPainter timelineRulerPainter(
  WidgetTester tester, {
  int index = 0,
}) {
  final paint = tester
      .widgetList<CustomPaint>(timelineRulerPaintFinder())
      .elementAt(index);
  return paint.painter! as TimelineFrameRulerPainter;
}

/// Whether the ruler's painted window contains [frameIndex].
bool timelineHeaderInWindow(
  WidgetTester tester,
  int frameIndex, {
  int index = 0,
}) {
  final painter = timelineRulerPainter(tester, index: index);
  return frameIndex >= painter.frameStartIndex &&
      frameIndex < painter.frameEndIndexExclusive;
}

/// The resolved header model at [frameIndex] (label, seconds line,
/// selected/outside/cached states, background).
TimelineRulerHeaderModel timelineHeaderModel(
  WidgetTester tester,
  int frameIndex, {
  int index = 0,
}) => timelineRulerPainter(tester, index: index).headerModelAt(frameIndex);

/// The header cell's GLOBAL rect (tap targets, alignment assertions).
Rect timelineHeaderGlobalRect(
  WidgetTester tester,
  int frameIndex, {
  int index = 0,
}) {
  final box = tester
      .renderObjectList<RenderBox>(timelineRulerPaintFinder())
      .elementAt(index);
  return timelineRulerPainter(
    tester,
    index: index,
  ).headerRectFor(frameIndex).shift(box.localToGlobal(Offset.zero));
}

// --- The X-sheet frame rail's painter probe (UI-R14 #1) ------------------

Finder xsheetRailPaintFinder() =>
    find.byKey(const ValueKey<String>('xsheet-frame-rail-paint'));

XSheetFrameRailPainter xsheetRailPainter(WidgetTester tester) =>
    tester.widget<CustomPaint>(xsheetRailPaintFinder()).painter!
        as XSheetFrameRailPainter;

/// Whether the rail's painted window contains [frameIndex].
bool xsheetFrameRowInWindow(WidgetTester tester, int frameIndex) {
  final painter = xsheetRailPainter(tester);
  return frameIndex >= painter.frameStartIndex &&
      frameIndex < painter.frameEndIndexExclusive;
}

/// The resolved rail-row model at [frameIndex].
TimelineRulerHeaderModel xsheetFrameRowModel(
  WidgetTester tester,
  int frameIndex,
) => xsheetRailPainter(tester).modelAt(frameIndex);

/// The rail row's GLOBAL rect.
Rect xsheetFrameRowGlobalRect(WidgetTester tester, int frameIndex) {
  final box = tester.renderObject<RenderBox>(xsheetRailPaintFinder());
  return xsheetRailPainter(
    tester,
  ).rowRectFor(frameIndex).shift(box.localToGlobal(Offset.zero));
}
