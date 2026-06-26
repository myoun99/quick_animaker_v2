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
      expect(
        find.text('operation: none, cacheInvalidations: 0'),
        findsOneWidget,
      );

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

      await _tap(tester, const Offset(1.5, 1.5));

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

    test('does not include forbidden state management or direct commit calls', () {
      final source = File(
        'lib/src/ui/canvas/brush_canvas_smoke_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Provider')));
      expect(source, isNot(contains('Riverpod')));
      expect(source, isNot(contains('Bloc')));
      expect(source, isNot(contains('ChangeNotifier')));
      expect(source, isNot(contains('InheritedWidget')));
      expect(source, isNot(contains('commitBrushDabSequence')));
      expect(source, isNot(contains('undoLatestBrushEdit')));
      expect(source, isNot(contains('redoLatestBrushEdit')));
    });

    testWidgets('does not affect StoryboardPanel or TimelinePanel', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const BrushCanvasSmokeScreen()));

      expect(find.byType(StoryboardPanel), findsNothing);
      expect(find.byType(TimelinePanel), findsNothing);
    });
  });
}

Future<void> _tap(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(offset, pointer: 1);
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
