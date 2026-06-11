import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_view.dart';

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

Future<void> _addLayer(WidgetTester tester) async {
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('timeline-toolbar-add-layer-button'),
  );
}

Future<void> _tapTimelineCell(WidgetTester tester, ValueKey<String> key) async {
  final cell = find.byKey(key);
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

Future<void> _switchToCut(WidgetTester tester, String cutId) async {
  await tester.tap(find.byKey(ValueKey<String>('cut-list-entry-$cutId')));
  await tester.pumpAndSettle();
}

Future<void> _createSecondCut(WidgetTester tester) async {
  await _tapCutCommandButton(tester, const ValueKey<String>('new-cut-button'));
}

Future<void> _dragCutOnto(
  WidgetTester tester, {
  required String sourceCutId,
  required String targetCutId,
}) async {
  final source = find.byKey(ValueKey<String>('cut-list-entry-$sourceCutId'));
  final target = find.byKey(ValueKey<String>('cut-list-entry-$targetCutId'));
  await tester.ensureVisible(source);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();

  await tester.dragFrom(
    tester.getCenter(source),
    tester.getCenter(target) - tester.getCenter(source),
  );
  await tester.pumpAndSettle();
}

Finder _timelineCell(String layerId, int frameIndex) {
  return find.byKey(ValueKey<String>('timeline-cell-$layerId-$frameIndex'));
}

void _expectCellText(String layerId, int frameIndex, String text) {
  expect(
    find.descendant(
      of: _timelineCell(layerId, frameIndex),
      matching: find.text(text),
    ),
    findsOneWidget,
  );
}

void _expectNoCellText(String layerId, int frameIndex, String text) {
  expect(
    find.descendant(
      of: _timelineCell(layerId, frameIndex),
      matching: find.text(text),
    ),
    findsNothing,
  );
}

Future<void> _renameCurrentFrame(WidgetTester tester, String name) async {
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('rename-frame-button'),
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('rename-frame-text-field')),
    name,
  );
  await tester.tap(
    find.byKey(const ValueKey<String>('rename-frame-ok-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _openCutNoteDialog(WidgetTester tester) async {
  await _tapCutCommandButton(
    tester,
    const ValueKey<String>('edit-cut-note-button'),
  );
}

Future<void> _saveCutNote(WidgetTester tester, String note) async {
  await _openCutNoteDialog(tester);
  await tester.enterText(
    find.byKey(const ValueKey<String>('cut-note-text-field')),
    note,
  );
  await _tapCutNoteSaveButton(tester);
}

Future<void> _tapCutNoteSaveButton(WidgetTester tester) async {
  final saveButton = find.byKey(const ValueKey<String>('save-cut-note-button'));
  await tester.ensureVisible(saveButton);
  await tester.pumpAndSettle();
  await tester.tap(saveButton);
  await tester.pumpAndSettle();
}

Future<void> _tapCutNoteCancelButton(WidgetTester tester) async {
  final cancelButton = find.byKey(
    const ValueKey<String>('cancel-cut-note-button'),
  );
  await tester.ensureVisible(cancelButton);
  await tester.pumpAndSettle();
  await tester.tap(cancelButton);
  await tester.pumpAndSettle();
}

String _cutNoteFieldText(WidgetTester tester) {
  return tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('cut-note-text-field')),
          )
          .controller
          ?.text ??
      '';
}

Future<String> _currentCutNoteFromDialog(WidgetTester tester) async {
  await _openCutNoteDialog(tester);
  final note = _cutNoteFieldText(tester);
  await _tapCutNoteCancelButton(tester);
  return note;
}

Future<void> _renameActiveCut(WidgetTester tester, String name) async {
  await _tapCutCommandButton(
    tester,
    const ValueKey<String>('rename-cut-button'),
  );
  await tester.enterText(
    find.byKey(const ValueKey<String>('rename-cut-text-field')),
    name,
  );
  await tester.tap(
    find.byKey(const ValueKey<String>('rename-cut-confirm-button')),
  );
  await tester.pumpAndSettle();
}

Future<void> _createSecondAuthoredFrame(WidgetTester tester) async {
  await _tapTimelineCell(
    tester,
    const ValueKey<String>('timeline-cell-sample-layer-1-1'),
  );
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('blank-exposure-button'),
  );
  await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
}

