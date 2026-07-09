import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_timeline_layout.dart';

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

Finder _timelineLayerRows() {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('timeline-layer-row-');
  });
}

Future<void> _tapTimelineCell(WidgetTester tester, ValueKey<String> key) async {
  final cell = find.byKey(key);
  await tester.ensureVisible(cell);
  await tester.pumpAndSettle();
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

/// The top chips bar is retired: the storyboard panel is the cut oracle and
/// actuator now. It only exists in storyboard mode, so these helpers hop in,
/// act or read, and restore the timeline when they had to switch. Never call
/// them while a dialog is open — the mode toggle would tap the modal barrier.
Future<T> _withStoryboardPanel<T>(
  WidgetTester tester,
  Future<T> Function(StoryboardPanel panel) act,
) async {
  final wasHidden = find.byType(StoryboardPanel).evaluate().isEmpty;
  if (wasHidden) {
    await _showStoryboardPanel(tester);
  }
  final result = await act(
    tester.widget<StoryboardPanel>(find.byType(StoryboardPanel)),
  );
  if (wasHidden) {
    await _showTimelinePanel(tester);
  }
  return result;
}

Future<void> _switchToCut(WidgetTester tester, String cutId) async {
  await _withStoryboardPanel(tester, (panel) async {
    final entries = buildStoryboardTimelineLayout(panel.project);
    expect(entries.map((entry) => entry.cutId.value), contains(cutId));

    panel.onCutSelected(CutId(cutId));
    await tester.pumpAndSettle();
  });
}

Future<void> _tapStoryboardCutBlock(WidgetTester tester, String cutId) async {
  await _withStoryboardPanel(tester, (panel) async {
    await tester.tap(
      find.byKey(ValueKey<String>('storyboard-cut-block-$cutId')),
    );
    await tester.pumpAndSettle();
  });
}

Future<void> _createSecondCut(WidgetTester tester) async {
  await _tapCutCommandButton(tester, const ValueKey<String>('new-cut-button'));
}

Future<void> _expectCutName(
  WidgetTester tester,
  String cutId,
  String text,
) async {
  await _withStoryboardPanel(tester, (panel) async {
    final title = find.byKey(ValueKey<String>('storyboard-cut-title-$cutId'));
    expect(title, findsOneWidget);
    expect(tester.widget<Text>(title).data, text);
  });
}

Future<void> _expectCutExists(
  WidgetTester tester,
  String cutId, {
  required bool exists,
}) async {
  await _withStoryboardPanel(tester, (panel) async {
    expect(
      find.byKey(ValueKey<String>('storyboard-cut-block-$cutId')),
      exists ? findsOneWidget : findsNothing,
    );
  });
}

Future<void> _expectCutsNamed(
  WidgetTester tester,
  String name,
  int count,
) async {
  await _withStoryboardPanel(tester, (panel) async {
    final titles = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return widget is Text &&
          key is ValueKey<String> &&
          key.value.startsWith('storyboard-cut-title-') &&
          widget.data == name;
    });
    expect(titles, findsNWidgets(count));
  });
}

Future<void> _expectActiveCutName(WidgetTester tester, String name) async {
  await _withStoryboardPanel(tester, (panel) async {
    // The block highlight carries the active state (no ACTIVE badge);
    // the panel's activeCutId is the oracle for WHICH cut that is.
    final activeId = panel.activeCutId.value;
    expect(
      tester
          .widget<Text>(
            find.byKey(ValueKey<String>('storyboard-cut-title-$activeId')),
          )
          .data,
      name,
    );
  });
}

Future<void> _dragCutOnto(
  WidgetTester tester, {
  required String sourceCutId,
  required String targetCutId,
}) async {
  await _withStoryboardPanel(tester, (panel) async {
    final targetEntry = buildStoryboardTimelineLayout(
      panel.project,
    ).singleWhere((entry) => entry.cutId.value == targetCutId);

    panel.onCutReordered?.call(
      draggedCutId: CutId(sourceCutId),
      targetTrackId: targetEntry.trackId,
      targetCutIndex: targetEntry.cutIndex,
    );

    await tester.pumpAndSettle();
  });
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
  await _showTimelinePanel(tester);
}

Future<void> _tapCutNoteCancelButton(WidgetTester tester) async {
  final cancelButton = find.byKey(
    const ValueKey<String>('cancel-cut-note-button'),
  );
  await tester.ensureVisible(cancelButton);
  await tester.pumpAndSettle();
  await tester.tap(cancelButton);
  await tester.pumpAndSettle();
  await _showTimelinePanel(tester);
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
  // The command left the app in storyboard mode (the dialog blocked the
  // automatic return); restore the timeline the tests assume.
  await _showTimelinePanel(tester);
}

Future<void> _createSecondAuthoredFrame(WidgetTester tester) async {
  await _tapTimelineCell(
    tester,
    const ValueKey<String>('timeline-cell-default-layer-1-1'),
  );
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('blank-exposure-button'),
  );
  await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
}

String _statusText(WidgetTester tester, ValueKey<String> key) {
  final status = tester.widget<Text>(find.byKey(key));
  return status.data ?? '';
}

