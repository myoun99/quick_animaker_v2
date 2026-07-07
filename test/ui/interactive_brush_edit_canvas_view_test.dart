import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_bitmap_materialization_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

import 'brush_canvas_test_helpers.dart';

void main() {
  group('InteractiveBrushEditCanvasView', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    testWidgets(
      'builds Listener and BrushEditCanvasView without GestureDetector',
      (tester) async {
        final sessionState = _sessionState();
        await tester.pumpWidget(
          _app(
            InteractiveBrushEditCanvasView(
              sessionState: sessionState,
              layerId: layerId,
              frameId: frameId,
              inputSettings: const BrushEditCanvasInputSettings(),
              onSourceStrokeCommitted: (_) {},
              showTransparentBackground: false,
            ),
          ),
        );

        final viewFinder = find.byType(InteractiveBrushEditCanvasView);
        expect(viewFinder, findsOneWidget);
        expect(
          find.descendant(
            of: viewFinder,
            matching: find.byKey(
              const ValueKey<String>(
                'interactive-brush-edit-canvas-view-listener',
              ),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: viewFinder,
            matching: find.byType(BrushEditCanvasView),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: viewFinder,
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
        );

        final canvasView = tester.widget<BrushEditCanvasView>(
          find.descendant(
            of: viewFinder,
            matching: find.byType(BrushEditCanvasView),
          ),
        );
        expect(identical(canvasView.sessionState, sessionState), isTrue);
        expect(canvasView.showTransparentBackground, isFalse);
      },
    );

    testWidgets('pointer down does not throw', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1.5, 1.5)),
        pointer: 1,
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('pointer move does not throw', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1.5, 1.5)),
        pointer: 1,
      );
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(3.5, 1.5)));
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(results, hasLength(1));
    });

    testWidgets('tap stroke commits source dabs', (tester) async {
      final sessionState = _sessionState();
      final results = <List<BrushDab>>[];

      await tester.pumpWidget(_app(_view(sessionState, results.add)));
      await tapCanvas(tester, const Offset(1.5, 1.5));

      expect(results, hasLength(1));
      expect(results.single, hasLength(1));
      expect(identical(sessionState, sessionState), isTrue);
    });

    testWidgets('drag commit creates exactly one operation result', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      await dragCanvas(tester, const [
        Offset(1.5, 1.5),
        Offset(2.5, 1.5),
        Offset(3.5, 2.5),
      ]);

      expect(results, hasLength(1));
      final sequences = results.single.map((dab) => dab.sequence).toList();
      expect(results.single, isNotEmpty);
      expect(sequences, everyElement(greaterThanOrEqualTo(0)));
      expect(_isStrictlyIncreasing(sequences), isTrue);
    });

    testWidgets('fast drag commits sampled source dabs beyond raw endpoints', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(),
            results.add,
            inputSettings: const BrushEditCanvasInputSettings(size: 8),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1, 1)),
        pointer: 1,
      );
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(7, 1)));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));
      final sequences = results.single.map((dab) => dab.sequence).toList();
      expect(results.single.length, greaterThan(2));
      expect(sequences, everyElement(greaterThanOrEqualTo(0)));
      expect(_isStrictlyIncreasing(sequences), isTrue);
    });

    testWidgets('tiny movement does not create duplicate sampled source dabs', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(),
            results.add,
            inputSettings: const BrushEditCanvasInputSettings(size: 8),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1, 1)),
        pointer: 1,
      );
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(1.5, 1)));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single, hasLength(1));
      expect(results.single.single.sequence, 0);
    });

    testWidgets('pointer down shows active overlay before movement', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1, 1)),
        pointer: 1,
      );
      await tester.pump();

      final canvasView = tester.widget<BrushEditCanvasView>(
        find.byType(BrushEditCanvasView),
      );
      expect(canvasView.overlayModel!.dabs, isNotEmpty);
      expect(results, isEmpty);

      await gesture.cancel();
    });

    testWidgets(
      'drag stroke keeps continuous active path before commit and clears after commit',
      (tester) async {
        final results = <List<BrushDab>>[];
        await tester.pumpWidget(
          _app(
            _view(
              _sessionState(),
              results.add,
              inputSettings: const BrushEditCanvasInputSettings(size: 4),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          canvasGlobalOffset(tester, const Offset(1, 1)),
          pointer: 1,
        );
        await gesture.moveTo(canvasGlobalOffset(tester, const Offset(5, 1)));
        await tester.pump();

        var canvasView = tester.widget<BrushEditCanvasView>(
          find.byType(BrushEditCanvasView),
        );
        expect(canvasView.overlayModel!.dabs, isNotEmpty);
        expect(results, isEmpty);

        await gesture.up();
        await tester.pump();

        canvasView = tester.widget<BrushEditCanvasView>(
          find.byType(BrushEditCanvasView),
        );
        expect(results, hasLength(1));
        // The overlay settles (stays visible) until the committed tiles
        // decode or the settling window elapses, so the stroke never flashes
        // away during the handoff to the materialized bitmap.
        expect(canvasView.overlayModel!.dabs, isNotEmpty);

        await tester.pump(const Duration(milliseconds: 350));
        canvasView = tester.widget<BrushEditCanvasView>(
          find.byType(BrushEditCanvasView),
        );
        expect(canvasView.overlayModel!.dabs, isEmpty);
      },
    );

    testWidgets(
      'fast drag keeps active display bounded while committing full source stroke',
      (tester) async {
        final results = <List<BrushDab>>[];
        await tester.pumpWidget(
          _app(
            _view(
              _sessionState(),
              results.add,
              inputSettings: const BrushEditCanvasInputSettings(size: 1),
            ),
          ),
        );

        final gesture = await tester.startGesture(
          canvasGlobalOffset(tester, const Offset(1, 1)),
          pointer: 1,
        );
        await gesture.moveTo(canvasGlobalOffset(tester, const Offset(7, 1)));
        await tester.pump();

        var canvasView = tester.widget<BrushEditCanvasView>(
          find.byType(BrushEditCanvasView),
        );
        expect(canvasView.overlayModel!.dabs, isNotEmpty);
        expect(canvasView.overlayModel!.dabs.length, greaterThan(2));
        expect(canvasView.overlayModel!.dabs.last.center.x, 7);
        expect(results, isEmpty);

        await gesture.up();
        // Let the settling window elapse before checking the cleared state.
        await tester.pump(const Duration(milliseconds: 350));

        canvasView = tester.widget<BrushEditCanvasView>(
          find.byType(BrushEditCanvasView),
        );
        expect(canvasView.overlayModel!.dabs, isEmpty);
        expect(results, hasLength(1));
        expect(results.single.length, greaterThan(2));
      },
    );

    testWidgets('repeated tap strokes produce repeated operation results', (
      tester,
    ) async {
      var sessionState = _sessionState();
      final results = <List<BrushDab>>[];

      await tester.pumpWidget(
        _app(
          _view(sessionState, (result) {
            results.add(result);
          }),
        ),
      );
      await tapCanvas(tester, const Offset(1.5, 1.5));
      await tester.pumpWidget(
        _app(
          _view(sessionState, (result) {
            results.add(result);
          }),
        ),
      );
      await tapCanvas(tester, const Offset(2.5, 1.5));

      expect(results, hasLength(2));
      expect(results.map((result) => result.length), [1, 1]);
    });

    testWidgets('coordinates are interpreted relative to the canvas view', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 48, left: 24),
              child: _view(_sessionState(), results.add),
            ),
          ),
        ),
      );

      await tapCanvas(tester, const Offset(1.5, 1.5));

      expect(results, hasLength(1));
      expect(results.single, hasLength(1));
    });

    testWidgets(
      'viewport transform keeps committed dabs in canvas coordinates',
      (tester) async {
        final results = <List<BrushDab>>[];
        await tester.pumpWidget(
          _app(
            _view(
              _sessionState(),
              results.add,
              viewport: CanvasViewport(zoom: 2),
            ),
          ),
        );

        await tapCanvas(tester, const Offset(3, 3));

        expect(results, hasLength(1));
        expect(results.single.single.center.x, 1.5);
        expect(results.single.single.center.y, 1.5);
      },
    );

    testWidgets(
      'viewport pan and zoom keep committed dabs in canvas coordinates',
      (tester) async {
        final results = <List<BrushDab>>[];
        await tester.pumpWidget(
          _app(
            _view(
              _sessionState(),
              results.add,
              viewport: CanvasViewport(zoom: 2, panX: 4, panY: 6),
            ),
          ),
        );

        await tapCanvas(tester, const Offset(7, 9));

        expect(results, hasLength(1));
        expect(results.single.single.center.x, 1.5);
        expect(results.single.single.center.y, 1.5);
      },
    );

    testWidgets('second touch finger cancels the stroke without committing', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final firstFinger = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await firstFinger.down(canvasGlobalOffset(tester, const Offset(1, 1)));
      await firstFinger.moveTo(canvasGlobalOffset(tester, const Offset(3, 3)));

      final secondFinger = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await secondFinger.down(canvasGlobalOffset(tester, const Offset(6, 6)));

      // Finger 1 keeps moving as part of the pinch — it must not draw.
      await firstFinger.moveTo(canvasGlobalOffset(tester, const Offset(5, 5)));
      await firstFinger.up();
      await secondFinger.up();
      await tester.pump();

      expect(results, isEmpty);

      // With every finger lifted, a single-finger stroke works again.
      final thirdFinger = await tester.createGesture(
        kind: PointerDeviceKind.touch,
      );
      await thirdFinger.down(canvasGlobalOffset(tester, const Offset(2, 2)));
      await thirdFinger.up();
      await tester.pump();

      expect(results, hasLength(1));
    });

    testWidgets('single-finger touch stroke still commits', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final finger = await tester.createGesture(kind: PointerDeviceKind.touch);
      await finger.down(canvasGlobalOffset(tester, const Offset(1, 1)));
      await finger.moveTo(canvasGlobalOffset(tester, const Offset(4, 4)));
      await finger.up();
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single, isNotEmpty);
    });

    testWidgets('middle mouse drag never commits dabs', (tester) async {
      // Viewport panning itself moved to the panel's
      // CanvasViewportGestureLayer; the view must simply not draw from a
      // middle-button drag.
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.down(canvasGlobalOffset(tester, const Offset(1, 1)));
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(4, 6)));
      await gesture.up();
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('pointer outside surface does not emit a result', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      await tapCanvas(tester, const Offset(9, 9));

      expect(results, isEmpty);
    });

    testWidgets('clips the drawing canvas display to the viewport', (
      tester,
    ) async {
      // The Cut-canvas-rect clipping now happens inside the composite
      // painter (canvas.clipRect in canvas space); the widget tree clips
      // the whole editor display to the viewport bounds.
      await tester.pumpWidget(_app(_view(_sessionState(), (_) {})));

      final clipFinder = find.byKey(
        const ValueKey<String>('interactive-brush-edit-canvas-clip'),
      );

      expect(clipFinder, findsOneWidget);
      expect(
        find.descendant(
          of: clipFinder,
          matching: find.byType(BrushEditCanvasView),
        ),
        findsOneWidget,
      );
    });

    testWidgets('pointer down outside then entering commits in-canvas dabs', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 32,
            height: 32,
            child: _view(_sessionState(), results.add),
          ),
        ),
      );

      final origin = tester.getTopLeft(
        find.byType(InteractiveBrushEditCanvasView),
      );
      final gesture = await tester.startGesture(
        origin + const Offset(12, 1),
        pointer: 1,
      );
      await tester.pump();
      await gesture.moveTo(origin + const Offset(2, 1));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));

      final dabs = results.single;
      expect(dabs.map((dab) => dab.center.x).toList(), [8, 7, 6, 5, 4, 3, 2]);
      expect(dabs.map((dab) => dab.center.y).toSet(), {1});
    });

    testWidgets('pointer down outside and staying outside commits nothing', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 32,
            height: 32,
            child: _view(_sessionState(), results.add),
          ),
        ),
      );

      final origin = tester.getTopLeft(
        find.byType(InteractiveBrushEditCanvasView),
      );
      final gesture = await tester.startGesture(
        origin + const Offset(12, 1),
        pointer: 1,
      );
      await gesture.moveTo(origin + const Offset(14, 1));
      await gesture.up();
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('leaving and re-entering does not connect across outside gap', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 32,
            height: 32,
            child: _view(_sessionState(), results.add),
          ),
        ),
      );

      final origin = tester.getTopLeft(
        find.byType(InteractiveBrushEditCanvasView),
      );
      final gesture = await tester.startGesture(
        origin + const Offset(1, 1),
        pointer: 1,
      );
      await gesture.moveTo(origin + const Offset(3, 1));
      await gesture.moveTo(origin + const Offset(12, 1));
      await tester.pump();
      expect(results, isEmpty);

      await gesture.moveTo(origin + const Offset(6, 1));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));

      final xs = results.single.map((dab) => dab.center.x).toList();

      expect(xs, containsAll([1, 2, 3, 4, 5, 6, 7, 8]));
      expect(xs, isNot(contains(9)));
      expect(xs, isNot(contains(10)));
      expect(xs, isNot(contains(11)));
      expect(xs, isNot(contains(12)));
      expect(xs.last, 6);
    });

    testWidgets('active stroke snapshots input settings until pointer up', (
      tester,
    ) async {
      final sessionState = _sessionState(width: 200, height: 32);
      final results = <List<BrushDab>>[];
      const initialSettings = BrushEditCanvasInputSettings(
        color: 0xFFE53935,
        size: 20,
        spacing: 0.25,
      );
      const rebuiltSettings = BrushEditCanvasInputSettings(
        color: 0xFF1E88E5,
        size: 20,
        spacing: 4.0,
      );

      await tester.pumpWidget(
        _app(_view(sessionState, results.add, inputSettings: initialSettings)),
      );

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1, 1)),
        pointer: 1,
      );
      await tester.pump();

      await tester.pumpWidget(
        _app(_view(sessionState, results.add, inputSettings: rebuiltSettings)),
      );
      await tester.pump();

      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(101, 1)));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single, hasLength(greaterThan(10)));
      expect(results.single.map((dab) => dab.color).toSet(), {0xFFE53935});
      expect(results.single.map((dab) => dab.size).toSet(), {20});
    });

    testWidgets('pen pressure scales committed dab size when enabled', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(width: 200, height: 16),
            results.add,
            inputSettings: const BrushEditCanvasInputSettings(
              size: 8,
              pressureSize: true,
            ),
          ),
        ),
      );

      await _pressureStroke(
        tester,
        canvasPoints: const [Offset(2, 1), Offset(40, 1)],
        pressure: 0.5,
      );

      expect(results, hasLength(1));
      // Constant 0.5 pressure with pressureSize on halves every dab's size.
      for (final dab in results.single) {
        expect(dab.size, closeTo(4.0, 1e-6));
      }
    });

    testWidgets(
      'mouse strokes paint at full pressure even with the size toggle on',
      (tester) async {
        // Regression: a mouse claims a 0..1 pressure range on some platforms
        // while always reporting pressure 0.0, which scaled every dab to
        // size zero — enabling pen pressure made the mouse stop drawing.
        final results = <List<BrushDab>>[];
        await tester.pumpWidget(
          _app(
            _view(
              _sessionState(width: 200, height: 16),
              results.add,
              inputSettings: const BrushEditCanvasInputSettings(
                size: 8,
                pressureSize: true,
                pressureOpacity: true,
              ),
            ),
          ),
        );

        await _pressureStroke(
          tester,
          canvasPoints: const [Offset(2, 1), Offset(40, 1)],
          pressure: 0.0,
          kind: PointerDeviceKind.mouse,
        );

        expect(results, hasLength(1));
        expect(results.single.map((dab) => dab.size).toSet(), {8.0});
        expect(results.single.map((dab) => dab.opacity).toSet(), {1.0});
      },
    );

    testWidgets('pen pressure is ignored when the size toggle is off', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(width: 200, height: 16),
            results.add,
            // pressureSize defaults off: pressure must not change the size.
            inputSettings: const BrushEditCanvasInputSettings(size: 8),
          ),
        ),
      );

      await _pressureStroke(
        tester,
        canvasPoints: const [Offset(2, 1), Offset(40, 1)],
        pressure: 0.5,
      );

      expect(results, hasLength(1));
      expect(results.single.map((dab) => dab.size).toSet(), {8.0});
    });

    testWidgets('pen pressure ramps dab size across a stroke', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(width: 200, height: 16),
            results.add,
            inputSettings: const BrushEditCanvasInputSettings(
              size: 8,
              pressureSize: true,
            ),
          ),
        ),
      );

      // Pen-down at full pressure, drag to a light-pressure sample: size
      // should decrease monotonically along the interpolated stroke.
      await _pressureStroke(
        tester,
        canvasPoints: const [Offset(2, 1), Offset(120, 1)],
        pressure: 0.25,
        downPressure: 1.0,
      );

      expect(results, hasLength(1));
      final sizes = results.single.map((dab) => dab.size).toList();
      expect(sizes.length, greaterThan(3));
      expect(sizes.first, greaterThan(sizes.last));
      expect(sizes.first, closeTo(8.0, 1e-6));
      // Every dab stays within the base size envelope.
      expect(sizes, everyElement(lessThanOrEqualTo(8.0 + 1e-6)));
      expect(sizes, everyElement(greaterThanOrEqualTo(0.0)));
    });

    testWidgets('pointer cancel does not emit a result', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1.5, 1.5)),
        pointer: 1,
      );
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('pointer move without pointer down does not emit a result', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      tester.binding.handlePointerEvent(
        const PointerMoveEvent(position: Offset(1.5, 1.5)),
      );
      tester.binding.handlePointerEvent(
        const PointerUpEvent(position: Offset(1.5, 1.5)),
      );
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('eraser input settings stamp erase dabs', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(
          _view(
            _sessionState(),
            results.add,
            inputSettings: const BrushEditCanvasInputSettings(erase: true),
          ),
        ),
      );

      await tapCanvas(tester, const Offset(3, 3));

      expect(results, hasLength(1));
      expect(results.single.every((dab) => dab.erase), isTrue);
    });

    testWidgets('stray touches never cancel a stylus stroke (palm rest)', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final stylus = await tester.createGesture(kind: PointerDeviceKind.stylus);
      await stylus.down(canvasGlobalOffset(tester, const Offset(1.5, 1.5)));

      // Two palm contacts land while the stylus draws — only a TOUCH
      // stroke turns into a pinch; the stylus stroke must survive.
      final palmA = await tester.createGesture(kind: PointerDeviceKind.touch);
      final palmB = await tester.createGesture(kind: PointerDeviceKind.touch);
      await palmA.down(canvasGlobalOffset(tester, const Offset(6, 6)));
      await palmB.down(canvasGlobalOffset(tester, const Offset(7, 7)));

      await stylus.moveTo(canvasGlobalOffset(tester, const Offset(3, 3)));
      await stylus.up();
      await palmA.up();
      await palmB.up();
      await tester.pump();

      expect(results, hasLength(1));
      expect(results.single, isNotEmpty);
    });

    testWidgets('callback is called at most once per stroke', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(_app(_view(_sessionState(), results.add)));

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1.5, 1.5)),
        pointer: 1,
      );
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(2.5, 1.5)));
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(20, 20)));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));
    });

    testWidgets('does not mutate input states', (tester) async {
      final sessionState = _sessionState();
      final originalCanvasState = sessionState.canvasState;
      final originalHistoryState = sessionState.materializationHistoryState;
      final originalSessionSnapshot = sessionState.toString();
      final originalCanvasSnapshot = originalCanvasState.toString();
      final originalHistorySnapshot = originalHistoryState.toString();
      final results = <List<BrushDab>>[];

      await tester.pumpWidget(_app(_view(sessionState, results.add)));
      await tapCanvas(tester, const Offset(1.5, 1.5));

      expect(identical(sessionState.canvasState, originalCanvasState), isTrue);
      expect(
        identical(
          sessionState.materializationHistoryState,
          originalHistoryState,
        ),
        isTrue,
      );
      expect(sessionState.toString(), originalSessionSnapshot);
      expect(originalCanvasState.toString(), originalCanvasSnapshot);
      expect(originalHistoryState.toString(), originalHistorySnapshot);
    });

    test(
      'does not execute undo or redo and does not add forbidden state management',
      () {
        final source = _readInteractiveSource();

        expect(source, isNot(contains('undoLatestBrushBitmapMaterialization')));
        expect(source, isNot(contains('redoLatestBrushBitmapMaterialization')));
        expect(source, isNot(contains('Provider')));
        expect(source, isNot(contains('Riverpod')));
        expect(source, isNot(contains('Bloc')));
        expect(source, isNot(contains('ChangeNotifier')));
      },
    );

    testWidgets('does not affect StoryboardPanel or TimelinePanel', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_view(_sessionState(), (_) {})));

      expect(find.byType(StoryboardPanel), findsNothing);
      expect(find.byType(TimelinePanel), findsNothing);
    });
  });
}

