import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';

void main() {
  testWidgets('shows placeholder app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('QuickAnimaker v2.1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('new-frame-button')),
      findsOneWidget,
    );
    expect(find.text('New Frame'), findsOneWidget);
    expect(find.text('New Drawing'), findsNothing);
  });

  testWidgets('initial layers start with blank exposures at frame 1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final layer1FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    final layer2FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-2-0'),
    );

    expect(
      find.descendant(of: layer1FirstCell, matching: find.text('X')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: layer2FirstCell, matching: find.text('X')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('blank exposure start'), findsNWidgets(2));
    expect(find.bySemanticsLabel('blank held exposure'), findsWidgets);
    expect(find.text('●'), findsNothing);
  });

  testWidgets(
    'new frame replaces selected layer blank exposure with drawing start',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      await tester.ensureVisible(newFrameButton);
      await tester.pumpAndSettle();

      await tester.tap(newFrameButton);
      await tester.pumpAndSettle();

      final layer1FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-sample-layer-1-0'),
      );
      final layer2FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-sample-layer-2-0'),
      );

      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('○')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: layer2FirstCell, matching: find.text('X')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('drawing start'), findsOneWidget);
      expect(find.bySemanticsLabel('blank exposure start'), findsOneWidget);
      expect(find.text('●'), findsNothing);
    },
  );
}