void _expectActiveLayerName(String name) {
  expect(
    find.descendant(
      of: find.byKey(const ValueKey<String>('timeline-selected-layer')),
      matching: find.text(name),
    ),
    findsOneWidget,
  );
}

void _expectCurrentFrame(WidgetTester tester, int frameNumber) {
  expect(
    _statusText(
      tester,
      const ValueKey<String>('timeline-current-frame-counter'),
    ),
    '$frameNumber',
  );
}

String? _selectedCellStateLabel(WidgetTester tester) {
  // The selection ring lives on the grid cursor layer, positioned exactly
  // over the selected cell — find the cell sharing its top-left and read
  // that cell's marker semantics.
  final ringTopLeft = tester.getTopLeft(
    find.byKey(const ValueKey<String>('timeline-selected-cell')),
  );
  final cells = find.byWidgetPredicate(
    (widget) =>
        widget.key is ValueKey<String> &&
        (widget.key as ValueKey<String>).value.startsWith('timeline-cell-'),
  );
  for (final element in cells.evaluate()) {
    final cellFinder = find.byKey(element.widget.key!);
    if (tester.getTopLeft(cellFinder) != ringTopLeft) {
      continue;
    }
    final texts = tester.widgetList<Text>(
      find.descendant(of: cellFinder, matching: find.byType(Text)),
    );
    return texts.isEmpty ? null : texts.first.semanticsLabel;
  }
  return null;
}

Future<void> _showStoryboardPanel(WidgetTester tester) async {
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('timeline-mode-storyboard-button'),
  );
}

