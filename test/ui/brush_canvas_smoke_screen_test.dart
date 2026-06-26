import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_operation_kind.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_canvas_smoke_screen.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_canvas_smoke_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

void main() {
  group('BrushCanvasSmokeScreen', () {
    testWidgets('builds with stable keys and default configuration', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

      expect(find.byType(BrushCanvasSmokeScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-smoke-screen')),
        findsOneWidget,
      );
      expect(find.byType(InteractiveBrushCanvasSmokeHost), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('brush-canvas-smoke-screen-controls'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-smoke-screen-host')),
        findsOneWidget,
      );

      final host = tester.widget<InteractiveBrushCanvasSmokeHost>(
        find.byType(InteractiveBrushCanvasSmokeHost),
      );
      expect(host.layerId, const LayerId('smoke-layer'));
      expect(host.frameId, const FrameId('smoke-frame'));
      expect(host.inputSettings, const BrushEditCanvasInputSettings());
      expect(host.showTransparentBackground, isTrue);
      expect(
        host.initialSessionState.canvasState.currentSurface.canvasSize,
        CanvasSize(width: 64, height: 64),
      );
      expect(host.initialSessionState.canvasState.currentSurface.tileSize, 16);
    });

    testWidgets('passes custom canvas, tile, input, and background settings', (
      tester,
    ) async {
      const layerId = LayerId('custom-layer');
      const frameId = FrameId('custom-frame');
      const inputSettings = BrushEditCanvasInputSettings(color: 0xFFFF00FF);
      final canvasSize = CanvasSize(width: 8, height: 8);

      await tester.pumpWidget(
        _app(
          BrushCanvasSmokeScreen(
            layerId: layerId,
            frameId: frameId,
            inputSettings: inputSettings,
            canvasSize: canvasSize,
            tileSize: 2,
            showTransparentBackground: false,
          ),
        ),
      );

      final host = tester.widget<InteractiveBrushCanvasSmokeHost>(
        find.byType(InteractiveBrushCanvasSmokeHost),
      );
      expect(host.layerId, layerId);
      expect(host.frameId, frameId);
      expect(host.inputSettings, inputSettings);
      expect(host.showTransparentBackground, isFalse);
      expect(
        host.initialSessionState.canvasState.currentSurface.canvasSize,
        canvasSize,
      );
      expect(host.initialSessionState.canvasState.currentSurface.tileSize, 2);
    });

    testWidgets('debug status is shown by default and can be hidden', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

      expect(
        find.byKey(
          const ValueKey<String>('brush-canvas-smoke-screen-debug-status'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('operation: none'), findsOneWidget);
      expect(find.textContaining('cacheInvalidations: 0'), findsOneWidget);
      expect(find.textContaining('color: 0xFF000000'), findsOneWidget);

      await tester.pumpWidget(
        _app(const BrushCanvasSmokeScreen(showDebugStatus: false)),
      );

      expect(
        find.byKey(
          const ValueKey<String>('brush-canvas-smoke-screen-debug-status'),
        ),
        findsNothing,
      );
    });

    testWidgets('pointer down/up updates debug status and visible state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          BrushCanvasSmokeScreen(
            canvasSize: CanvasSize(width: 8, height: 8),
            tileSize: 2,
          ),
        ),
      );

      await _tapCanvas(tester, const Offset(1.5, 1.5));

      expect(
        find.textContaining(
          'operation: ${BrushEditSessionOperationKind.commit.name}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('cacheInvalidations: 1'), findsOneWidget);

      final view = tester.widget<InteractiveBrushEditCanvasView>(
        find.byType(InteractiveBrushEditCanvasView),
      );
      expect(view.sessionState.canvasState.currentSurface.tiles, isNotEmpty);
    });


    testWidgets('color presets update host settings and future strokes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          BrushCanvasSmokeScreen(
            canvasSize: CanvasSize(width: 8, height: 8),
            tileSize: 2,
          ),
        ),
      );

      expect(_host(tester).inputSettings.color, 0xFF000000);

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-color-red'),
      );
      expect(_host(tester).inputSettings.color, 0xFFFF0000);
      expect(find.textContaining('color: 0xFFFF0000'), findsOneWidget);

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-color-blue'),
      );
      expect(_host(tester).inputSettings.color, 0xFF0000FF);
      expect(find.textContaining('color: 0xFF0000FF'), findsOneWidget);

      await _tapCanvas(tester, const Offset(1.5, 1.5));
      final bluePixels = _view(tester)
          .sessionState
          .canvasState
          .currentSurface
          .tiles
          .values
          .single
          .pixels;

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-reset'),
      );
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-color-black'),
      );
      expect(_host(tester).inputSettings.color, 0xFF000000);
      await _tapCanvas(tester, const Offset(1.5, 1.5));

      final blackPixels = _view(tester)
          .sessionState
          .canvasState
          .currentSurface
          .tiles
          .values
          .single
          .pixels;
      expect(blackPixels, isNot(bluePixels));
    });

    testWidgets('undo, redo, and reset update visible state and debug status', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          BrushCanvasSmokeScreen(
            canvasSize: CanvasSize(width: 8, height: 8),
            tileSize: 2,
          ),
        ),
      );

      await _tapCanvas(tester, const Offset(1.5, 1.5));
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isNotEmpty,
      );

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-undo'),
      );
      expect(find.textContaining('operation: undo'), findsOneWidget);
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isEmpty,
      );

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-redo'),
      );
      expect(find.textContaining('operation: redo'), findsOneWidget);
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isNotEmpty,
      );

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-reset'),
      );
      expect(find.textContaining('operation: reset'), findsOneWidget);
      expect(find.textContaining('cacheInvalidations: 0'), findsOneWidget);
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isEmpty,
      );
    });

    testWidgets(
      'does not add GestureDetector outside interactive canvas path',
      (tester) async {
        await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

        final screenFinder = find.byType(BrushCanvasSmokeScreen);
        expect(
          find.descendant(
            of: screenFinder,
            matching: find.byType(GestureDetector),
          ),
          findsNothing,
        );
      },
    );

    test(
      'does not include forbidden state management or direct commit calls',
      () {
        final source = File(
          'lib/src/ui/canvas/brush_canvas_smoke_screen.dart',
        ).readAsStringSync();

        expect(source, isNot(contains('Provider')));
        expect(source, isNot(contains('Riverpod')));
        expect(source, isNot(contains('Bloc')));
        expect(source, isNot(contains('ChangeNotifier')));
        expect(source, isNot(contains('InheritedWidget')));
        expect(source, isNot(contains('commitBrushDabSequence')));
      },
    );

    testWidgets('does not affect StoryboardPanel or TimelinePanel', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

      expect(find.byType(StoryboardPanel), findsNothing);
      expect(find.byType(TimelinePanel), findsNothing);
    });
  });
}

Future<void> _tapCanvas(WidgetTester tester, Offset localOffset) async {
  final viewFinder = find.byType(InteractiveBrushEditCanvasView);
  final globalOffset = tester.getTopLeft(viewFinder) + localOffset;
  final gesture = await tester.startGesture(globalOffset, pointer: 1);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}

InteractiveBrushCanvasSmokeHost _host(WidgetTester tester) {
  return tester.widget<InteractiveBrushCanvasSmokeHost>(
    find.byType(InteractiveBrushCanvasSmokeHost),
  );
}

InteractiveBrushEditCanvasView _view(WidgetTester tester) {
  return tester.widget<InteractiveBrushEditCanvasView>(
    find.byType(InteractiveBrushEditCanvasView),
  );
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pump();
}
