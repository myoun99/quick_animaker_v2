import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/cut_list_helpers.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/cut/cut_list_bar.dart';

void main() {
  group('CutListBar', () {
    testWidgets('renders cut names', (tester) async {
      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(id: 'cut-1', name: 'Cut 1'),
              _entry(id: 'cut-2', name: 'Cut 2'),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('cut-list-bar')),
        findsOneWidget,
      );
      expect(find.text('Cuts:'), findsOneWidget);
      expect(find.text('Cut 1'), findsOneWidget);
      expect(find.text('Cut 2'), findsOneWidget);
    });

    testWidgets('visually marks the active cut', (tester) async {
      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(id: 'cut-1', name: 'Cut 1'),
              _entry(id: 'cut-2', name: 'Cut 2', isActive: true),
            ],
          ),
        ),
      );

      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey<String>('cut-list-bar'))),
      );
      final activeDecoration = _chipDecoration(tester, 'cut-2');
      final inactiveDecoration = _chipDecoration(tester, 'cut-1');
      final activeLabel = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cut-list-entry-label-cut-2')),
      );
      final inactiveLabel = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cut-list-entry-label-cut-1')),
      );

      expect(activeDecoration.color, theme.colorScheme.primaryContainer);
      expect(
        inactiveDecoration.color,
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(activeDecoration.border?.top.color, theme.colorScheme.primary);
      expect(
        inactiveDecoration.border?.top.color,
        theme.colorScheme.outlineVariant,
      );
      expect(activeLabel.style?.fontWeight, FontWeight.w700);
      expect(inactiveLabel.style?.fontWeight, FontWeight.w500);
      expect(activeDecoration.border?.top.width, 1.5);
      expect(inactiveDecoration.border?.top.width, 1);
      expect(
        find.byKey(const ValueKey<String>('cut-list-entry-active-dot-cut-2')),
        findsOneWidget,
      );
      expect(find.byTooltip('Active: Cut 2'), findsOneWidget);
      expect(find.byTooltip('Cut: Cut 1'), findsOneWidget);
    });

    testWidgets('renders compact command actions when callbacks are provided', (
      tester,
    ) async {
      var newCutCount = 0;
      var renameCutCount = 0;
      var duplicateCutCount = 0;
      var moveLeftCount = 0;
      var moveRightCount = 0;
      var deleteCutCount = 0;

      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [_entry(id: 'cut-1', name: 'Cut 1', isActive: true)],
            onNewCut: () => newCutCount += 1,
            onRenameActiveCut: () => renameCutCount += 1,
            onDuplicateActiveCut: () => duplicateCutCount += 1,
            onMoveActiveCutLeft: () => moveLeftCount += 1,
            onMoveActiveCutRight: () => moveRightCount += 1,
            onDeleteActiveCut: () => deleteCutCount += 1,
          ),
        ),
      );

      expect(find.byTooltip('New Cut'), findsOneWidget);
      expect(find.byTooltip('Rename Cut'), findsOneWidget);
      expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
      expect(find.byTooltip('Move Cut Left'), findsOneWidget);
      expect(find.byTooltip('Move Cut Right'), findsOneWidget);
      expect(find.byTooltip('Delete Cut'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('new-cut-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('rename-cut-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('duplicate-cut-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('move-cut-left-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('move-cut-right-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('delete-cut-button')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('new-cut-button')));
      await tester.tap(find.byKey(const ValueKey<String>('rename-cut-button')));
      await tester.tap(
        find.byKey(const ValueKey<String>('duplicate-cut-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('move-cut-left-button')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('move-cut-right-button')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('delete-cut-button')));

      expect(newCutCount, 1);
      expect(renameCutCount, 1);
      expect(duplicateCutCount, 1);
      expect(moveLeftCount, 1);
      expect(moveRightCount, 1);
      expect(deleteCutCount, 1);
    });

    testWidgets('keeps long cut labels compact', (tester) async {
      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(
                id: 'cut-1',
                name: 'A very long production cut name for layout hardening',
                isActive: true,
              ),
            ],
            onNewCut: () {},
            onRenameActiveCut: () {},
            onDuplicateActiveCut: () {},
            onDeleteActiveCut: () {},
          ),
        ),
      );

      final label = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cut-list-entry-label-cut-1')),
      );

      expect(label.overflow, TextOverflow.ellipsis);
      expect(label.softWrap, isFalse);
      expect(find.byTooltip('New Cut'), findsOneWidget);
      expect(find.byTooltip('Rename Cut'), findsOneWidget);
      expect(find.byTooltip('Duplicate Cut'), findsOneWidget);
      expect(find.byTooltip('Delete Cut'), findsOneWidget);
    });

    testWidgets('renders no cut controls for passive read-only display', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [_entry(id: 'cut-1', name: 'Cut 1')],
          ),
        ),
      );

      final cutListBar = find.byKey(const ValueKey<String>('cut-list-bar'));

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(InkWell), findsNothing);
      expect(
        find.descendant(of: cutListBar, matching: find.byType(GestureDetector)),
        findsNothing,
      );
    });

    testWidgets('calls onCutSelected with tapped cut id when provided', (
      tester,
    ) async {
      CutId? selectedCutId;

      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(id: 'cut-1', name: 'Cut 1'),
              _entry(id: 'cut-2', name: 'Cut 2'),
            ],
            onCutSelected: (cutId) => selectedCutId = cutId,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('cut-list-entry-cut-2')),
      );

      expect(selectedCutId, const CutId('cut-2'));
      expect(find.byType(InkWell), findsNWidgets(2));
      expect(find.byTooltip('Switch to Cut 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Switch to cut Cut 2'), findsOneWidget);
    });

    testWidgets('uses short active semantics label', (tester) async {
      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(id: 'cut-1', name: 'Cut 1', isActive: true),
              _entry(id: 'cut-2', name: 'Cut 2'),
            ],
            onCutSelected: (_) {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('Active cut Cut 1'), findsOneWidget);
      expect(find.byTooltip('Active: Cut 1'), findsOneWidget);
      expect(find.byTooltip('Switch to Cut 2'), findsOneWidget);
    });

    testWidgets('tapping inactive cut does not visually mark it active', (
      tester,
    ) async {
      CutId? selectedCutId;

      await tester.pumpWidget(
        _testApp(
          CutListBar(
            entries: [
              _entry(id: 'cut-1', name: 'Cut 1', isActive: true),
              _entry(id: 'cut-2', name: 'Cut 2'),
            ],
            onCutSelected: (cutId) => selectedCutId = cutId,
          ),
        ),
      );

      final theme = Theme.of(
        tester.element(find.byKey(const ValueKey<String>('cut-list-bar'))),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('cut-list-entry-cut-2')),
      );
      await tester.pump();

      final activeDecoration = _chipDecoration(tester, 'cut-1');
      final inactiveDecoration = _chipDecoration(tester, 'cut-2');
      final activeLabel = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cut-list-entry-label-cut-1')),
      );
      final inactiveLabel = tester.widget<Text>(
        find.byKey(const ValueKey<String>('cut-list-entry-label-cut-2')),
      );

      expect(selectedCutId, const CutId('cut-2'));
      expect(activeDecoration.color, theme.colorScheme.primaryContainer);
      expect(
        inactiveDecoration.color,
        theme.colorScheme.surfaceContainerHighest,
      );
      expect(activeLabel.style?.fontWeight, FontWeight.w700);
      expect(inactiveLabel.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('renders nothing when entries are empty', (tester) async {
      await tester.pumpWidget(_testApp(const CutListBar(entries: [])));

      expect(
        find.byKey(const ValueKey<String>('cut-list-bar-empty')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('cut-list-bar')), findsNothing);
      expect(find.text('Cuts:'), findsNothing);
    });
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

BoxDecoration _chipDecoration(WidgetTester tester, String cutId) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey<String>('cut-list-entry-$cutId')),
  );
  return container.decoration! as BoxDecoration;
}

CutListEntry _entry({
  required String id,
  required String name,
  bool isActive = false,
}) {
  return CutListEntry(
    trackId: const TrackId('track-1'),
    trackName: 'Video Track',
    trackIndex: 0,
    trackType: TrackType.video,
    cutId: CutId(id),
    cutName: name,
    cutIndex: 0,
    isActive: isActive,
  );
}
