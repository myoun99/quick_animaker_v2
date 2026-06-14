import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_block.dart';

void main() {
  testWidgets('renders child content at the requested width', (tester) async {
    await _pumpBlock(
      tester,
      const TimelineBlock(
        width: 128,
        isActive: false,
        child: Text('Shared block content'),
      ),
    );

    expect(find.text('Shared block content'), findsOneWidget);
    expect(tester.getSize(find.byType(TimelineBlock)).width, 128);
  });

  testWidgets('calls tap callback', (tester) async {
    var taps = 0;

    await _pumpBlock(
      tester,
      TimelineBlock(
        width: 128,
        isActive: false,
        onTap: () => taps += 1,
        child: const Text('Tap target'),
      ),
    );

    await tester.tap(find.byType(TimelineBlock));
    await tester.pumpAndSettle();

    expect(taps, 1);
  });

  testWidgets('uses a different decoration for active state', (tester) async {
    await _pumpBlock(
      tester,
      const Column(
        children: [
          TimelineBlock(
            key: ValueKey<String>('inactive-block'),
            width: 128,
            isActive: false,
            child: Text('Inactive'),
          ),
          TimelineBlock(
            key: ValueKey<String>('active-block'),
            width: 128,
            isActive: true,
            child: Text('Active'),
          ),
        ],
      ),
    );

    final inactive = _decorationFor(tester, 'inactive-block');
    final active = _decorationFor(tester, 'active-block');

    expect(active.color, isNot(inactive.color));
    expect(active.border, isNot(inactive.border));
  });
}

Future<void> _pumpBlock(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

BoxDecoration _decorationFor(WidgetTester tester, String key) {
  final containerFinder = find.descendant(
    of: find.byKey(ValueKey<String>(key)),
    matching: find.byType(Container),
  );
  final container = tester.widget<Container>(containerFinder);
  return container.decoration! as BoxDecoration;
}
