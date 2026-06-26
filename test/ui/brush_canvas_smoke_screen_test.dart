import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_operation_kind.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_canvas_smoke_screen.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_canvas_smoke_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

import 'brush_canvas_test_helpers.dart';

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

      await tapCanvas(tester, const Offset(1.5, 1.5));

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

      await tapCanvas(tester, const Offset(1.5, 1.5));
      final bluePixels = _view(
        tester,
      ).sessionState.canvasState.currentSurface.tiles.values.single.pixels;

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-reset'),
      );
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-color-black'),
      );
      expect(_host(tester).inputSettings.color, 0xFF000000);
      await tapCanvas(tester, const Offset(1.5, 1.5));

      final blackPixels = _view(
        tester,
      ).sessionState.canvasState.currentSurface.tiles.values.single.pixels;
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

      await tapCanvas(tester, const Offset(1.5, 1.5));
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

    testWidgets('two strokes followed by undo removes only latest stroke', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_smallScreen()));

      await tapCanvas(tester, const Offset(1.5, 1.5));
      await tapCanvas(tester, const Offset(3.5, 2.5));
      expect(_view(tester).sessionState.historyState.undoEntries, hasLength(2));

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-undo'),
      );

      expect(find.textContaining('operation: undo'), findsOneWidget);
      expect(_view(tester).sessionState.historyState.undoEntries, hasLength(1));
      expect(_view(tester).sessionState.historyState.redoEntries, hasLength(1));
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isNotEmpty,
      );
    });

    testWidgets('redo restores the latest undone stroke', (tester) async {
      await tester.pumpWidget(_app(_smallScreen()));

      await tapCanvas(tester, const Offset(1.5, 1.5));
      await tapCanvas(tester, const Offset(3.5, 2.5));
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-undo'),
      );
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-redo'),
      );

      expect(find.textContaining('operation: redo'), findsOneWidget);
      expect(_view(tester).sessionState.historyState.undoEntries, hasLength(2));
      expect(_view(tester).sessionState.historyState.redoEntries, isEmpty);
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isNotEmpty,
      );
    });

    testWidgets('reset clears canvas and prevents stale redo restore', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_smallScreen()));

      await tapCanvas(tester, const Offset(1.5, 1.5));
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-undo'),
      );
      expect(_view(tester).sessionState.historyState.redoEntries, hasLength(1));
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-reset'),
      );
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-redo'),
      );

      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isEmpty,
      );
      expect(_view(tester).sessionState.historyState.redoEntries, isEmpty);
      expect(find.textContaining('operation: redo'), findsOneWidget);
    });

    testWidgets('blank undo and redo do not crash or change visible state', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_smallScreen()));

      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-undo'),
      );
      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isEmpty,
      );
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-redo'),
      );

      expect(
        _view(tester).sessionState.canvasState.currentSurface.tiles,
        isEmpty,
      );
      expect(find.textContaining('operation: redo'), findsOneWidget);
    });

    testWidgets('color change affects future stroke without erasing existing strokes', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_smallScreen()));

      await tapCanvas(tester, const Offset(1.5, 1.5));
      final blackState = _view(tester).sessionState;
      await _tapKey(
        tester,
        const ValueKey<String>('brush-canvas-smoke-screen-color-blue'),
      );
      await tapCanvas(tester, const Offset(3.5, 2.5));
      final blueState = _view(tester).sessionState;

      expect(_host(tester).inputSettings.color, 0xFF0000FF);
      expect(find.textContaining('color: 0xFF0000FF'), findsOneWidget);
      expect(blueState.historyState.undoEntries, hasLength(2));
      expect(
        blueState.canvasState.currentSurface.tiles.length,
        greaterThanOrEqualTo(
          blackState.canvasState.currentSurface.tiles.length,
        ),
      );
      expect(_surfaceHasRgbaBytes(blueState, const [0, 0, 255, 255]), isTrue);
    });

    testWidgets('debug status is deterministic across operations and color', (
      tester,
    ) async {
      await tester.pumpWidget(_app(_smallScreen()));

      expect(_debugStatus(tester), 'operation: none, cacheInvalidations: 0, color: 0xFF000000');
      await tapCanvas(tester, const Offset(1.5, 1.5));
      expect(_debugStatus(tester), 'operation: commit, cacheInvalidations: 1, color: 0xFF000000');
      await _tapKey(tester, const ValueKey<String>('brush-canvas-smoke-screen-undo'));
      expect(_debugStatus(tester), 'operation: undo, cacheInvalidations: 2, color: 0xFF000000');
      await _tapKey(tester, const ValueKey<String>('brush-canvas-smoke-screen-redo'));
      expect(_debugStatus(tester), 'operation: redo, cacheInvalidations: 3, color: 0xFF000000');
      await _tapKey(tester, const ValueKey<String>('brush-canvas-smoke-screen-color-red'));
      expect(_debugStatus(tester), 'operation: redo, cacheInvalidations: 3, color: 0xFFFF0000');
      await _tapKey(tester, const ValueKey<String>('brush-canvas-smoke-screen-reset'));
      expect(_debugStatus(tester), 'operation: reset, cacheInvalidations: 0, color: 0xFFFF0000');
    });

    testWidgets('does not add GestureDetector inside interactive canvas host', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

      final hostFinder = find.byType(InteractiveBrushCanvasSmokeHost);

      expect(
        find.descendant(of: hostFinder, matching: find.byType(GestureDetector)),
        findsNothing,
      );
    });

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

BrushCanvasSmokeScreen _smallScreen() {
  return BrushCanvasSmokeScreen(
    canvasSize: CanvasSize(width: 8, height: 8),
    tileSize: 2,
  );
}

String _debugStatus(WidgetTester tester) {
  return tester
      .widget<Text>(
        find.byKey(
          const ValueKey<String>('brush-canvas-smoke-screen-debug-status'),
        ),
      )
      .data!;
}

bool _surfaceHasRgbaBytes(
  BrushEditSessionState sessionState,
  List<int> rgbaBytes,
) {
  for (final tile in sessionState.canvasState.currentSurface.tiles.values) {
    final pixels = tile.pixels;
    for (var i = 0; i <= pixels.length - rgbaBytes.length; i += 4) {
      if (pixels[i] == rgbaBytes[0] &&
          pixels[i + 1] == rgbaBytes[1] &&
          pixels[i + 2] == rgbaBytes[2] &&
          pixels[i + 3] == rgbaBytes[3]) {
        return true;
      }
    }
  }
  return false;
}
