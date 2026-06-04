import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';

void main() {
  testWidgets('shows placeholder app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('QuickAnimaker v2.1'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('new-frame-button')), findsOneWidget);
    expect(find.text('New Frame'), findsOneWidget);
    expect(find.text('New Drawing'), findsNothing);
  });
}
