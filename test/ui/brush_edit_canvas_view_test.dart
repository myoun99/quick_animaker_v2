import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_bitmap_materialization_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/ui/canvas/bitmap_surface_painter.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_view.dart';

void main() {
  group('BrushEditCanvasView', () {
    testWidgets('wraps CustomPaint in stable keyed RepaintBoundary', (
      tester,
    ) async {
      final sessionState = _sessionState(
        BitmapSurface(canvasSize: CanvasSize(width: 12, height: 8)),
      );

      await tester.pumpWidget(
        _app(BrushEditCanvasView(sessionState: sessionState)),
      );

      expect(
        find.byKey(const ValueKey<String>('brush-edit-canvas-view-boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('brush-edit-canvas-view-custom-paint'),
        ),
        findsOneWidget,
      );
      final canvasViewFinder = find.byType(BrushEditCanvasView);

      expect(
        find.descendant(of: canvasViewFinder, matching: find.byType(Listener)),
        findsNothing,
      );

      expect(
        find.descendant(
          of: canvasViewFinder,
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });

    testWidgets('sizes itself from current surface canvasSize', (tester) async {
      final sessionState = _sessionState(
        BitmapSurface(canvasSize: CanvasSize(width: 12, height: 8)),
      );

      await tester.pumpWidget(
        _app(BrushEditCanvasView(sessionState: sessionState)),
      );

      expect(
        tester.getSize(
          find.byKey(const ValueKey<String>('brush-edit-canvas-view-boundary')),
        ),
        const Size(12, 8),
      );
      expect(
        tester.getSize(
          find.byKey(
            const ValueKey<String>('brush-edit-canvas-view-custom-paint'),
          ),
        ),
        const Size(12, 8),
      );
    });

    testWidgets('passes current surface and background setting to painter', (
      tester,
    ) async {
      final surface = BitmapSurface(
        canvasSize: CanvasSize(width: 7, height: 5),
      );
      final sessionState = _sessionState(surface);

      await tester.pumpWidget(
        _app(
          BrushEditCanvasView(
            sessionState: sessionState,
            showTransparentBackground: false,
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byKey(
          const ValueKey<String>('brush-edit-canvas-view-custom-paint'),
        ),
      );
      final painter = customPaint.painter! as BitmapSurfacePainter;

      expect(identical(painter.surface, surface), isTrue);
      expect(painter.showTransparentBackground, isFalse);
    });
  });
}

BrushEditSessionState _sessionState(BitmapSurface surface) {
  return BrushEditSessionState(
    canvasState: CanvasSurfaceState(currentSurface: surface),
    materializationHistoryState: BrushBitmapMaterializationHistoryState(),
  );
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}
