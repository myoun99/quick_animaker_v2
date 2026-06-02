import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

void main() {
  testWidgets('renders timeline cells', (tester) async {
    await tester.pumpWidget(_panel());

    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('timeline-frame-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('timeline-frame-23')), findsOneWidget);
  });

  testWidgets('select frame callback', (tester) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _panel(onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex),
    );

    await tester.tap(find.byKey(const ValueKey<String>('timeline-frame-5')));

    expect(selectedFrameIndex, 5);
  });

  testWidgets('highlights current frame', (tester) async {
    await tester.pumpWidget(_panel(currentFrameIndex: 3));

    expect(find.text('Frame 3'), findsOneWidget);
    expect(find.textContaining('Current frame: 3'), findsOneWidget);
  });
}

Widget _panel({
  int currentFrameIndex = 0,
  int frameCount = 12,
  ValueChanged<int>? onSelectFrame,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TimelinePanel(
        currentFrameIndex: currentFrameIndex,
        frameCount: frameCount,
        onSelectFrame: onSelectFrame ?? (_) {},
      ),
    ),
  );
}
