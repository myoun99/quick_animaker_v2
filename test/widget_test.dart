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

  testWidgets('initial layer starts with a blank exposure at frame 1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );

    expect(
      find.descendant(of: firstCell, matching: find.text('X')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('blank exposure start'), findsOneWidget);
    expect(find.bySemanticsLabel('blank held exposure'), findsWidgets);
    expect(find.text('●'), findsNothing);
  });

  testWidgets('new frame replaces initial blank exposure with drawing start', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await tester.tap(find.byKey(const ValueKey<String>('new-frame-button')));
    await tester.pump();

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );

    expect(
      find.descendant(of: firstCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.text('X'), findsNothing);
    expect(find.text('●'), findsNothing);
  });
}
