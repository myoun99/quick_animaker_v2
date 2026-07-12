import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/panels/editor_panel_tabs.dart';

/// R10-②: keep-alive tabs stay mounted offstage across switches (instant
/// switch-back, state preserved); plain tabs unmount as before.
void main() {
  Widget host({
    required String activeTabId,
    required ValueChanged<String> onTabSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EditorPanelTabs(
          tabs: [
            EditorPanelTab(
              id: 'heavy',
              label: 'Heavy',
              icon: Icons.timeline,
              keepAlive: true,
              builder: (context) => const _CounterBox(key: ValueKey('heavy')),
            ),
            EditorPanelTab(
              id: 'light',
              label: 'Light',
              icon: Icons.palette,
              builder: (context) => const Text('light-content'),
            ),
          ],
          activeTabId: activeTabId,
          onTabSelected: onTabSelected,
        ),
      ),
    );
  }

  testWidgets('a keep-alive tab keeps its STATE across switches; a plain '
      'tab unmounts', (tester) async {
    var active = 'heavy';
    Future<void> pump() async {
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            activeTabId: active,
            onTabSelected: (id) => setState(() => active = id),
          ),
        ),
      );
      await tester.pump();
    }

    await pump();
    // Bump the heavy tab's local state.
    await tester.tap(find.byKey(const ValueKey('heavy')));
    await tester.pump();
    expect(find.text('count: 1'), findsOneWidget);

    // Switch away: the heavy subtree stays mounted (offstage, not
    // hittable), the light tab mounts fresh. Finders must opt INTO
    // offstage widgets to see it.
    await tester.tap(find.byKey(const ValueKey<String>('panel-tab-light')));
    await tester.pumpAndSettle();
    expect(find.text('light-content'), findsOneWidget);
    expect(find.text('count: 1', skipOffstage: false), findsOneWidget);
    expect(find.text('count: 1'), findsNothing);

    // Switch back: the state survived — no rebuild from scratch.
    await tester.tap(find.byKey(const ValueKey<String>('panel-tab-heavy')));
    await tester.pumpAndSettle();
    expect(find.text('count: 1'), findsOneWidget);

    // The plain tab unmounted when it lost the stage.
    expect(find.text('light-content', skipOffstage: false), findsNothing);
  });
}

class _CounterBox extends StatefulWidget {
  const _CounterBox({super.key});

  @override
  State<_CounterBox> createState() => _CounterBoxState();
}

class _CounterBoxState extends State<_CounterBox> {
  var _count = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _count += 1),
      child: ColoredBox(
        color: Colors.transparent,
        child: Center(child: Text('count: $_count')),
      ),
    );
  }
}
