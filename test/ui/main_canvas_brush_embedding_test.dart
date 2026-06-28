import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';
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

  testWidgets('debug preview uses active editor selection when a frame exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(initialProject: _projectWithActiveFrame())),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('main-canvas-mode-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MainCanvasBrushHost), findsOneWidget);
    expect(find.byType(BrushWorkspaceView), findsOneWidget);
    expect(
      find.text('Active Frame: Frame 1 (editor-frame-1)'),
      findsOneWidget,
    );
    expect(find.text('Active Frame: Frame 1 (frame-1)'), findsNothing);
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

Project _projectWithActiveFrame() {
  return Project(
    id: const ProjectId('editor-project'),
    name: 'Editor Project',
    createdAt: DateTime.utc(2026),
    tracks: [
      Track(
        id: const TrackId('editor-track'),
        name: 'Video Track',
        cuts: [
          Cut(
            id: const CutId('editor-cut'),
            name: 'Editor Cut',
            duration: 24,
            canvasSize: const CanvasSize(width: 320, height: 240),
            layers: [
              Layer(
                id: const LayerId('editor-layer'),
                name: 'Editor Layer',
                frames: [
                  Frame(
                    id: const FrameId('editor-frame-1'),
                    duration: 1,
                    strokes: const [],
                  ),
                ],
                timeline: {
                  0: TimelineExposure.drawing(
                    const FrameId('editor-frame-1'),
                  ),
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
