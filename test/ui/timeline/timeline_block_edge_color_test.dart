import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_block.dart';

/// R26 #8: the cut block's resting edge follows the background's
/// brightness (light edge on dark lanes, dark edge on light lanes), a
/// hover brightens it, and the ACTIVE accent edge stays untouched.
void main() {
  Widget harness({required Brightness brightness, required bool isActive}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: TimelineBlock(
            width: 120,
            isActive: isActive,
            onTap: () {},
            child: const SizedBox(height: 40),
          ),
        ),
      ),
    );
  }

  Color borderColorOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(TimelineBlock),
        matching: find.byType(Container),
      ),
    );
    final decoration = container.decoration! as BoxDecoration;
    return decoration.border!.top.color;
  }

  testWidgets('the resting edge differs by theme brightness', (tester) async {
    await tester.pumpWidget(
      harness(brightness: Brightness.dark, isActive: false),
    );
    final darkScheme = ThemeData(brightness: Brightness.dark).colorScheme;
    expect(
      borderColorOf(tester),
      timelineBlockRestingEdgeColor(darkScheme, Brightness.dark),
    );

    await tester.pumpWidget(
      harness(brightness: Brightness.light, isActive: false),
    );
    // MaterialApp animates theme changes; settle before reading colors.
    await tester.pumpAndSettle();
    final lightScheme = ThemeData(brightness: Brightness.light).colorScheme;
    expect(
      borderColorOf(tester),
      timelineBlockRestingEdgeColor(lightScheme, Brightness.light),
    );
    expect(
      timelineBlockRestingEdgeColor(darkScheme, Brightness.dark),
      isNot(timelineBlockRestingEdgeColor(lightScheme, Brightness.light)),
      reason: 'one grey for both backgrounds was exactly the complaint',
    );
  });

  testWidgets('a hover brightens the resting edge', (tester) async {
    await tester.pumpWidget(
      harness(brightness: Brightness.dark, isActive: false),
    );
    final scheme = ThemeData(brightness: Brightness.dark).colorScheme;

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(TimelineBlock)));
    await tester.pump();

    expect(borderColorOf(tester), timelineBlockHoverEdgeColor(scheme));

    await gesture.moveTo(Offset.zero);
    await tester.pump();
    expect(
      borderColorOf(tester),
      timelineBlockRestingEdgeColor(scheme, Brightness.dark),
    );
  });

  testWidgets('the active accent edge stays exactly as it was', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(brightness: Brightness.dark, isActive: true),
    );
    final scheme = ThemeData(brightness: Brightness.dark).colorScheme;
    expect(borderColorOf(tester), scheme.primary);

    // Hovering an active block must not override the accent.
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(TimelineBlock)));
    await tester.pump();
    expect(borderColorOf(tester), scheme.primary);
  });
}
