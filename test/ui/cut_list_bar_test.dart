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
      expect(find.byTooltip('Active cut: Cut 2'), findsOneWidget);
      expect(find.byTooltip('Cut: Cut 1'), findsOneWidget);
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

      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byType(InkWell), findsNothing);
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
