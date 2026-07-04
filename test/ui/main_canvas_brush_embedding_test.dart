import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/main.dart';
import 'package:quick_animaker_v2/src/controllers/default_cut_helpers.dart';
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
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

void main() {
  testWidgets('HomePage mounts production brush host in the main canvas area', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(const ValueKey<String>('main-canvas-mode-toggle')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('main-canvas-legacy-host')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('main-canvas-brush-host-container')),
      findsOneWidget,
    );
    expect(find.byType(MainCanvasBrushHost), findsOneWidget);
    expect(find.textContaining('Active strokes:'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Redo'), findsOneWidget);
    expect(find.text('Project Undo'), findsNothing);
    expect(find.text('Project Redo'), findsNothing);
  });

  testWidgets(
    'production brush host shows empty-selection placeholder without active drawing frame',
    (tester) async {
      await tester.pumpWidget(const QuickAnimakerApp());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('main-canvas-brush-host-container')),
        findsOneWidget,
      );
      expect(find.byType(MainCanvasBrushHost), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('main-canvas-brush-host-empty-selection'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Select a layer and frame to edit with Brush.'),
        findsOneWidget,
      );
      expect(find.byType(BrushCanvasPanel), findsNothing);
      expect(find.byType(InteractiveBrushEditCanvasView), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-default-frame')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-frame-1')),
        findsNothing,
      );
      expect(find.text('Debug Reset Session'), findsNothing);
      expect(find.text('Black'), findsNothing);
      expect(find.text('Red'), findsNothing);
    },
  );

  testWidgets(
    'production brush host uses active editor selection when a frame exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomePage(initialProject: _projectWithActiveFrame())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MainCanvasBrushHost), findsOneWidget);
      expect(find.byType(BrushCanvasPanel), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-editor-frame-1')),
        findsOneWidget,
      );
      final brushView = tester.widget<InteractiveBrushEditCanvasView>(
        find.byType(InteractiveBrushEditCanvasView),
      );
      expect(brushView.layerId, const LayerId('editor-layer'));
      expect(brushView.frameId, const FrameId('editor-frame-1'));
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-frame-1')),
        findsNothing,
      );
      expect(find.text('Active Frame: Frame 1 (frame-1)'), findsNothing);
      expect(find.text('Debug Reset Session'), findsNothing);
    },
  );

  testWidgets('separate Brush Workspace route entry is retired', (
    tester,
  ) async {
    await tester.pumpWidget(const QuickAnimakerApp());

    expect(
      find.byKey(const ValueKey<String>('brush-workspace-entry')),
      findsNothing,
    );
    expect(find.text('Brush Workspace'), findsNothing);
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
            duration: defaultCutDuration,
            canvasSize: defaultCutCanvasSize,
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
                  0: TimelineExposure.drawing(const FrameId('editor-frame-1')),
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
