import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

Finder interactiveBrushCanvasFinder() =>
    find.byType(InteractiveBrushEditCanvasView);

Offset canvasGlobalOffset(WidgetTester tester, Offset localOffset) {
  return tester.getTopLeft(interactiveBrushCanvasFinder()) + localOffset;
}

Future<void> tapCanvas(
  WidgetTester tester,
  Offset localOffset, {
  int pointer = 1,
}) async {
  final gesture = await tester.startGesture(
    canvasGlobalOffset(tester, localOffset),
    pointer: pointer,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Future<void> dragCanvas(
  WidgetTester tester,
  List<Offset> localOffsets, {
  int pointer = 1,
}) async {
  assert(localOffsets.isNotEmpty);

  final gesture = await tester.startGesture(
    canvasGlobalOffset(tester, localOffsets.first),
    pointer: pointer,
  );
  await tester.pump();

  for (final localOffset in localOffsets.skip(1)) {
    await gesture.moveTo(canvasGlobalOffset(tester, localOffset));
    await tester.pump();
  }

  await gesture.up();
  await tester.pump();
}
