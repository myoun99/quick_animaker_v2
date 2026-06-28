import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_screen.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

void main() {
  testWidgets('main canvas host embeds reusable brush view without screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MainCanvasBrushHost.fixture())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('main-canvas-brush-host')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(find.byType(BrushWorkspaceScreen), findsNothing);
  });

  testWidgets('accepts a supplied non-fixture active frame key', (
    tester,
  ) async {
    const key = BrushFrameKey(
      projectId: ProjectId('project-real'),
      trackId: TrackId('track-real'),
      cutId: CutId('cut-real'),
      layerId: LayerId('layer-real'),
      frameId: FrameId('frame-real'),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MainCanvasBrushHost(activeFrameKey: key)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(find.textContaining('frame-real'), findsWidgets);
    expect(find.textContaining('frame-1'), findsNothing);
  });
}
