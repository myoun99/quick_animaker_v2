import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_screen.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_view.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

void main() {
  testWidgets(
    'HomePage defaults to legacy CanvasView in the main canvas area',
    (tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());

      expect(
        find.byKey(const ValueKey<String>('main-canvas-mode-toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('main-canvas-legacy-host')),
        findsOneWidget,
      );
      expect(find.byType(CanvasView), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('main-canvas-brush-host-container')),
        findsNothing,
      );
      expect(find.byType(MainCanvasBrushHost), findsNothing);
    },
  );

  testWidgets('debug preview toggle shows MainCanvasBrushHost in main canvas', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await tester.tap(
      find.byKey(const ValueKey<String>('main-canvas-mode-toggle')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('main-canvas-brush-host-container')),
      findsOneWidget,
    );
    expect(find.byType(MainCanvasBrushHost), findsOneWidget);
    expect(find.byType(BrushWorkspaceView), findsOneWidget);
    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(find.byType(CanvasView), findsNothing);
  });

  testWidgets('debug preview toggle returns to legacy CanvasView', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    final toggle = find.byKey(
      const ValueKey<String>('main-canvas-mode-toggle'),
    );
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('main-canvas-legacy-host')),
      findsOneWidget,
    );
    expect(find.byType(CanvasView), findsOneWidget);
    expect(find.byType(MainCanvasBrushHost), findsNothing);
  });

  testWidgets('BrushWorkspaceScreen remains available from the debug route', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-workspace-entry')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BrushWorkspaceScreen), findsOneWidget);
    expect(find.byType(BrushWorkspaceView), findsOneWidget);
  });
}
