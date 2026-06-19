import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_header_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

void main() {
  Future<void> pumpHeaderRow(
    WidgetTester tester, {
    required int frameStartIndex,
    required int frameEndIndexExclusive,
    required int currentFrameIndex,
    required int playbackFrameCount,
    required ValueChanged<int> onSelectFrame,
    double leadingFrameSpacerWidth = 96,
    double trailingFrameSpacerWidth = 144,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TimelineFrameHeaderRow(
            frameStartIndex: frameStartIndex,
            frameEndIndexExclusive: frameEndIndexExclusive,
            currentFrameIndex: currentFrameIndex,
            playbackFrameCount: playbackFrameCount,
            leadingFrameSpacerWidth: leadingFrameSpacerWidth,
            trailingFrameSpacerWidth: trailingFrameSpacerWidth,
            metrics: TimelineGridMetrics.defaults,
            onSelectFrame: onSelectFrame,
          ),
        ),
      ),
    );
  }

  testWidgets('renders stable row and spacer keys exactly once', (
    tester,
  ) async {
    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 6,
      currentFrameIndex: 4,
      playbackFrameCount: 6,
      onSelectFrame: (_) {},
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-leading-spacer'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('timeline-frame-header-trailing-spacer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders visible frame header keys for the supplied window', (
    tester,
  ) async {
    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 6,
      currentFrameIndex: 4,
      playbackFrameCount: 6,
      onSelectFrame: (_) {},
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-4')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-6')),
      findsNothing,
    );
  });

  testWidgets('renders one-based frame number text', (tester) async {
    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 6,
      currentFrameIndex: 4,
      playbackFrameCount: 6,
      onSelectFrame: (_) {},
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
  });

  testWidgets('tapping a frame header selects that frame', (tester) async {
    int? selectedFrameIndex;

    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 6,
      currentFrameIndex: 4,
      playbackFrameCount: 6,
      onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-frame-header-4')),
    );

    expect(selectedFrameIndex, 4);
  });

  testWidgets('current frame header keeps stable key behavior', (tester) async {
    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 6,
      currentFrameIndex: 4,
      playbackFrameCount: 6,
      onSelectFrame: (_) {},
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-4')),
      findsOneWidget,
    );
  });

  testWidgets('outside-playback frame headers are still rendered', (
    tester,
  ) async {
    await pumpHeaderRow(
      tester,
      frameStartIndex: 3,
      frameEndIndexExclusive: 7,
      currentFrameIndex: 4,
      playbackFrameCount: 5,
      onSelectFrame: (_) {},
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-6')),
      findsOneWidget,
    );
  });
}