String _cellActionHint(WidgetTester tester) {
  return _statusText(tester, const ValueKey<String>('cell-action-hint'));
}

String _statusText(WidgetTester tester, ValueKey<String> key) {
  final status = tester.widget<Text>(find.byKey(key));
  return status.data ?? '';
}

bool _isActionButtonEnabled(WidgetTester tester, ValueKey<String> key) {
  final button = find.byKey(key);
  final widget = tester.widget(button);

  return switch (widget) {
    TextButton(:final onPressed) => onPressed != null,
    IconButton(:final onPressed) => onPressed != null,
    _ => _isDescendantIconButtonEnabled(tester, button),
  };
}

bool _isDescendantIconButtonEnabled(WidgetTester tester, Finder button) {
  final iconButton = tester.widget<IconButton>(
    find.descendant(of: button, matching: find.byType(IconButton)),
  );
  return iconButton.onPressed != null;
}

IconData _layerKindIcon(WidgetTester tester, String layerId) {
  final finder = find.byKey(
    ValueKey<String>('timeline-layer-kind-icon-$layerId'),
  );
  return tester.widget<Icon>(finder).icon!;
}

void _expectCutOrder(WidgetTester tester, List<String> cutIds) {
  final centers = [
    for (final cutId in cutIds)
      tester
          .getCenter(find.byKey(ValueKey<String>('cut-list-entry-$cutId')))
          .dx,
  ];

  for (var index = 1; index < centers.length; index += 1) {
    expect(centers[index], greaterThan(centers[index - 1]));
  }
}

