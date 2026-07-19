import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_viewport_gesture_layer.dart';
import 'package:quick_animaker_v2/src/ui/input/app_input_settings.dart';

/// PEN-7b: the CONTROL-mode touch engine — finger-count slots, the
/// lock-then-modifier rule, snap constraints. Everything runs under the
/// control mode (the product default); the corpus baseline elsewhere is
/// untouched (this file opts in per test).
void main() {
  tearDown(() {
    AppInput.settings.value = AppInputSettings.testCorpusBaseline;
    AppInput.debugTouchOnlyFormFactorOverride = null;
  });

  Future<
    ({
      List<String> actions,
      List<CanvasViewport> viewports,
      List<(double, bool)> sizeDrags,
    })
  >
  pumpEngine(WidgetTester tester, {CanvasViewport? viewport}) async {
    // Opt INTO control mode (the corpus baseline pins draw): keep any
    // custom settings a test already applied.
    if (AppInput.settings.value.canvasTouchMode != CanvasTouchMode.control) {
      AppInput.settings.value = AppInput.settings.value.copyWith(
        canvasTouchMode: CanvasTouchMode.control,
      );
    }
    final actions = <String>[];
    final viewports = <CanvasViewport>[];
    final sizeDrags = <(double, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanvasViewportGestureLayer(
            viewport: viewport ?? CanvasViewport(),
            onViewportChanged: viewports.add,
            onInvokeAction: actions.add,
            onBrushSizeDragStart: () {},
            onBrushSizeDragUpdate: (delta, {required snap}) =>
                sizeDrags.add((delta, snap)),
            onBrushSizeDragEnd: () {},
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    return (actions: actions, viewports: viewports, sizeDrags: sizeDrags);
  }

  testWidgets('1-finger horizontal flip steps drawings; the late finger '
      'switches to ONE-FRAME steps (lock-then-modifier)', (tester) async {
    final probes = await pumpEngine(tester);

    final finger = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.touch,
    );
    // Cross the slop horizontally, then one full step right.
    await finger.moveBy(const Offset(30, 2));
    await finger.moveBy(const Offset(48, 0));
    await tester.pump();
    expect(probes.actions, contains('drawing-next'));

    // A LATE second finger = modifier, never a re-classification: the
    // gesture keeps flipping, but by single frames now.
    final modifier = await tester.startGesture(
      const Offset(400, 300),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    probes.actions.clear();
    await finger.moveBy(const Offset(96, 0));
    await tester.pump();
    expect(probes.actions, isNotEmpty);
    expect(probes.actions.toSet(), {'frame-next'});

    await modifier.up();
    await finger.up();
    await tester.pump();
  });

  testWidgets('1-finger vertical flip walks layers through the arrow '
      'arbitration ids', (tester) async {
    final probes = await pumpEngine(tester);

    final finger = await tester.startGesture(
      const Offset(200, 300),
      kind: PointerDeviceKind.touch,
    );
    await finger.moveBy(const Offset(2, -30));
    await finger.moveBy(const Offset(0, -48));
    await tester.pump();
    await finger.up();
    await tester.pump();

    expect(probes.actions, contains('selection-nudge-up'));
  });

  testWidgets('2-finger drag navigates (pan reaches the viewport); with '
      'rotation disabled the view never rotates', (tester) async {
    AppInput.settings.value = const AppInputSettings(
      touchTimelineScroll: false,
      navigationRotationEnabled: false,
    );
    final probes = await pumpEngine(tester);

    final first = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.touch,
    );
    final second = await tester.startGesture(
      const Offset(300, 200),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    // Move both fingers together (pan) with a strong relative twist.
    await first.moveBy(const Offset(40, 10));
    await second.moveBy(const Offset(40, 90));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(probes.viewports, isNotEmpty);
    for (final viewport in probes.viewports) {
      expect(viewport.rotationDegrees, 0);
    }
  });

  testWidgets('3-finger vertical drag reports brush size; the late finger '
      'flags SNAP', (tester) async {
    final probes = await pumpEngine(tester);

    final fingers = [
      await tester.startGesture(
        const Offset(200, 300),
        kind: PointerDeviceKind.touch,
      ),
      await tester.startGesture(
        const Offset(260, 300),
        kind: PointerDeviceKind.touch,
      ),
      await tester.startGesture(
        const Offset(320, 300),
        kind: PointerDeviceKind.touch,
      ),
    ];
    await tester.pump();
    for (final finger in fingers) {
      await finger.moveBy(const Offset(0, -30));
    }
    await tester.pump();
    expect(probes.sizeDrags, isNotEmpty);
    expect(probes.sizeDrags.last.$2, isFalse);
    expect(probes.sizeDrags.last.$1, greaterThan(0), reason: 'up = bigger');

    final modifier = await tester.startGesture(
      const Offset(500, 400),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    for (final finger in fingers) {
      await finger.moveBy(const Offset(0, -10));
    }
    await tester.pump();
    expect(probes.sizeDrags.last.$2, isTrue, reason: 'modifier = snap');

    await modifier.up();
    for (final finger in fingers) {
      await finger.up();
    }
    await tester.pump();
  });

  testWidgets('a STAGGERED second finger still forms the two-finger '
      'gesture (PEN-8 #3: pre-lock joins have no time window)', (tester) async {
    final probes = await pumpEngine(tester);

    final first = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.touch,
    );
    // The second finger lands WELL past any simultaneity window (the
    // tablet-reported miss: 살짝 어긋난 핀치가 안 먹히던 케이스).
    await tester.pump(const Duration(milliseconds: 400));
    final second = await tester.startGesture(
      const Offset(260, 200),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump();
    await first.moveBy(const Offset(-40, 0));
    await second.moveBy(const Offset(40, 0));
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(probes.actions, isEmpty, reason: 'no one-finger flip fired');
    expect(probes.viewports, isNotEmpty, reason: 'the pinch navigated');
    expect(probes.viewports.last.zoom, greaterThan(1));
  });

  testWidgets('slots are ASSIGNABLE: 1-finger set to navigate pans the '
      'viewport instead of flipping', (tester) async {
    AppInput.settings.value = const AppInputSettings(
      touchTimelineScroll: false,
      touchDragOneFinger: CanvasTouchDragAction.navigate,
    );
    final probes = await pumpEngine(tester);

    final finger = await tester.startGesture(
      const Offset(200, 200),
      kind: PointerDeviceKind.touch,
    );
    await finger.moveBy(const Offset(30, 0));
    await finger.moveBy(const Offset(60, 0));
    await tester.pump();
    await finger.up();
    await tester.pump();

    expect(probes.actions, isEmpty, reason: 'no flip on a navigate slot');
    expect(probes.viewports, isNotEmpty, reason: 'one-finger pan');
  });
}