BrushEditSessionState _sessionState({int width = 8, int height = 8}) {
  return BrushEditSessionState(
    canvasState: CanvasSurfaceState(
      currentSurface: BitmapSurface(
        canvasSize: CanvasSize(width: width, height: height),
        tileSize: 2,
      ),
    ),
    materializationHistoryState: BrushBitmapMaterializationHistoryState(),
  );
}

InteractiveBrushEditCanvasView _view(
  BrushEditSessionState sessionState,
  ValueChanged<List<BrushDab>> onResult, {
  BrushEditCanvasInputSettings inputSettings =
      const BrushEditCanvasInputSettings(),
  CanvasViewport? viewport,
}) {
  return InteractiveBrushEditCanvasView(
    sessionState: sessionState,
    layerId: const LayerId('layer-a'),
    frameId: const FrameId('frame-a'),
    inputSettings: inputSettings,
    viewport: viewport,
    // Tests observe the committed source dabs; the exact pre-rasterized
    // stroke pixels travel alongside them in the commit data.
    onSourceStrokeCommitted: (strokeData) => onResult(strokeData.sourceDabs),
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

/// Drives a stroke through raw pointer events carrying a specific pressure
/// (test gestures cannot set pressure). [downPressure] defaults to
/// [pressure] so a flat-pressure stroke needs only one value. Defaults to a
/// stylus: only stylus devices are trusted for pressure — a mouse claims a
/// 0..1 pressure range on some platforms while always reporting 0.0.
Future<void> _pressureStroke(
  WidgetTester tester, {
  required List<Offset> canvasPoints,
  required double pressure,
  double? downPressure,
  int pointer = 1,
  PointerDeviceKind kind = PointerDeviceKind.stylus,
}) async {
  final globals = [
    for (final point in canvasPoints) canvasGlobalOffset(tester, point),
  ];
  tester.binding.handlePointerEvent(
    PointerDownEvent(
      pointer: pointer,
      kind: kind,
      position: globals.first,
      pressure: downPressure ?? pressure,
      pressureMin: 0,
      pressureMax: 1,
    ),
  );
  await tester.pump();
  for (final global in globals.skip(1)) {
    tester.binding.handlePointerEvent(
      PointerMoveEvent(
        pointer: pointer,
        kind: kind,
        position: global,
        pressure: pressure,
        pressureMin: 0,
        pressureMax: 1,
      ),
    );
    await tester.pump();
  }
  tester.binding.handlePointerEvent(
    PointerUpEvent(
      pointer: pointer,
      kind: kind,
      position: globals.last,
      pressure: 0,
      pressureMin: 0,
      pressureMax: 1,
    ),
  );
  await tester.pump();
}

String _readInteractiveSource() {
  return File(
    'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
  ).readAsStringSync();
}

bool _isStrictlyIncreasing(Iterable<int> values) {
  int? previous;
  for (final value in values) {
    if (previous != null && value <= previous) {
      return false;
    }
    previous = value;
  }
  return true;
}
