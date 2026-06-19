import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_vertical_scrollbar_rail.dart';

void main() {
  const slotKey = ValueKey<String>('timeline-vertical-scrollbar-slot');
  const railKey = ValueKey<String>('timeline-vertical-scrollbar');
  const trackKey = ValueKey<String>('timeline-vertical-scrollbar-track');
  const thumbKey = ValueKey<String>('timeline-vertical-scrollbar-thumb');

  Future<void> pumpSlot(
    WidgetTester tester, {
    double width = 12,
    double height = 120,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: TimelineVerticalScrollbarSlot(width: width, height: height),
        ),
      ),
    );
  }

  Future<void> pumpRail(
    WidgetTester tester, {
    required ScrollController controller,
    double viewportHeight = 120,
    double contentHeight = 360,
    bool attachControllerToScrollable = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 12,
            height: viewportHeight,
            child: Stack(
              children: [
                if (attachControllerToScrollable)
                  SingleChildScrollView(
                    controller: controller,
                    child: SizedBox(width: 12, height: contentHeight),
                  ),
                TimelineVerticalScrollbarRail(
                  controller: controller,
                  viewportHeight: viewportHeight,
                  contentHeight: contentHeight,
                  width: 12,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Positioned thumbPositioned(WidgetTester tester) {
    return tester.widget<Positioned>(
      find.ancestor(of: find.byKey(thumbKey), matching: find.byType(Positioned)),
    );
  }

  testWidgets('slot stable key exists exactly once and preserves size', (
    tester,
  ) async {
    await pumpSlot(tester, width: 14, height: 96);

    expect(find.byKey(slotKey), findsOneWidget);
    expect(tester.getSize(find.byKey(slotKey)), const Size(14, 96));
  });

  testWidgets('rail stable key exists exactly once', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(tester, controller: controller);

    expect(find.byKey(railKey), findsOneWidget);
  });

  testWidgets('track and thumb keys exist exactly once', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(tester, controller: controller);

    expect(find.byKey(trackKey), findsOneWidget);
    expect(find.byKey(thumbKey), findsOneWidget);
  });

  testWidgets('thumb is visible when content is taller than viewport', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(
      tester,
      controller: controller,
      viewportHeight: 120,
      contentHeight: 360,
    );

    expect(find.byKey(thumbKey), findsOneWidget);
    expect(thumbPositioned(tester).height, greaterThan(0));
  });

  testWidgets('thumb height respects minimum height', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(
      tester,
      controller: controller,
      viewportHeight: 120,
      contentHeight: 2400,
    );

    expect(thumbPositioned(tester).height, 32);
  });

  testWidgets('thumb fills viewport when content does not exceed viewport', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(
      tester,
      controller: controller,
      viewportHeight: 120,
      contentHeight: 120,
    );

    expect(thumbPositioned(tester).height, 120);
  });

  testWidgets('track tap uses the provided external controller', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await pumpRail(
      tester,
      controller: controller,
      viewportHeight: 120,
      contentHeight: 360,
      attachControllerToScrollable: true,
    );

    expect(controller.hasClients, isTrue);
    expect(controller.offset, 0);

    await tester.tapAt(
      tester.getTopLeft(find.byKey(trackKey)) + const Offset(6, 100),
    );
    await tester.pump();

    expect(controller.offset, greaterThan(0));
  });
}
