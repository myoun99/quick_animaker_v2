import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_bitmap_materialization_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/brush_dab.dart';
import 'package:quick_animaker_v2/src/models/brush_tip_shape.dart';
import 'package:quick_animaker_v2/src/models/canvas_point.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/ui/canvas/active_stroke_overlay_painter.dart';
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
          const ValueKey<String>('brush-edit-canvas-base-custom-paint'),
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
            const ValueKey<String>('brush-edit-canvas-base-custom-paint'),
          ),
        ),
        const Size(12, 8),
      );
    });

    testWidgets('splits committed base layer from active overlay layer', (
      tester,
    ) async {
      final sessionState = _sessionState(
        BitmapSurface(canvasSize: CanvasSize(width: 12, height: 8)),
      );
      final activeDab = BrushDab(
        center: CanvasPoint(x: 4, y: 1),
        color: 0xFF000000,
        size: 1,
        opacity: 1,
        flow: 1,
        hardness: 1,
        tipShape: BrushTipShape.round,
        pressure: 1,
        sequence: 1,
      );

      final overlayModel = ActiveStrokeOverlayModel()..dabs.add(activeDab);
      addTearDown(overlayModel.dispose);

      await tester.pumpWidget(
        _app(
          BrushEditCanvasView(
            sessionState: sessionState,
            overlayModel: overlayModel,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('brush-edit-canvas-base-boundary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-edit-canvas-active-boundary')),
        findsOneWidget,
      );

      final basePaint = tester.widget<CustomPaint>(
        find.byKey(
          const ValueKey<String>('brush-edit-canvas-base-custom-paint'),
        ),
      );
      final activePaint = tester.widget<CustomPaint>(
        find.byKey(
          const ValueKey<String>('brush-edit-canvas-active-custom-paint'),
        ),
      );

      final basePainter = basePaint.painter! as BitmapSurfacePainter;
      final activePainter = activePaint.painter! as ActiveStrokeOverlayPainter;

      expect(
        identical(basePainter.surface, sessionState.canvasState.currentSurface),
        isTrue,
      );
      expect(identical(activePainter.model, overlayModel), isTrue);
      expect(activePainter.model!.dabs, [activeDab]);
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
          const ValueKey<String>('brush-edit-canvas-base-custom-paint'),
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
