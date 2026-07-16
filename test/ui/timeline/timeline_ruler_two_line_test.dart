import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_header_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

/// UI-R10 #27: the ruler reads TWO lines — seconds on top (plain second
/// index on its boundary), frame numbers below (absolute in frame mode,
/// the 1..fps cycle in seconds mode; no quote notation anywhere).
void main() {
  Widget harness({required bool showSeconds}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: TimelineFrameHeaderRow(
          frameStartIndex: 22,
          frameEndIndexExclusive: 28,
          currentFrameIndex: 22,
          playbackFrameCount: 48,
          leadingFrameSpacerWidth: 0,
          trailingFrameSpacerWidth: 0,
          metrics: const TimelineGridMetrics(
            frameCellWidth: 48,
            layerRowHeight: 52,
          ),
          onSelectFrame: (_) {},
          framesPerSecond: 24,
          showSeconds: showSeconds,
        ),
      ),
    ),
  );

  testWidgets('frame mode: absolute numbers below, the second index on '
      'its boundary above', (tester) async {
    await tester.pumpWidget(harness(showSeconds: false));

    expect(find.text('23'), findsOneWidget, reason: 'frame 22 prints 23');
    expect(find.text('25'), findsOneWidget, reason: 'frame 24 prints 25');
    // The seconds line: frame 24 starts second 2.
    expect(find.text('2'), findsOneWidget);
    // No quote notation anywhere (plain numbers only).
    expect(find.textContaining("'"), findsNothing);
    expect(find.textContaining('"'), findsNothing);
  });

  testWidgets('seconds mode: the bottom line cycles 1..fps', (tester) async {
    await tester.pumpWidget(harness(showSeconds: true));

    expect(find.text('23'), findsOneWidget, reason: 'frame 22 → cycle 23');
    expect(find.text('24'), findsOneWidget, reason: 'frame 23 → cycle 24');
    // Frame 24 restarts the cycle at 1 — and its seconds label 2 sits on
    // the same boundary.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2), reason: 'cycle 2 + second 2');
    expect(find.text('25'), findsNothing, reason: 'no absolute numbers');
  });
}
