import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';

void main() {
  Future<void> tapToolbarButton(WidgetTester tester, Finder button) async {
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

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
    expect(find.bySemanticsLabel('inbetween mark'), findsNothing);
  });

  testWidgets(
    'mark button toggles current cell without changing exposure marker',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final markButton = find.byKey(
        const ValueKey<String>('toggle-mark-button'),
      );
      expect(markButton, findsOneWidget);
      expect(find.text('Mark ●'), findsOneWidget);

      final layer1FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-sample-layer-1-0'),
      );

      await tapToolbarButton(tester, markButton);

      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('inbetween mark'), findsOneWidget);

      await tapToolbarButton(tester, markButton);

      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsNothing,
      );
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('X')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'new frame replaces selected layer blank exposure with drawing start',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      await tapToolbarButton(tester, newFrameButton);

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
      expect(find.bySemanticsLabel('inbetween mark'), findsNothing);
    },
  );
  testWidgets(
    'frame editing toolbar buttons, rename dialog, and delete cell work',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final renameButton = find.byKey(
        const ValueKey<String>('rename-frame-button'),
      );
      final deleteButton = find.byKey(
        const ValueKey<String>('delete-cell-button'),
      );
      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      final markButton = find.byKey(
        const ValueKey<String>('toggle-mark-button'),
      );

      expect(renameButton, findsOneWidget);
      expect(deleteButton, findsOneWidget);
      expect(tester.widget<TextButton>(renameButton).onPressed, isNull);
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNotNull);

      await tapToolbarButton(tester, newFrameButton);

      expect(tester.widget<TextButton>(renameButton).onPressed, isNotNull);
      await tapToolbarButton(tester, renameButton);

      final renameDialog = find.byType(AlertDialog);
      expect(renameDialog, findsOneWidget);
      expect(
        find.descendant(
          of: renameDialog,
          matching: find.byKey(
            const ValueKey<String>('rename-frame-text-field'),
          ),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('rename-frame-text-field')),
        'A1',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('rename-frame-ok-button')),
      );
      await tester.pumpAndSettle();

      final layer1FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-sample-layer-1-0'),
      );
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('A1')),
        findsOneWidget,
      );

      await tapToolbarButton(tester, markButton);
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsOneWidget,
      );

      await tapToolbarButton(tester, deleteButton);
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('A1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsNothing,
      );

      await tapToolbarButton(tester, deleteButton);
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('A1')),
        findsNothing,
      );
      expect(tester.widget<TextButton>(renameButton).onPressed, isNull);
    },
  );

  testWidgets('rename cancel leaves frame marker unchanged', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final newFrameButton = find.byKey(
      const ValueKey<String>('new-frame-button'),
    );
    final renameButton = find.byKey(
      const ValueKey<String>('rename-frame-button'),
    );

    await tapToolbarButton(tester, newFrameButton);
    await tapToolbarButton(tester, renameButton);
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-frame-text-field')),
      'Cancelled',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('rename-frame-cancel-button')),
    );
    await tester.pumpAndSettle();

    final layer1FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    expect(
      find.descendant(of: layer1FirstCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.text('Cancelled'), findsNothing);
  });
}