Future<void> _showTimelinePanel(WidgetTester tester) async {
  await _tapToolbarButton(
    tester,
    const ValueKey<String>('timeline-mode-timeline-button'),
  );
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

Future<void> _expectCutOrder(WidgetTester tester, List<String> cutIds) async {
  await _withStoryboardPanel(tester, (panel) async {
    expect(
      buildStoryboardTimelineLayout(
        panel.project,
      ).map((entry) => entry.cutId.value).toList(),
      cutIds,
    );
  });
}

Future<CutId> _activeCutId(WidgetTester tester) {
  return _withStoryboardPanel(tester, (panel) async => panel.activeCutId);
}

Future<void> _tapCutCommandButton(
  WidgetTester tester,
  ValueKey<String> key,
) async {
  // Cut management actions live in the storyboard panel's toolbar: enter
  // storyboard mode, act, and return to the timeline the tests assume.
  // When the action opened a dialog, stay put — switching modes would tap
  // the modal barrier and dismiss it; the dialog helpers switch back after
  // the dialog closes.
  await _showStoryboardPanel(tester);
  final button = find.byKey(key);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
  if (find.byType(Dialog).evaluate().isEmpty) {
    await _showTimelinePanel(tester);
  }
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
  expect(find.byTooltip('Add'), findsOneWidget);
  expect(find.byTooltip('Blank / X'), findsOneWidget);
  expect(find.byTooltip('Mark ●'), findsOneWidget);
  expect(find.byTooltip('Copy Frame'), findsOneWidget);
  expect(find.byTooltip('Paste Linked Frame'), findsOneWidget);
  expect(find.byTooltip('Edit Instance'), findsOneWidget);
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
    expect(find.text('QuickAnimaker'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('new-frame-button')),
      findsOneWidget,
    );
    expect(find.byTooltip('Add'), findsOneWidget);
    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectActiveCutName(tester, 'Cut 1');
    expect(find.text('New Drawing'), findsNothing);

    // Cut management actions live in the storyboard panel's toolbar.
    await _showStoryboardPanel(tester);
    expect(find.byTooltip('New Cut'), findsOneWidget);
    expect(find.byTooltip('Rename Cut'), findsOneWidget);
    expect(find.byTooltip('Edit Cut Note'), findsOneWidget);
    expect(find.byTooltip('Canvas Size'), findsOneWidget);
    expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
    expect(find.byTooltip('Move Cut Left'), findsOneWidget);
    expect(find.byTooltip('Move Cut Right'), findsOneWidget);
    expect(find.byTooltip('Delete Cut'), findsOneWidget);
  });

  testWidgets('default sample cut duration is 24 frames', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    // The bottom dock runs between the two vertical tool bars, so the
    // grid viewport is 88px narrower than the window — scroll far enough
    // for the cut's last frame header to materialize.
    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('timeline-frame-header-23')),
      findsOneWidget,
    );
  });

  testWidgets('timeline frame axis extends endlessly while scrolling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    // Base extent = 24-frame cut + safety/minimum cells (48 frames). Keep
    // dragging right: the endless runway must materialize headers beyond it.
    for (var i = 0; i < 5; i += 1) {
      await tester.drag(
        find.byKey(const ValueKey<String>('timeline-frame-scroll-viewport')),
        const Offset(-1200, 0),
      );
      await tester.pumpAndSettle();
    }

    final beyondBaseHeaders = find.byWidgetPredicate((widget) {
      final key = widget.key;
      if (key is! ValueKey<String> ||
          !key.value.startsWith('timeline-frame-header-')) {
        return false;
      }
      final index = int.tryParse(
        key.value.substring('timeline-frame-header-'.length),
      );
      return index != null && index >= 48;
    });
    expect(beyondBaseHeaders, findsWidgets);
  });

  testWidgets('timeline zoom buttons rescale the frame axis', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final header0 = find.byKey(
      const ValueKey<String>('timeline-frame-header-0'),
    );
    expect(tester.getSize(header0).width, 48);
    // Wide cells label every frame in-cell.
    expect(
      find.descendant(of: header0, matching: find.text('1')),
      findsOneWidget,
    );

    Future<void> zoomTo(double pixelsPerFrame) async {
      tester
          .widget<Slider>(
            find.byKey(const ValueKey<String>('timeline-zoom-slider')),
          )
          .onChanged!(pixelsPerFrame);
      await tester.pumpAndSettle();
    }

    await zoomTo(72);
    expect(tester.getSize(header0).width, 72);

    await zoomTo(24);
    expect(tester.getSize(header0).width, 24);
    // Narrow cells move their labels to the every-Nth overlay: no in-cell
    // texts anywhere in the header cells.
    expect(
      find.descendant(of: header0, matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('xsheet zoom rescales the frame row height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('timeline-orientation-toggle-button'),
    );

    final row0 = find.byKey(const ValueKey<String>('xsheet-frame-row-0'));
    expect(tester.getSize(row0).height, 36);

    // The X-sheet row height tracks the slider proportionally (36 at 48).
    tester
        .widget<Slider>(
          find.byKey(const ValueKey<String>('timeline-zoom-slider')),
        )
        .onChanged!(72);
    await tester.pumpAndSettle();
    expect(tester.getSize(row0).height, 54);
  });

  testWidgets('the time display toggle switches the counter to seconds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    String counterText() => tester
        .widget<Text>(
          find.byKey(const ValueKey<String>('timeline-current-frame-counter')),
        )
        .data!;
    expect(counterText(), '1');

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('timeline-time-display-toggle-button'),
    );
    // Frame 1 at 24fps in conte notation.
    expect(counterText(), '0+01');

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('timeline-time-display-toggle-button'),
    );
    expect(counterText(), '1');
  });

  testWidgets('xsheet frame axis extends endlessly while scrolling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('timeline-orientation-toggle-button'),
    );

    for (var i = 0; i < 5; i += 1) {
      await tester.drag(
        find.byKey(const ValueKey<String>('xsheet-frame-vertical-viewport')),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
    }

    final beyondBaseRows = find.byWidgetPredicate((widget) {
      final key = widget.key;
      if (key is! ValueKey<String> ||
          !key.value.startsWith('xsheet-frame-row-')) {
        return false;
      }
      final index = int.tryParse(
        key.value.substring('xsheet-frame-row-'.length),
      );
      return index != null && index >= 48;
    });
    expect(beyondBaseRows, findsWidgets);
  });

  testWidgets('top row keeps cut switching and undo redo reachable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    // The old top chips bar is retired; cut switching lives in the
    // storyboard panel now.
    expect(
      find.byKey(const ValueKey<String>('top-toolbar-scroll-view')),
      findsNothing,
    );
    await _expectCutExists(tester, 'default-cut-1', exists: true);
    expect(find.byKey(const ValueKey<String>('undo-button')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('redo-button')), findsOneWidget);

    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));
    _expectCellText('default-layer-1', 0, '○');

    await _tapUndoButton(tester);

    _expectCellText('default-layer-1', 0, 'X');
    _expectNoCellText('default-layer-1', 0, '○');

    await _tapRedoButton(tester);

    _expectCellText('default-layer-1', 0, '○');
  });

  testWidgets('does not expose future cut management features', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _showStoryboardPanel(tester);

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
    await _expectActiveCutName(tester, 'New Cut');
    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);

    await _dragCutOnto(
      tester,
      sourceCutId: 'cut-1',
      targetCutId: 'default-cut-1',
    );

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));
  });

  testWidgets('dragging Cut 1 after Cut 2 supports undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _expectActiveCutName(tester, 'Cut 1');
    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);

    await _dragCutOnto(
      tester,
      sourceCutId: 'default-cut-1',
      targetCutId: 'cut-1',
    );

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapUndoButton(tester);

    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapRedoButton(tester);

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));
  });

  testWidgets('move cut buttons reorder active cut left with undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    await _expectActiveCutName(tester, 'New Cut');
    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('move-cut-left-button'),
    );

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _tapUndoButton(tester);

    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);
    await _expectActiveCutName(tester, 'New Cut');

    await _tapRedoButton(tester);

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'New Cut');
  });

  testWidgets('move cut buttons reorder active cut right with undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _expectActiveCutName(tester, 'Cut 1');
    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('move-cut-right-button'),
    );

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapUndoButton(tester);

    await _expectCutOrder(tester, ['default-cut-1', 'cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');

    await _tapRedoButton(tester);

    await _expectCutOrder(tester, ['cut-1', 'default-cut-1']);
    await _expectActiveCutName(tester, 'Cut 1');
  });

  testWidgets('move cut buttons are disabled at cut list edges', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');
    // The move buttons live in the storyboard panel's toolbar.
    await _showStoryboardPanel(tester);

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

    await _expectCutExists(tester, 'cut-1', exists: false);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('new-cut-button'),
    );

    await _expectCutName(tester, 'cut-1', 'New Cut');
    await _expectCutExists(tester, 'cut-1', exists: true);
    await _expectActiveCutName(tester, 'New Cut');
    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutsNamed(tester, 'Cut 2', 0);
  });

  testWidgets('duplicates the active cut from the cut list command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _expectCutExists(tester, 'cut-1', exists: false);

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('duplicate-cut-button'),
    );

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutName(tester, 'cut-1', 'Cut 1 Copy');
    await _expectCutsNamed(tester, 'Cut 2', 0);
    await _expectCutExists(tester, 'default-cut-1', exists: true);
    await _expectCutExists(tester, 'cut-1', exists: true);
    await _expectActiveCutName(tester, 'Cut 1 Copy');
    expect(find.byTooltip('Linked Cut'), findsNothing);
  });

  testWidgets('deletes the active cut from the cut list command', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutName(tester, 'cut-1', 'New Cut');

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('delete-cut-button'),
    );

    await _expectCutExists(tester, 'default-cut-1', exists: false);
    await _expectCutExists(tester, 'default-cut-1', exists: false);
    await _expectCutExists(tester, 'cut-1', exists: true);
    await _expectActiveCutName(tester, 'New Cut');
  });

  testWidgets('replaces the last deleted cut through the cut command action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapCutCommandButton(
      tester,
      const ValueKey<String>('delete-cut-button'),
    );

    await _expectCutExists(tester, 'default-cut-1', exists: false);
    await _expectCutExists(tester, 'cut-1', exists: true);
    await _expectCutName(tester, 'cut-1', 'Cut 1');
    await _expectActiveCutName(tester, 'Cut 1');
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
    await _expectActiveCutName(tester, 'Cut 1');
  });

  testWidgets('different cuts keep separate cut notes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _saveCutNote(tester, 'Cut 1 note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    expect(await _currentCutNoteFromDialog(tester), '');

    await _saveCutNote(tester, 'Cut 2 note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 note');

    await _switchToCut(tester, 'default-cut-1');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');
  });

  testWidgets('undo and redo update the correct cut note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _saveCutNote(tester, 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    await _saveCutNote(tester, 'Cut 2 old note');
    await _saveCutNote(tester, 'Cut 2 new note');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 new note');
    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _tapUndoButton(tester);

    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 old note');
    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _switchToCut(tester, 'default-cut-1');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');

    await _switchToCut(tester, 'cut-1');
    await _tapRedoButton(tester);

    expect(await _currentCutNoteFromDialog(tester), 'Cut 2 new note');
    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _switchToCut(tester, 'default-cut-1');
    expect(await _currentCutNoteFromDialog(tester), 'Cut 1 note');
  });

  testWidgets('edit cut note button opens dialog with current note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

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
      await _expectActiveCutName(tester, 'Cut 1');
      expect(await _activeCutId(tester), const CutId('default-cut-1'));

      await _saveCutNote(tester, 'New note');

      expect(find.text('Edit Cut Note'), findsNothing);
      expect(await _currentCutNoteFromDialog(tester), 'New note');
      await _expectActiveCutName(tester, 'Cut 1');
      expect(await _activeCutId(tester), const CutId('default-cut-1'));

      await _tapUndoButton(tester);

      expect(await _currentCutNoteFromDialog(tester), 'Old note');
      await _expectActiveCutName(tester, 'Cut 1');
      expect(await _activeCutId(tester), const CutId('default-cut-1'));

      await _tapRedoButton(tester);

      expect(await _currentCutNoteFromDialog(tester), 'New note');
      await _expectActiveCutName(tester, 'Cut 1');
      expect(await _activeCutId(tester), const CutId('default-cut-1'));
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
      await _expectActiveCutName(tester, 'Cut 1');
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
    await _expectActiveCutName(tester, 'Cut 1');
  });

  testWidgets('opens and cancels rename cut dialog without mutation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

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
    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutsNamed(tester, 'Canceled Cut', 0);
    await _expectActiveCutName(tester, 'Cut 1');
  });

  testWidgets('renames active cut and supports undo and redo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _renameActiveCut(tester, 'Scene A');

    await _expectCutName(tester, 'default-cut-1', 'Scene A');
    await _expectCutsNamed(tester, 'Cut 1', 0);
    await _expectActiveCutName(tester, 'Scene A');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapUndoButton(tester);

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutsNamed(tester, 'Scene A', 0);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapRedoButton(tester);

    await _expectCutName(tester, 'default-cut-1', 'Scene A');
    await _expectCutsNamed(tester, 'Cut 1', 0);
    await _expectActiveCutName(tester, 'Scene A');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));
  });

  testWidgets('ignores empty rename cut input', (WidgetTester tester) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _renameActiveCut(tester, '   ');

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectActiveCutName(tester, 'Cut 1');
    final undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey<String>('undo-button')),
    );
    expect(undoButton.onPressed, isNull);
  });

  testWidgets('allows duplicate cut names without merging cuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _renameActiveCut(tester, 'Cut 1');

    await _expectCutsNamed(tester, 'Cut 1', 2);
    await _expectCutExists(tester, 'default-cut-1', exists: true);
    await _expectCutExists(tester, 'cut-1', exists: true);
    await _expectActiveCutName(tester, 'Cut 1');
    expect(find.textContaining('already'), findsNothing);
    expect(find.textContaining('duplicate'), findsNothing);
  });

  testWidgets('uses the sample cut resolved from the project by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutsNamed(tester, 'Cut 2', 0);
    _expectActiveLayerName('A');
    expect(find.text('B'), findsNothing);
    await _expectCutsNamed(tester, 'New Cut', 0);
    expect(find.text('A'), findsWidgets);
    expect(find.text('X'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-default-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-default-layer-2-0')),
      findsNothing,
    );
    await _expectActiveCutName(tester, 'Cut 1');
  });

  testWidgets('initial timeline layer shows animation kind icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(
        const ValueKey<String>('timeline-layer-kind-icon-default-layer-1'),
      ),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, 'default-layer-1'), Icons.brush_outlined);
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
        const ValueKey<String>('timeline-layer-kind-icon-default-layer-2'),
      ),
      findsOneWidget,
    );
    expect(_layerKindIcon(tester, 'default-layer-2'), Icons.brush_outlined);
    _expectActiveLayerName('B');
    expect(find.bySemanticsLabel('Animation layer'), findsNWidgets(2));
  });

  testWidgets('storyboard toggle updates the active layer kind icon', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(_layerKindIcon(tester, 'default-layer-1'), Icons.brush_outlined);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-storyboard-layer-button'),
    );

    expect(
      _layerKindIcon(tester, 'default-layer-1'),
      Icons.auto_stories_outlined,
    );
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('toggle-storyboard-layer-button'),
    );

    expect(_layerKindIcon(tester, 'default-layer-1'), Icons.brush_outlined);
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

    expect(_layerKindIcon(tester, 'default-layer-1'), Icons.brush_outlined);
    expect(
      _layerKindIcon(tester, 'default-layer-2'),
      Icons.auto_stories_outlined,
    );
    expect(find.bySemanticsLabel('Animation layer'), findsOneWidget);
    expect(find.bySemanticsLabel('Storyboard layer'), findsOneWidget);
    expect(find.text('A'), findsWidgets);
    expect(find.text('B'), findsWidgets);

    final layerAName = find.byKey(
      const ValueKey<String>('timeline-layer-name-default-layer-1'),
    );
    await tester.ensureVisible(layerAName);
    await tester.pumpAndSettle();
    await tester.tap(layerAName);
    await tester.pumpAndSettle();

    _expectActiveLayerName('A');
  });

  testWidgets('pressing Add Layer creates B then C above active layers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    _expectActiveLayerName('A');
    expect(
      find.byKey(const ValueKey<String>('timeline-layer-row-default-layer-2')),
      findsNothing,
    );

    await _addLayer(tester);

    _expectActiveLayerName('B');
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-default-layer-2-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-selected-layer')),
      findsOneWidget,
    );
    _expectCellText('default-layer-2', 0, 'X');

    var layerBTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-default-layer-2'),
          ),
        )
        .dy;
    var layerATop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-default-layer-1'),
          ),
        )
        .dy;
    expect(layerBTop, lessThan(layerATop));

    await _addLayer(tester);

    _expectActiveLayerName('C');
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-default-layer-3-0')),
      findsOneWidget,
    );
    _expectCellText('default-layer-3', 0, 'X');

    final layerCTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-default-layer-3'),
          ),
        )
        .dy;
    layerBTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-default-layer-2'),
          ),
        )
        .dy;
    layerATop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('timeline-layer-row-default-layer-1'),
          ),
        )
        .dy;

    expect(layerCTop, lessThan(layerBTop));
    expect(layerBTop, lessThan(layerATop));
    expect(
      find.byKey(
        const ValueKey<String>('timeline-layer-kind-icon-default-layer-3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('XSheet keeps raw layer order after adding B and C', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _addLayer(tester);
    await _addLayer(tester);
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('timeline-orientation-toggle-button'),
    );

    final layerALeft = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('xsheet-layer-header-default-layer-1'),
          ),
        )
        .dx;
    final layerBLeft = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('xsheet-layer-header-default-layer-2'),
          ),
        )
        .dx;
    final layerCLeft = tester
        .getTopLeft(
          find.byKey(
            const ValueKey<String>('xsheet-layer-header-default-layer-3'),
          ),
        )
        .dx;

    expect(layerALeft, lessThan(layerBLeft));
    expect(layerBLeft, lessThan(layerCLeft));
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-default-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-default-layer-2-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-default-layer-3-0')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-cell-default-layer-1-0')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('xsheet-selected-layer')),
        matching: find.text('A'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('switches between existing sample cuts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');

    await _expectCutName(tester, 'default-cut-1', 'Cut 1');
    await _expectCutName(tester, 'cut-1', 'New Cut');
    await _expectCutsNamed(tester, 'Cut 2', 0);
    await _expectActiveCutName(tester, 'Cut 1');
    _expectActiveLayerName('A');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await _tapStoryboardCutBlock(tester, 'cut-1');

    await _expectActiveCutName(tester, 'New Cut');
    _expectActiveLayerName('A');
    expect(find.text('B'), findsNothing);
    expect(find.text('A'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(find.text('X'), findsWidgets);
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _tapStoryboardCutBlock(tester, 'default-cut-1');

    await _expectActiveCutName(tester, 'Cut 1');
    await _expectCutName(tester, 'cut-1', 'New Cut');
    _expectActiveLayerName('A');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));
  });

  testWidgets('StoryboardPanel cut selection syncs active cut surfaces', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _switchToCut(tester, 'default-cut-1');
    await _showStoryboardPanel(tester);

    expect(
      find.byKey(const ValueKey<String>('storyboard-panel')),
      findsOneWidget,
    );
    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));

    await tester.tap(
      find.byKey(const ValueKey<String>('storyboard-cut-block-cut-1')),
    );
    await tester.pumpAndSettle();

    await _expectActiveCutName(tester, 'New Cut');
    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _showTimelinePanel(tester);

    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('storyboard-panel')),
      findsNothing,
    );
  });

  testWidgets('cut switching updates StoryboardPanel highlight', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);
    await _showStoryboardPanel(tester);

    expect(await _activeCutId(tester), const CutId('cut-1'));

    await _switchToCut(tester, 'default-cut-1');

    await _expectActiveCutName(tester, 'Cut 1');
    expect(await _activeCutId(tester), const CutId('default-cut-1'));
  });

  testWidgets('new frame after switching to Cut 2 stays scoped to Cut 2', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());
    await _createSecondCut(tester);

    await _switchToCut(tester, 'cut-1');
    await _expectActiveCutName(tester, 'New Cut');
    _expectActiveLayerName('A');
    _expectCellText('layer-1', 0, 'X');

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-1'),
    );
    await _tapToolbarButton(tester, const ValueKey<String>('new-frame-button'));

    _expectCellText('layer-1', 0, 'X');
    _expectCellText('layer-1', 1, '○');
    expect(_selectedCellStateLabel(tester), 'drawing start');

    await _switchToCut(tester, 'default-cut-1');

    await _expectActiveCutName(tester, 'Cut 1');
    _expectActiveLayerName('A');
    _expectCellText('default-layer-1', 0, 'X');
    _expectNoCellText('default-layer-1', 1, '○');

    await _switchToCut(tester, 'cut-1');

    await _expectActiveCutName(tester, 'New Cut');
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
      expect(_selectedCellStateLabel(tester), 'inbetween mark');

      await _switchToCut(tester, 'default-cut-1');

      await _expectActiveCutName(tester, 'Cut 1');
      // Cut 1's layer is untouched: one empty run whose first cell reads X.
      _expectCellText('default-layer-1', 0, 'X');
      _expectNoCellText('default-layer-1', 1, 'X');
      _expectNoCellText('default-layer-1', 2, '●');
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

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('increase-exposure-button'),
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-layer-1-1'),
    );
    expect(_selectedCellStateLabel(tester), 'held exposure');
    _expectNoCellText('layer-1', 1, 'X');

    await _switchToCut(tester, 'default-cut-1');

    _expectActiveLayerName('A');
    // The fresh layer is all empty (X) cells; empty cells carry no
    // semantics label under the unified model.
    expect(_selectedCellStateLabel(tester), isNull);
    _expectCellText('default-layer-1', 0, 'X');
    _expectNoCellText('default-layer-1', 1, '○');
  });

  testWidgets(
    'comma edge grips ripple blocks TVPaint-style with one undo per drag',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      // The drawing row sits at the bottom below the camera/CAM/SE fixture
      // rows; scroll it into view via its RAIL row (cell-level ensureVisible
      // would over-scroll the custom frame viewport and push frame 0 out of
      // the virtualized window).
      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('timeline-layer-row-default-layer-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Block A at index 0, block B at index 3 with an X gap between.
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-cell-default-layer-1-3')),
      );
      await tester.pumpAndSettle();
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );

      // Grip keys are ORDINAL-based (block 0, block 1) so a start-edge drag
      // that moves the block's start index keeps its gesture subtree alive.
      final endGrip = find.byKey(
        const ValueKey<String>(
          'timeline-block-edge-grip-end-default-layer-1-0',
        ),
      );
      final startGripB = find.byKey(
        const ValueKey<String>(
          'timeline-block-edge-grip-start-default-layer-1-1',
        ),
      );
      expect(endGrip, findsOneWidget);
      expect(startGripB, findsOneWidget);

      // Lengthen A by 3: it consumes the X gap and pushes B from 3 to 4
      // with B's comma preserved.
      final gesture = await tester.startGesture(tester.getCenter(endGrip));
      await gesture.moveBy(const Offset(19, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(144, 0));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      _expectNoCellText('default-layer-1', 1, 'X');
      _expectNoCellText('default-layer-1', 2, 'X');
      _expectCellText('default-layer-1', 4, '○');

      // The whole drag is ONE undo step.
      await _tapToolbarButton(tester, const ValueKey<String>('undo-button'));
      _expectCellText('default-layer-1', 1, 'X');
      _expectCellText('default-layer-1', 3, '○');

      // START-edge drag across several cells in ONE gesture: the live
      // preview moves the block's start every step, and the drag must
      // survive it (regression: start grips died after one step). B grows
      // backward through the gap until it touches A.
      final frontDrag = await tester.startGesture(tester.getCenter(startGripB));
      await frontDrag.moveBy(const Offset(-19, 0));
      await tester.pump();
      await frontDrag.moveBy(const Offset(-48, 0));
      await tester.pumpAndSettle();
      await frontDrag.moveBy(const Offset(-48, 0));
      await tester.pumpAndSettle();
      await frontDrag.up();
      await tester.pumpAndSettle();

      _expectCellText('default-layer-1', 1, '○');
      _expectNoCellText('default-layer-1', 2, 'X');
      _expectNoCellText('default-layer-1', 3, '○');
    },
  );

  testWidgets(
    'cut switching clears copied frame before cross-cut linked paste',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());
      await _createSecondCut(tester);
      await _switchToCut(tester, 'default-cut-1');

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('copy-frame-button'),
      );

      await _switchToCut(tester, 'cut-1');

      await _expectActiveCutName(tester, 'New Cut');
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

    await _expectActiveCutName(tester, 'New Cut');
    _expectActiveLayerName('A');
    _expectNoCellText('layer-1', 1, '○');

    await _tapRedoButton(tester);

    await _expectActiveCutName(tester, 'New Cut');
    _expectCellText('layer-1', 1, '○');
  });

  testWidgets('timeline action toolbar hosts cell action controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final toolbar = find.byKey(
      const ValueKey<String>('timeline-action-toolbar'),
    );

    expect(toolbar, findsOneWidget);
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byKey(const ValueKey<String>('new-frame-button')),
      ),
      findsOneWidget,
    );
    _expectTimelineActionKeys();
    _expectTimelineActionTooltips();
    expect(
      find.byKey(const ValueKey<String>('timeline-toolbar-layer-group')),
      findsOneWidget,
    );
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
  });

  testWidgets('initial layer starts with a blank exposure at frame 1', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final layer1FirstCell = find.byKey(
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
    );

    expect(
      find.descendant(of: layer1FirstCell, matching: find.text('X')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-default-layer-2-0')),
      findsNothing,
    );
    // Paper-sheet style: only the FIRST cell of the empty run reads X.
    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('timeline-cell-default-layer-1-1'),
        ),
        matching: find.text('X'),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('drawing start'), findsNothing);
    expect(find.bySemanticsLabel('inbetween mark'), findsNothing);
  });

  testWidgets(
    'selected cell state updates for blank, drawing, name, and mark',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      _expectActiveLayerName('A');
      _expectCurrentFrame(tester, 1);
      // Empty (X) cells carry no semantics label.
      expect(_selectedCellStateLabel(tester), isNull);

      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      await tester.ensureVisible(newFrameButton);
      await tester.pumpAndSettle();
      await tester.tap(newFrameButton);
      await tester.pumpAndSettle();

      expect(_selectedCellStateLabel(tester), 'drawing start');

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

      expect(_selectedCellStateLabel(tester), 'drawing start A1');

      // Marks live on held/empty cells (never on a drawing start): hold the
      // block one frame longer, then mark the held cell.
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('increase-exposure-button'),
      );
      await _tapTimelineCell(
        tester,
        const ValueKey<String>('timeline-cell-default-layer-1-1'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('toggle-mark-button'),
      );

      expect(_selectedCellStateLabel(tester), 'inbetween mark');
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
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );
    _expectCurrentFrame(tester, 2);
    expect(_selectedCellStateLabel(tester), isNull);
    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('delete-cell-button'),
      ),
      isFalse,
    );

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
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

    // Hold the block across frames 1-3, then cut the hold at frame 3.
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('increase-exposure-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('increase-exposure-button'),
    );
    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-default-layer-1-2'),
    );
    final blankButton = find.byKey(
      const ValueKey<String>('blank-exposure-button'),
    );
    await tester.ensureVisible(blankButton);
    await tester.pumpAndSettle();
    await tester.tap(blankButton);
    await tester.pumpAndSettle();
    _expectCellText('default-layer-1', 2, 'X');

    await _tapTimelineCell(
      tester,
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );
    expect(_selectedCellStateLabel(tester), 'held exposure');
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
        const ValueKey<String>('timeline-cell-default-layer-1-0'),
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
        const ValueKey<String>('timeline-cell-default-layer-1-0'),
      );

      final newFrameButton = find.byKey(
        const ValueKey<String>('new-frame-button'),
      );
      await tester.ensureVisible(newFrameButton);
      await tester.pumpAndSettle();

      await tester.tap(newFrameButton);
      await tester.pumpAndSettle();

      final layer1FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-default-layer-1-0'),
      );
      final layer2FirstCell = find.byKey(
        const ValueKey<String>('timeline-cell-default-layer-2-0'),
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
        const ValueKey<String>('timeline-cell-default-layer-1-0'),
      );
      expect(
        find.descendant(of: layer1FirstCell, matching: find.text('A1')),
        findsOneWidget,
      );

      // Marks live on held/empty cells only; on a drawing start the mark
      // button is disabled under the unified model.
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('toggle-mark-button'),
        ),
        isFalse,
      );
      expect(markButton, findsOneWidget);

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
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
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
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('○')),
      findsOneWidget,
    );
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
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('A1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('A1')),
      findsOneWidget,
    );
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
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
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
    expect(copyButton, findsOneWidget);
    expect(pasteButton, findsOneWidget);
    expect(find.byTooltip('Copy Frame'), findsOneWidget);
    expect(find.byTooltip('Paste Linked Frame'), findsOneWidget);
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

    expect(
      _isActionButtonEnabled(
        tester,
        const ValueKey<String>('copy-frame-button'),
      ),
      isTrue,
    );

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
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('paste-linked-frame-button'),
    );

    final firstCell = find.byKey(
      const ValueKey<String>('timeline-cell-default-layer-1-0'),
    );
    final secondCell = find.byKey(
      const ValueKey<String>('timeline-cell-default-layer-1-1'),
    );
    expect(
      find.descendant(of: firstCell, matching: find.text('○')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: secondCell, matching: find.text('○')),
      findsOneWidget,
    );
  });

  testWidgets(
    'linked paste on a marked empty cell replaces the mark with a drawing',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('new-frame-button'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('copy-frame-button'),
      );
      await _addLayer(tester);

      await _tapTimelineCell(
        tester,
        const ValueKey<String>('timeline-cell-default-layer-2-0'),
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
        const ValueKey<String>('timeline-cell-default-layer-1-1'),
      );
      final secondCell = find.byKey(
        const ValueKey<String>('timeline-cell-default-layer-1-1'),
      );
      expect(
        find.descendant(of: secondCell, matching: find.text('X')),
        findsOneWidget,
      );

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('toggle-mark-button'),
      );
      expect(
        find.descendant(of: secondCell, matching: find.text('●')),
        findsOneWidget,
      );

      // One entry per cell: pasting a linked frame REPLACES the mark.
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('paste-linked-frame-button'),
      );

      expect(
        find.descendant(of: secondCell, matching: find.text('●')),
        findsNothing,
      );
      expect(
        find.descendant(of: secondCell, matching: find.text('○')),
        findsOneWidget,
      );
      expect(_selectedCellStateLabel(tester), 'drawing start');
    },
  );

  testWidgets('Copy and Paste Layer buttons expose in-memory clipboard UI', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    const copyKey = ValueKey<String>('copy-layer-button');
    const pasteKey = ValueKey<String>('paste-layer-button');

    expect(find.byKey(copyKey), findsOneWidget);
    expect(find.byTooltip('Copy Layer'), findsOneWidget);
    expect(find.byKey(pasteKey), findsOneWidget);
    expect(find.byTooltip('Paste Layer'), findsOneWidget);
    expect(_isActionButtonEnabled(tester, copyKey), isTrue);
    expect(_isActionButtonEnabled(tester, pasteKey), isFalse);

    await _tapToolbarButton(tester, copyKey);

    expect(find.byTooltip('Paste Layer (A)'), findsOneWidget);
    expect(_isActionButtonEnabled(tester, pasteKey), isTrue);
  });

  testWidgets(
    'Paste Layer creates another A, selects it, and undo/redo works',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('copy-layer-button'),
      );
      await _tapToolbarButton(
        tester,
        const ValueKey<String>('paste-layer-button'),
      );

      expect(find.text('A'), findsWidgets);
      // Two drawing rows plus the always-present S1·S2/CAM 1/camera rows.
      expect(_timelineLayerRows(), findsNWidgets(6));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('timeline-selected-layer')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );

      await _tapToolbarButton(tester, const ValueKey<String>('undo-button'));
      expect(_timelineLayerRows(), findsNWidgets(5));

      await _tapToolbarButton(tester, const ValueKey<String>('redo-button'));
      expect(_timelineLayerRows(), findsNWidgets(6));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('timeline-selected-layer')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('pasted layer can be renamed and deleted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('copy-layer-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('paste-layer-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('rename-layer-button'),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-layer-text-field')),
      'Pasted',
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('rename-layer-ok-button'),
    );

    expect(find.text('Pasted'), findsWidgets);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('delete-layer-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('delete-layer-confirm-button'),
    );

    expect(find.text('Pasted'), findsNothing);
  });

  testWidgets(
    'Duplicate Layer button duplicates active layer and selects copy',
    (WidgetTester tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      final duplicateButton = find.byKey(
        const ValueKey<String>('duplicate-layer-button'),
      );
      expect(duplicateButton, findsOneWidget);
      expect(
        _isActionButtonEnabled(
          tester,
          const ValueKey<String>('duplicate-layer-button'),
        ),
        isTrue,
      );

      await _tapToolbarButton(
        tester,
        const ValueKey<String>('duplicate-layer-button'),
      );

      expect(find.text('A'), findsWidgets);
      // Two drawing rows plus the always-present S1·S2/CAM 1/camera rows.
      expect(_timelineLayerRows(), findsNWidgets(6));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('timeline-selected-layer')),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('duplicated layer can be renamed and deleted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('duplicate-layer-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('rename-layer-button'),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-layer-text-field')),
      'Dup',
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('rename-layer-ok-button'),
    );

    expect(find.text('Dup'), findsWidgets);

    await _tapToolbarButton(
      tester,
      const ValueKey<String>('delete-layer-button'),
    );
    await _tapToolbarButton(
      tester,
      const ValueKey<String>('delete-layer-confirm-button'),
    );

    expect(find.text('Dup'), findsNothing);
  });
}
