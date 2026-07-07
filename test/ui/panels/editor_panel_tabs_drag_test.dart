import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_layout.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_tabs.dart';

/// Two draggable tab groups wired to one layout model, the way the
/// workspace docks are.
class _Harness extends StatelessWidget {
  const _Harness({required this.model});

  final EditorPanelLayoutModel model;

  static const Map<String, IconData> _icons = {
    'a': Icons.abc,
    'b': Icons.brush,
    'c': Icons.camera,
    'x': Icons.close,
    'y': Icons.face,
  };

  Widget _group(String groupId) {
    return EditorPanelTabs(
      groupId: groupId,
      tabs: [
        for (final id in model.tabsIn(groupId))
          EditorPanelTab(
            id: id,
            label: id.toUpperCase(),
            icon: _icons[id]!,
            builder: (context) => Text('content-$id'),
          ),
      ],
      activeTabId: model.activeTabIn(groupId)!,
      onTabSelected: (tabId) => model.selectTab(groupId, tabId),
      canAcceptTab: (data) =>
          model.canMoveTab(tabId: data.tabId, toGroupId: groupId),
      onTabMoved: (data, insertIndex) => model.moveTab(
        tabId: data.tabId,
        toGroupId: groupId,
        toIndex: insertIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: model,
          builder: (context, _) => Column(
            children: [
              SizedBox(height: 150, child: _group('one')),
              SizedBox(height: 150, child: _group('two')),
            ],
          ),
        ),
      ),
    );
  }
}

EditorPanelLayoutModel _twoGroups() => EditorPanelLayoutModel(
  groups: {
    'one': ['a', 'b', 'c'],
    'two': ['x', 'y'],
  },
);

Finder _tab(String id) => find.byKey(ValueKey<String>('panel-tab-$id'));

/// Drags a tab to [target] with a plain pointer drag (mouse semantics).
Future<void> _dragTab(WidgetTester tester, String id, Offset target) async {
  final gesture = await tester.startGesture(tester.getCenter(_tab(id)));
  await tester.pump(const Duration(milliseconds: 20));
  // Two hops so DragTarget onMove sees the final hover position.
  await gesture.moveTo(target + const Offset(0, -10));
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

/// A point on the left or right half of a tab button.
Offset _tabHalf(WidgetTester tester, String id, {required bool right}) {
  final center = tester.getCenter(_tab(id));
  final edgeX = right
      ? tester.getTopRight(_tab(id)).dx - 3
      : tester.getTopLeft(_tab(id)).dx + 3;
  return Offset(edgeX, center.dy);
}

void main() {
  testWidgets('dropping on a tab\'s right half inserts after it', (
    tester,
  ) async {
    final model = _twoGroups();
    await tester.pumpWidget(_Harness(model: model));

    await _dragTab(tester, 'a', _tabHalf(tester, 'c', right: true));

    expect(model.tabsIn('one'), ['b', 'c', 'a']);
  });

  testWidgets('dropping on a tab\'s left half inserts before it', (
    tester,
  ) async {
    final model = _twoGroups();
    await tester.pumpWidget(_Harness(model: model));

    await _dragTab(tester, 'c', _tabHalf(tester, 'a', right: false));

    expect(model.tabsIn('one'), ['c', 'a', 'b']);
  });

  testWidgets('dropping on the strip tail appends to that group', (
    tester,
  ) async {
    final model = _twoGroups();
    await tester.pumpWidget(_Harness(model: model));

    // Well to the right of the last tab of group two = its strip tail.
    final tail = tester.getCenter(_tab('y')) + const Offset(200, 0);
    await _dragTab(tester, 'a', tail);

    expect(model.tabsIn('one'), ['b', 'c']);
    expect(model.tabsIn('two'), ['x', 'y', 'a']);
    // A re-docked tab becomes active in its new group.
    expect(model.activeTabIn('two'), 'a');
    expect(find.text('content-a'), findsOneWidget);
  });

  testWidgets('cross-group drop on a tab half lands at that index', (
    tester,
  ) async {
    final model = _twoGroups();
    await tester.pumpWidget(_Harness(model: model));

    await _dragTab(tester, 'b', _tabHalf(tester, 'y', right: false));

    expect(model.tabsIn('one'), ['a', 'c']);
    expect(model.tabsIn('two'), ['x', 'b', 'y']);
  });

  testWidgets('a group\'s last tab refuses to leave', (tester) async {
    final model = EditorPanelLayoutModel(
      groups: {
        'one': ['a', 'b', 'c'],
        'two': ['x'],
      },
    );
    await tester.pumpWidget(_Harness(model: model));

    await _dragTab(tester, 'x', _tabHalf(tester, 'b', right: false));

    expect(model.tabsIn('one'), ['a', 'b', 'c']);
    expect(model.tabsIn('two'), ['x']);
  });

  testWidgets('plain taps still switch tabs on a draggable strip', (
    tester,
  ) async {
    final model = _twoGroups();
    await tester.pumpWidget(_Harness(model: model));
    expect(find.text('content-a'), findsOneWidget);

    await tester.tap(_tab('b'));
    await tester.pumpAndSettle();

    expect(model.activeTabIn('one'), 'b');
    expect(find.text('content-b'), findsOneWidget);
    expect(model.tabsIn('one'), ['a', 'b', 'c']);
  });
}
