import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_bitmap_materialization_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
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

    testWidgets('tap stroke commits source dabs', (
      tester,
    ) async {
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
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

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
              child: _view(
                _sessionState(),
                results.add,
              ),
            ),
          ),
        ),
      );

      await tapCanvas(tester, const Offset(1.5, 1.5));

      expect(results, hasLength(1));
      expect(results.single, hasLength(1));
    });

    testWidgets('pointer outside surface does not emit a result', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

      await tapCanvas(tester, const Offset(9, 9));

      expect(results, isEmpty);
    });

    testWidgets('pointer cancel does not emit a result', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

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
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

      tester.binding.handlePointerEvent(
        const PointerMoveEvent(position: Offset(1.5, 1.5)),
      );
      tester.binding.handlePointerEvent(
        const PointerUpEvent(position: Offset(1.5, 1.5)),
      );
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('second pointer is ignored while first pointer is active', (
      tester,
    ) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

      final first = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1.5, 1.5)),
        pointer: 1,
      );
      final second = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(2.5, 1.5)),
        pointer: 2,
      );
      await second.up();
      await first.up();
      await tester.pump();

      expect(results, hasLength(1));
    });

    testWidgets('callback is called at most once per stroke', (tester) async {
      final results = <List<BrushDab>>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), results.add)),
      );

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

      await tester.pumpWidget(
        _app(_view(sessionState, results.add)),
      );
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
      await tester.pumpWidget(
        _app(_view(_sessionState(), (_) {})),
      );

      expect(find.byType(StoryboardPanel), findsNothing);
      expect(find.byType(TimelinePanel), findsNothing);
    });
  });
}

BrushEditSessionState _sessionState() {
  return BrushEditSessionState(
    canvasState: CanvasSurfaceState(
      currentSurface: BitmapSurface(
        canvasSize: CanvasSize(width: 8, height: 8),
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
}) {
  return InteractiveBrushEditCanvasView(
    sessionState: sessionState,
    layerId: const LayerId('layer-a'),
    frameId: const FrameId('frame-a'),
    inputSettings: inputSettings,
    onSourceStrokeCommitted: onResult,
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
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