Future<void> _tapCutCommandButton(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _tapTopBarButton(WidgetTester tester, ValueKey<String> key) async {
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _tapUndoButton(WidgetTester tester) async {
  await _tapTopBarButton(tester, const ValueKey<String>('undo-button'));
}

Future<void> _tapRedoButton(WidgetTester tester) async {
  await _tapTopBarButton(tester, const ValueKey<String>('redo-button'));
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
    expect(find.byKey(const ValueKey<String>('cut-list-bar')), findsOneWidget);
    expect(find.byTooltip('New Cut'), findsOneWidget);
    expect(find.byTooltip('Rename Cut'), findsOneWidget);
    expect(find.byTooltip('Edit Cut Note'), findsOneWidget);
    expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
    expect(find.byTooltip('Move Cut Left'), findsOneWidget);
    expect(find.byTooltip('Move Cut Right'), findsOneWidget);
    expect(find.byTooltip('Delete Cut'), findsOneWidget);
    expect(find.text('Cuts:'), findsOneWidget);
    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(find.text('New Drawing'), findsNothing);
  });

  testWidgets('top row keeps cut actions and undo redo reachable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(const ValueKey<String>('top-toolbar-scroll-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('top-toolbar-row')),
      findsOneWidget,
    );
    expect(find.byTooltip('New Cut'), findsOneWidget);
    expect(find.byTooltip('Rename Cut'), findsOneWidget);
    expect(find.byTooltip('Edit Cut Note'), findsOneWidget);
    expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
    expect(find.byTooltip('Move Cut Left'), findsOneWidget);
    expect(find.byTooltip('Move Cut Right'), findsOneWidget);
    expect(find.byTooltip('Delete Cut'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('undo-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('redo-button')), findsOneWidget);

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    _expectCellText('sample-layer-1', 0, '○');

    await _tapUndoButton(tester);

    _expectCellText('sample-layer-1', 0, 'X');
    _expectNoCellText('sample-layer-1', 0, '○');

    await _tapRedoButton(tester);

    _expectCellText('sample-layer-1', 0, '○');
  });

  testWidgets('does not expose future cut management features', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byTooltip('Reorder Cut'), findsNothing);
    expect(find.byTooltip('Move Cut Left'), findsOneWidget);
    expect(find.byTooltip('Move Cut Right'), findsOneWidget);
    expect(find.byTooltip('Linked Cut'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('cut-reorder-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('cut-reorder-handle')),
      findsNothing,
    );
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('cut-management-panel')),
      findsNothing,
    );
    expect(find.text('Cut Management'), findsNothing);
    expect(find.text('Manage Cuts'), findsNothing);
    expect(find.text('Conte Panel'), findsNothing);
    expect(find.text('Storyboard Panel'), findsNothing);
    expect(find.text('Metadata Panel'), findsNothing);
    expect(find.text('Cut Inspector'), findsNothing);
    expect(find.text('StoryboardLayer'), findsNothing);
    expect(find.text('StoryboardPanel'), findsNothing);
    expect(find.text('actionMemo'), findsNothing);
    expect(find.text('dialogueMemo'), findsNothing);
    expect(find.byType(ReorderableListView), findsNothing);
  });

  testWidgets('dragging Cut 2 before Cut 1 keeps Cut 2 active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    _expectCutOrder(tester, ['sample-cut', 'cut-1']);

    await _dragCutOnto(tester, sourceCutId: 'cut-1', targetCutId: 'sample-cut');

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );
  });

  testWidgets('dragging Cut 1 after Cut 2 supports undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    _expectCutOrder(tester, ['sample-cut', 'cut-1']);

    await _dragCutOnto(tester, sourceCutId: 'sample-cut', targetCutId: 'cut-1');

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await _tapUndoButton(tester);

    _expectCutOrder(tester, ['sample-cut', 'cut-1']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await _tapRedoButton(tester);

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );
  });

  testWidgets('move cut buttons reorder active cut left with undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    _expectCutOrder(tester, ['sample-cut', 'cut-1']);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('move-cut-left-button'),
    );

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );

    await _tapUndoButton(tester);

    _expectCutOrder(tester, ['sample-cut', 'cut-1']);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);

    await _tapRedoButton(tester);

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
  });

  testWidgets('move cut buttons reorder active cut right with undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    _expectCutOrder(tester, ['sample-cut', 'cut-1']);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('move-cut-right-button'),
    );

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await _tapUndoButton(tester);

    _expectCutOrder(tester, ['sample-cut', 'cut-1']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);

    await _tapRedoButton(tester);

    _expectCutOrder(tester, ['cut-1', 'sample-cut']);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('move cut buttons are disabled at cut list edges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('move-cut-left-button'),
      ),
      isFalse,
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('move-cut-right-button'),
      ),
      isTrue,
    );

    await _switchToCut(tester, 'cut-1');

    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('move-cut-left-button'),
      ),
      isTrue,
    );
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('move-cut-right-button'),
      ),
      isFalse,
    );
  });

  testWidgets('creates a new cut from the cut list command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byTooltip('New Cut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsNothing,
    );

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('new-cut-button'),
    );

    expect(find.text('New Cut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsOneWidget,
    );
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('Cut 2'), findsNothing);
  });

  testWidgets('duplicates the active cut from the cut list command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsNothing,
    );

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('duplicate-cut-button'),
    );

    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('Cut 1 Copy'), findsOneWidget);
    expect(find.text('Cut 2'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-sample-cut')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsOneWidget,
    );
    expect(find.byTooltip('Active: Cut 1 Copy'), findsOneWidget);
    expect(find.byTooltip('Linked Cut'), findsNothing);
  });

  testWidgets('deletes the active cut from the cut list command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    expect(find.byTooltip('Delete Cut'), findsOneWidget);
    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('New Cut'), findsOneWidget);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('delete-cut-button'),
    );

    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-sample-cut')),
      findsNothing,
    );
    expect(find.text('Cut 1'), findsNothing);
    expect(find.text('New Cut'), findsOneWidget);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
  });

  testWidgets('replaces the last deleted cut through the cut command action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('delete-cut-button'),
    );

    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-sample-cut')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsOneWidget,
    );
    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('long multi-line cut note remains editable and savable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    const longNote = '''Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
Line 7
Line 8''';

    await _openCutNoteDialog(tester);
    expect(
      find.byKey(const ValueKey<String>('cut-note-text-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('save-cut-note-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cancel-cut-note-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('cut-note-text-field')),
      longNote,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('cancel-cut-note-button')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('save-cut-note-button')),
    );
    await _tapCutNoteSaveButton(tester);

    expect(await _currentCutNoteFromDialog(tester), longNote);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('different cuts keep separate cut notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    await _saveCutNote(tester, 'Cut 1 note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    expect(await _currentCutNoteFromDialog(tester), '');

    await _saveCutNote(tester, 'Cut 2 note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 note');

    await _switchToCut(tester, 'sample-cut');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');
  });

  testWidgets('undo and redo update the correct cut note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    await _saveCutNote(tester, 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    await _saveCutNote(tester, 'Cut 2 old note');
    await _saveCutNote(tester, 'Cut 2 new note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 new note');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );

    await _tapUndoButton(tester);

    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 old note');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );

    await _switchToCut(tester, 'sample-cut');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    await _tapRedoButton(tester);

    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 new note');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );

    await _switchToCut(tester, 'sample-cut');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');
  });

  testWidgets('edit cut note button opens dialog with current note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byTooltip('Edit Cut Note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('edit-cut-note-button')),
      findsOneWidget,
    );

    await _saveCutNote(tester, 'Old note');
    await _openCutNoteDialog(tester);

    expect(find.text('Edit Cut Note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('cut-note-text-field')),
      findsOneWidget,
    );
    expect(_cutNoteFieldText(tester), 'Old note');
    expect(
      find.byKey(const ValueKey<String>('save-cut-note-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cancel-cut-note-button')),
      findsOneWidget,
    );

    await _tapCutNoteCancelButton(tester);
  });

  testWidgets(
    'saving cut note supports undo and redo without changing active cut',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      await _saveCutNote(tester, 'Old note');
      expect(await _currentCutNoteFromDialog(tester), 'Old note');
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(
        tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
        const CutId('sample-cut'),
      );

      await _saveCutNote(tester, 'New note');

      expect(find.text('Edit Cut Note'), findsNothing);
      expect(await _currentCutNoteFromDialog(tester), 'New note');
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(
        tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
        const CutId('sample-cut'),
      );

      await _tapUndoButton(tester);

      expect(await _currentCutNoteFromDialog(tester), 'Old note');
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(
        tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
        const CutId('sample-cut'),
      );

      await _tapRedoButton(tester);

      expect(await _currentCutNoteFromDialog(tester), 'New note');
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(
        tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
        const CutId('sample-cut'),
      );
    },
  );

  testWidgets(
    'canceling cut note dialog does not change note or create history',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      await _openCutNoteDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey<String>('cut-note-text-field')),
        'Canceled note',
      );
      await _tapCutNoteCancelButton(tester);

      expect(find.text('Edit Cut Note'), findsNothing);
      expect(await _currentCutNoteFromDialog(tester), '');
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(
        _isActionButtonEnabled(tester, const ValueKey<String>('undo-button')),
        isFalse,
      );
    },
  );

  testWidgets('saving unchanged cut note skips history entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _openCutNoteDialog(tester);
    expect(_cutNoteFieldText(tester), '');
    await _tapCutNoteSaveButton(tester);

    expect(find.text('Edit Cut Note'), findsNothing);
    expect(await _currentCutNoteFromDialog(tester), '');
    expect(
      _isActionButtonEnabled(tester, const ValueKey<String>('undo-button')),
      isFalse,
    );
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('opens and cancels rename cut dialog without mutation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.byTooltip('Rename Cut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('rename-cut-button')),
      findsOneWidget,
    );

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('rename-cut-button'),
    );

    expect(find.text('Rename Cut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('rename-cut-text-field')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey<String>('rename-cut-text-field')),
          )
          .controller
          ?.text,
      'Cut 1',
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-cut-text-field')),
      'Canceled Cut',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('rename-cut-cancel-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rename Cut'), findsNothing);
    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('Canceled Cut'), findsNothing);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('renames active cut and supports undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _renameActiveCut(tester, 'Scene A');

    expect(find.text('Scene A'), findsOneWidget);
    expect(find.text('Cut 1'), findsNothing);
    expect(find.byTooltip('Active: Scene A'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await _tapUndoButton(tester);

    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('Scene A'), findsNothing);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await _tapRedoButton(tester);

    expect(find.text('Scene A'), findsOneWidget);
    expect(find.text('Cut 1'), findsNothing);
    expect(find.byTooltip('Active: Scene A'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );
  });

  testWidgets('ignores empty rename cut input', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _renameActiveCut(tester, '   ');

    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    final undoButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Undo'),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('allows duplicate cut names without merging cuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _renameActiveCut(tester, 'Cut 1');

    expect(find.text('Cut 1'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-sample-cut')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
      findsOneWidget,
    );
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(find.byTooltip('Switch to Cut 1'), findsOneWidget);
    expect(find.textContaining('already'), findsNothing);
    expect(find.textContaining('duplicate'), findsNothing);
  });

  testWidgets('uses the sample cut resolved from the project by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('Cut 2'), findsNothing);
    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.text('Layer: B'), findsNothing);
    expect(find.text('B'), findsNothing);
    expect(find.text('New Cut'), findsNothing);
    expect(find.text('A'), findsWidgets);
    expect(find.text('X'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-sample-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-sample-layer-2-0')),
      findsNothing,
    );
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
  });

  testWidgets('initial timeline layer shows animation kind icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(
        const ValueKey<String>('timeline-layer-kind-icon-sample-layer-1'),
      ),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, 'sample-layer-1'), Icons.brush_outlined);
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
    expect(find.text('A'), findsWidgets);
  });

  testWidgets('Add Layer creates an animation kind icon for active B', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _addLayer(tester);

    expect(
      find.byKey(
        const ValueKey<String>('timeline-layer-kind-icon-sample-layer-2'),
      ),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, 'sample-layer-2'), Icons.brush_outlined);
    expect(find.text('Layer: B'), findsOneWidget);
    expect(find.bySemanticsLabel('Animation layer'), findsNWidgets(2));
  });

  testWidgets('storyboard toggle updates the active layer kind icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(_layerKindIcon(tester, 'sample-layer-1'), Icons.brush_outlined);
    expect(
      _statusText(tester, const ValueKey<String>('active-layer-kind-label')),
      'Animation Layer',
    );

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-storyboard-layer-button'),
    );

    expect(
      _layerKindIcon(tester, 'sample-layer-1'),
      Icons.auto_stories_outlined,
    );
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);
    expect(
      _statusText(tester, const ValueKey<String>('active-layer-kind-label')),
      'Storyboard Layer',
    );

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-storyboard-layer-button'),
    );

    expect(_layerKindIcon(tester, 'sample-layer-1'), Icons.brush_outlined);
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
  });

  testWidgets('multiple layers can show different layer kind icons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _addLayer(tester);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-storyboard-layer-button'),
    );

    expect(_layerKindIcon(tester, 'sample-layer-1'), Icons.brush_outlined);
    expect(
      _layerKindIcon(tester, 'sample-layer-2'),
      Icons.auto_stories_outlined,
    );
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);
    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);

    final layerAName = find.byKey(
      const ValueKey<String>('timeline-layer-name-sample-layer-1'),
    );
    await tester.ensureVisible(layerAName);
    await tester.pumpAndSettle();
    await tester.tap(layerAName);
    await tester.pumpAndSettle();

    expect(find.text('Layer: A'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timeline-selected-layer')),
      findsOneWidget,
    );
  });

  testWidgets('pressing Add Layer first creates active B above A', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.text('Layer: B'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-row-sample-layer-2')),
      findsNothing,
    );

    await _addLayer(tester);

    expect(find.text('Layer: B'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-sample-layer-2-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-selected-layer')),
      findsOneWidget,
    );
    _expectCellText('sample-layer-2', 0, 'X');

    final layerBTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-sample-layer-2'),
          ),
        )
        .dy;
    final layerATop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-sample-layer-1'),
          ),
        )
        .dy;
    expect(layerBTop, lessThan(layerATop));
  });

  testWidgets('switches between existing sample cuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'sample-cut');

    expect(find.text('Cut 1'), findsOneWidget);
    expect(find.text('New Cut'), findsOneWidget);
    expect(find.text('Cut 2'), findsNothing);
    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(find.byTooltip('Switch to New Cut'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cut-list-entry-cut-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to Cut 1'), findsOneWidget);
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(find.text('X'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('cut-1'),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('cut-list-entry-sample-cut')),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(find.byTooltip('Switch to New Cut'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    expect(
      tester.widget<CanvasView>(find.byType(CanvasView)).cutId,
      const CutId('sample-cut'),
    );
  });

  testWidgets('new frame after switching to Cut 2 stays scoped to Cut 2', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    _expectCellText('layer-1', 0, 'X');

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-1'),
    );
    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));

    _expectCellText('layer-1', 0, 'X');
    _expectCellText('layer-1', 1, '○');
    expect(find.text('Cell: Drawing start'), findsOneWidget);

    await _switchToCut(tester, 'sample-cut');

    expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    _expectCellText('sample-layer-1', 0, 'X');
    _expectNoCellText('sample-layer-1', 1, '○');

    await _switchToCut(tester, 'cut-1');

    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    _expectCellText('layer-1', 1, '○');
  });

  testWidgets(
    'blank and mark edits after switching to Cut 2 do not affect Cut 1',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());
      await _createSecondCut(tester);

      await _switchToCut(tester, 'cut-1');
      await _tapTimelineCell(
        tester,
        const ValueKey<String>('timeline-cell-layer-1-1'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );
      _expectCellText('layer-1', 1, '○');

      await _tapTimelineCell(
        tester,
        const ValueKey<String>('timeline-cell-layer-1-2'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('blank-exposure-button'),
      );
      _expectCellText('layer-1', 2, 'X');

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('toggle-mark-button'),
      );
      _expectCellText('layer-1', 2, '●');
      expect(find.text('Cell: Blank start (X) + Mark ●'), findsOneWidget);

      await _switchToCut(tester, 'sample-cut');

      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      _expectCellText('sample-layer-1', 0, 'X');
      _expectNoCellText('sample-layer-1', 1, 'X');
      _expectNoCellText('sample-layer-1', 2, '●');
      expect(find.bySemanticsLabel('inbetween mark'), findsNothing);
    },
  );

  testWidgets('exposure edit after switching to Cut 2 stays on Cut 2 entry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    expect(find.text('Duration: 1'), findsOneWidget);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('increase-exposure-button'),
    );

    expect(find.text('Duration: 2'), findsOneWidget);
    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-1'),
    );
    expect(find.text('Cell: Held drawing'), findsOneWidget);
    _expectNoCellText('layer-1', 1, 'X');

    await _switchToCut(tester, 'sample-cut');

    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.text('Cell: Blank start (X)'), findsOneWidget);
    _expectCellText('sample-layer-1', 0, 'X');
    _expectNoCellText('sample-layer-1', 1, '○');
    expect(find.text('Duration: -'), findsOneWidget);
  });

  testWidgets(
    'cut switching clears copied frame before cross-cut linked paste',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());
      await _createSecondCut(tester);
      await _switchToCut(tester, 'sample-cut');

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('copy-frame-button'),
      );
      expect(
        _statusText(tester, const ValueKey<String>('copied-frame-status')),
        startsWith('Copy: ui-frame-'),
      );

      await _switchToCut(tester, 'cut-1');

      expect(find.byTooltip('Active: New Cut'), findsOneWidget);
      expect(find.text('Copy: -'), findsOneWidget);
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('paste-linked-frame-button'),
        ),
        isFalse,
      );

      await _tapTimelineCell(
        tester,
        const ValueKey<String>('timeline-cell-layer-1-1'),
      );

      expect(find.text('Copy: -'), findsOneWidget);
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('paste-linked-frame-button'),
        ),
        isFalse,
      );
      _expectNoCellText('layer-1', 1, '○');
    },
  );

  testWidgets('undo and redo smoke after cut switching keeps Cut 2 active', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-1'),
    );
    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    _expectCellText('layer-1', 1, '○');

    await _tapUndoButton(tester);

    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    expect(find.text('Layer: A'), findsOneWidget);
    _expectNoCellText('layer-1', 1, '○');

    await _tapRedoButton(tester);

    expect(find.byTooltip('Active: New Cut'), findsOneWidget);
    _expectCellText('layer-1', 1, '○');
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
      find.byKey(const ValueKey<String>('timeline-toolbar-create-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-toolbar-copy-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-toolbar-edit-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-toolbar-exposure-group')),
      findsOneWidget,
    );
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

  testWidgets('phase 22 compact cell action hints update by cell state', (
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
    expect(find.text('Layer: A'), findsOneWidget);
    expect(find.text('Frame: 1'), findsOneWidget);
    expect(find.text('Cell: Blank start (X)'), findsOneWidget);
    expect(_cellActionHint(tester), contains('X:'));
    expect(_cellActionHint(tester), contains('New Frame'));
    expect(_cellActionHint(tester), isNot(contains('replace X')));
    expect(_cellActionHint(tester), isNot(contains('will')));

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
    expect(_cellActionHint(tester), contains('Drawing'));
    expect(_cellActionHint(tester), contains('Copy / Rename / Delete'));
    expect(
      _cellActionHint(tester),
      isNot(contains('delete this drawing frame')),
    );
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
    expect(_cellActionHint(tester), contains('Drawing + ●'));
    expect(_cellActionHint(tester), contains('Copy / Rename / Delete'));
    expect(_cellActionHint(tester), isNot(contains('drawing and its mark')));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(_cellActionHint(tester), contains('Held'));
    expect(_cellActionHint(tester), contains('Copy / Rename'));
    expect(_cellActionHint(tester), isNot(contains('Rename Frame')));
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
    expect(_cellActionHint(tester), contains('New Frame'));
    expect(_cellActionHint(tester), isNot(contains('New Frame can create')));

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-mark-button'),
    );
    expect(_cellActionHint(tester), contains('Empty + ●'));
    expect(_cellActionHint(tester), contains('Mark'));
    expect(_cellActionHint(tester), isNot(contains('will remove')));

    expect(find.byTooltip('New Frame'), findsOneWidget);
    expect(find.byTooltip('Blank / X'), findsOneWidget);
    expect(find.byTooltip('Mark ●'), findsOneWidget);
    expect(find.byTooltip('Rename Frame'), findsOneWidget);
    expect(find.byTooltip('Delete Cell'), findsOneWidget);
    expect(find.byTooltip('Decrease Exposure'), findsOneWidget);
    expect(find.byTooltip('Increase Exposure'), findsOneWidget);
  });

  testWidgets('initial layer starts with a blank exposure at frame 1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final layer1FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );

    expect(
      find.descendant(of: layer1FirstCell, matching: find.text('X')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-sample-layer-2-0')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('blank exposure start'), findsOneWidget);
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
      expect(find.text('Layer: A'), findsOneWidget);
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
      await _addLayer(tester);
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

  testWidgets('rename to empty clears frame name', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    await _renameCurrentFrame(tester, 'A1');
    expect(find.text('A1'), findsWidgets);

    await _renameCurrentFrame(tester, '   ');

    final layer1FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    expect(
      find.descendant(of: layer1FirstCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.text('A1'), findsNothing);
  });

  testWidgets('conflicting frame name dialog cancel leaves frames unchanged', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    await _renameCurrentFrame(tester, 'A1');
    await _createSecondAuthoredFrame(tester);

    await _renameCurrentFrame(tester, 'A1');

    expect(
      find.byKey(const ValueKey<String>('frame-name-conflict-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('frame-name-conflict-cancel-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('frame-name-conflict-link-button')),
      findsOneWidget,
    );
    expect(find.text('Rename only'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('frame-name-conflict-cancel-button')),
    );
    await tester.pumpAndSettle();

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(find.text('Links: 1'), findsOneWidget);
  });

  testWidgets('conflicting frame name link merges into existing material', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    await _renameCurrentFrame(tester, 'A1');
    await _createSecondAuthoredFrame(tester);

    await _renameCurrentFrame(tester, 'A1');
    await tester.tap(
      find.byKey(const ValueKey<String>('frame-name-conflict-link-button')),
    );
    await tester.pumpAndSettle();

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-sample-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(find.text('Links: 2'), findsOneWidget);
    expect(find.text('Rename only'), findsNothing);
  });

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
    expect(find.text('Links: -'), findsOneWidget);
    expect(find.text('Copy: -'), findsOneWidget);
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

    expect(find.text('Links: 1'), findsOneWidget);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('copy-frame-button'),
      ),
      isTrue,
    );
    expect(_cellActionHint(tester), contains('Copy'));
    expect(_cellActionHint(tester), isNot(contains('Copy Frame can')));

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
    expect(_cellActionHint(tester), contains('Paste'));
    expect(_cellActionHint(tester), isNot(contains('Paste Linked Frame')));

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
    expect(find.text('Links: 2'), findsOneWidget);
    expect(
      _statusText(tester, const ValueKey<String>('copied-frame-status')),
      startsWith('Copy: ui-frame-'),
    );
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
    await _addLayer(tester);

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
