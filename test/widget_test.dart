import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';

Future<void> _tapToolbarButton(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _tapTimelineCell(WidgetTester tester, ValueKey<String> key) async {
  final cell = find.byKey(key);
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

String _cellActionHint(WidgetTester tester) {
  final hint = tester.widget<Text>(
    find.byKey(const ValueKey<String>('cell-action-hint')),
  );
  return hint.data ?? '';
}

bool _isActionButtonEnabled(WidgetTester tester, ValueKey<String> key) {
  final widget = tester.widget(find.byKey(key));
  return switch (widget) {
    TextButton(:final onPressed) => onPressed != null,
    IconButton(:final onPressed) => onPressed != null,
    _ => throw StateError('Unsupported button type: ${widget.runtimeType}'),
  };
}

void _expectTimelineActionTooltips() {
  expect(find.byTooltip('New Frame'), findsOneWidget);
  expect(find.byTooltip('Blank / X'), findsOneWidget);
  expect(find.byTooltip('Mark ●'), findsOneWidget);
  expect(find.byTooltip('Copy Frame'), findsOneWidget);
  expect(find.byTooltip('Paste Linked Frame'), findsOneWidget);
  expect(find.byTooltip('Rename Frame'), findsOneWidget);
  expect(find.byTooltip('Delete Cell'), findsOneWidget);
  expect(find.byTooltip('Decrease Exposure'), findsOneWidget);
  expect(find.byTooltip('Increase Exposure'), findsOneWidget);
}

void _expectTimelineActionKeys() {
  expect(
    find.byKey(const ValueKey<String>('new-frame-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('blank-exposure-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('toggle-mark-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('copy-frame-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('paste-linked-frame-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('rename-frame-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('delete-cell-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('decrease-exposure-button')),
    findsOneWidget,
  );
  expect(
    find.byKey(const ValueKey<String>('increase-exposure-button')),
    findsOneWidget,
  );
}

void main() {
  testWidgets('shows placeholder app shell', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('QuickAnimaker v2.1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('new-frame-button')),
      findsOneWidget,
    );
    expect(find.byTooltip('New Frame'), findsOneWidget);
    expect(find.text('New Drawing'), findsNothing);
  });

  testWidgets('timeline action toolbar hosts cell action controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final toolbar = find.byKey(
      const ValueKey<String>('timeline-action-toolbar'),
    );
    final cellActions = find.byKey(
      const ValueKey<String>('cell-actions-section'),
    );

    expect(toolbar, findsOneWidget);
    expect(cellActions, findsOneWidget);
    expect(find.descendant(of: toolbar, matching: cellActions), findsOneWidget);
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byKey(const ValueKey<String>('new-frame-button')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byKey(const ValueKey<String>('cell-action-hint')),
      ),
      findsOneWidget,
    );
    _expectTimelineActionKeys();
    _expectTimelineActionTooltips();
    expect(
      find.byKey(const ValueKey<String>('current-layer-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('current-frame-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('current-cell-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('linked-frame-uses-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('copied-frame-status')),
      findsOneWidget,
    );
  });

  testWidgets('phase 18 cell actions section and hints update by cell state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(const ValueKey<String>('cell-actions-section')),
      findsOneWidget,
    );
    expect(find.text('Cell Actions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cell-action-hint')),
      findsOneWidget,
    );
    expect(find.text('Layer: Layer 1'), findsOneWidget);
    expect(find.text('Frame: 1'), findsOneWidget);
    expect(find.text('Cell: Blank start (X)'), findsOneWidget);
    expect(_cellActionHint(tester), contains('New Frame'));
    expect(_cellActionHint(tester), contains('replace X'));

    final deleteButton = find.byKey(
      const ValueKey<String>('delete-cell-button'),
    );
    final renameButton = find.byKey(
      const ValueKey<String>('rename-frame-button'),
    );
    expect(deleteButton, findsOneWidget);
    expect(renameButton, findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    expect(_cellActionHint(tester), contains('Delete Cell'));
    expect(_cellActionHint(tester), contains('delete this drawing frame'));
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isTrue,
    );

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    expect(_cellActionHint(tester), contains('drawing and its mark'));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(_cellActionHint(tester), contains('Held drawing'));
    expect(_cellActionHint(tester), contains('Rename Frame'));
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('rename-frame-button'),
      ),
      isTrue,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('delete-cell-button'),
    );
    expect(_cellActionHint(tester), contains('Empty'));
    expect(_cellActionHint(tester), contains('New Frame can create'));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    expect(_cellActionHint(tester), contains('Empty + Mark ●'));
    expect(_cellActionHint(tester), contains('Mark ● will remove the mark'));

    expect(find.byTooltip('New Frame'), findsOneWidget);
    expect(find.byTooltip('Blank / X'), findsOneWidget);
    expect(find.byTooltip('Mark ●'), findsOneWidget);
    expect(find.byTooltip('Rename Frame'), findsOneWidget);
    expect(find.byTooltip('Delete Cell'), findsOneWidget);
    expect(find.byTooltip('Decrease Exposure'), findsOneWidget);
    expect(find.byTooltip('Increase Exposure'), findsOneWidget);
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
    'selection status text updates for blank, drawing, name, and mark',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      expect(
        find.byKey(const ValueKey<String>('current-layer-status')),
        findsOneWidget,
      );
      expect(find.text('Layer: Layer 1'), findsOneWidget);
      expect(find.text('Frame: 1'), findsOneWidget);
      expect(find.text('Cell: Blank start (X)'), findsOneWidget);

      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      await tester.ensureVisible(newFrameButton);
      await tester.pumpAndSettle();
      await tester.tap(newFrameButton);
      await tester.pumpAndSettle();

      expect(find.text('Cell: Drawing start'), findsOneWidget);

      final renameButton = find.byKey(
        const ValueKey<String>('rename-frame-button'),
      );
      await tester.ensureVisible(renameButton);
      await tester.pumpAndSettle();
      await tester.tap(renameButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('rename-frame-text-field')),
        'A1',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('rename-frame-ok-button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cell: Drawing start: A1'), findsOneWidget);

      final markButton = find.byKey(
        const ValueKey<String>('toggle-mark-button'),
      );
      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();
      await tester.tap(markButton);
      await tester.pumpAndSettle();

      expect(find.text('Cell: Drawing start: A1 + Mark ●'), findsOneWidget);
    },
  );

  testWidgets('selection status and toolbar state distinguish held cells', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final deleteButton = find.byKey(
      const ValueKey<String>('delete-cell-button'),
    );
    final renameButton = find.byKey(
      const ValueKey<String>('rename-frame-button'),
    );
    expect(deleteButton, findsOneWidget);
    expect(renameButton, findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(find.text('Frame: 2'), findsOneWidget);
    expect(find.text('Cell: Blank held'), findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    final newFrameButton = find.byKey(
      const ValueKey<String>('new-frame-button'),
    );
    await tester.ensureVisible(newFrameButton);
    await tester.pumpAndSettle();
    await tester.tap(newFrameButton);
    await tester.pumpAndSettle();
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isTrue,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-2'),
    );
    final blankButton = find.byKey(
      const ValueKey<String>('blank-exposure-button'),
    );
    await tester.ensureVisible(blankButton);
    await tester.pumpAndSettle();
    await tester.tap(blankButton);
    await tester.pumpAndSettle();

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(find.text('Cell: Held drawing'), findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('rename-frame-button'),
      ),
      isTrue,
    );
  });

  testWidgets(
    'mark button toggles current cell without changing exposure marker',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final markButton = find.byKey(
        const ValueKey<String>('toggle-mark-button'),
      );
      expect(markButton, findsOneWidget);
      expect(find.byTooltip('Mark ●'), findsOneWidget);

      final layer1FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-sample-layer-1-0'),
      );

      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();
      await tester.tap(markButton);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('inbetween mark'), findsOneWidget);

      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();
      await tester.tap(markButton);
      await tester.pumpAndSettle();

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
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('rename-frame-button'),
        ),
        isFalse,
      );
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('delete-cell-button'),
        ),
        isFalse,
      );

      await tester.ensureVisible(newFrameButton);
      await tester.pumpAndSettle();
      await tester.tap(newFrameButton);
      await tester.pumpAndSettle();

      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('rename-frame-button'),
        ),
        isTrue,
      );
      await tester.ensureVisible(renameButton);
      await tester.pumpAndSettle();
      await tester.tap(renameButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('rename-frame-text-field')),
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

      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();
      await tester.tap(markButton);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsOneWidget,
      );

      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('delete-cell-button'),
        ),
        isTrue,
      );
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('A1')),
        findsNothing,
      );
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('●')),
        findsNothing,
      );
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('rename-frame-button'),
        ),
        isFalse,
      );
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('delete-cell-button'),
        ),
        isFalse,
      );
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

    await tester.ensureVisible(newFrameButton);
    await tester.pumpAndSettle();
    await tester.tap(newFrameButton);
    await tester.pumpAndSettle();
    await tester.ensureVisible(renameButton);
    await tester.pumpAndSettle();
    await tester.tap(renameButton);
    await tester.pumpAndSettle();
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

  testWidgets('linked frame copy and paste buttons link authored exposures', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final copyButton = find.byKey(const ValueKey<String>('copy-frame-button'));
    final pasteButton = find.byKey(
      const ValueKey<String>('paste-linked-frame-button'),
    );
    final linkedUsesStatus = find.byKey(
      const ValueKey<String>('linked-frame-uses-status'),
    );
    expect(copyButton, findsOneWidget);
    expect(pasteButton, findsOneWidget);
    expect(find.byTooltip('Copy Frame'), findsOneWidget);
    expect(find.byTooltip('Paste Linked Frame'), findsOneWidget);
    expect(linkedUsesStatus, findsOneWidget);
    expect(find.text('Linked uses: -'), findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('copy-frame-button'),
      ),
      isFalse,
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('paste-linked-frame-button'),
      ),
      isFalse,
    );

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));

    expect(find.text('Linked uses: 1'), findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('copy-frame-button'),
      ),
      isTrue,
    );
    expect(_cellActionHint(tester), contains('Copy Frame'));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('copy-frame-button'),
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('paste-linked-frame-button'),
      ),
      isTrue,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(_cellActionHint(tester), contains('Paste Linked Frame'));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('paste-linked-frame-button'),
    );

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.text('Linked uses: 2'), findsOneWidget);
  });

  testWidgets('linked paste replaces X and preserves mark priority', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('copy-frame-button'),
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-2-0'),
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('paste-linked-frame-button'),
      ),
      isFalse,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('blank-exposure-button'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('X')),
      findsOneWidget,
    );

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('paste-linked-frame-button'),
    );

    expect(
      find.descendant(of: secondCell, matching: find.text('●')),
      findsOneWidget,
    );
    expect(find.text('Cell: Drawing start + Mark ●'), findsOneWidget);
  });
}
