import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_screen.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

void main() {
  testWidgets('main canvas host embeds reusable brush view without screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MainCanvasBrushHost())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('main-canvas-brush-host')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(find.byType(BrushWorkspaceScreen), findsNothing);
  });
}
