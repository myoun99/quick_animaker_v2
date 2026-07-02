import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/brush_frame_key.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/main_canvas_brush_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

import '../helpers/brush_canvas_fixture.dart';

void main() {
  testWidgets(
    'production host without selection renders empty placeholder only',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MainCanvasBrushHost())),
      );
      await tester.pumpAndSettle();

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
        find.byKey(const ValueKey<String>('brush-canvas-frame-1')),
        findsNothing,
      );
    },
  );

  testWidgets('missing selection does not create fake editable brush state', (
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
      const MaterialApp(home: Scaffold(body: MainCanvasBrushHost())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveBrushEditCanvasView), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MainCanvasBrushHost(activeFrameKey: key)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-real')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('main-canvas-brush-host-empty-selection'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'explicit fixture data injection embeds reusable brush view without screen',
    (tester) async {
      final frameKeys = BrushCanvasFixture.createFrameKeys();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MainCanvasBrushHost(
              activeFrameKey: frameKeys.first,
              availableFrameKeys: frameKeys,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('main-canvas-brush-host')),
        findsOneWidget,
      );
      expect(find.byType(BrushCanvasPanel), findsOneWidget);
      expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('brush-canvas-frame-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-frame-1-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-frame-2-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('brush-frame-3-button')),
        findsNothing,
      );
      expect(find.text('Debug Reset Session'), findsNothing);
      expect(find.text('Black'), findsNothing);
      expect(find.text('Red'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('brush-workspace-screen')),
        findsNothing,
      );
    },
  );

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
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-real')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-1')),
      findsNothing,
    );
  });

  testWidgets('updates canvas when active frame key changes', (tester) async {
    const frameA = BrushFrameKey(
      projectId: ProjectId('project-real'),
      trackId: TrackId('track-real'),
      cutId: CutId('cut-real'),
      layerId: LayerId('layer-real'),
      frameId: FrameId('frame-a'),
    );
    const frameB = BrushFrameKey(
      projectId: ProjectId('project-real'),
      trackId: TrackId('track-real'),
      cutId: CutId('cut-real'),
      layerId: LayerId('layer-real'),
      frameId: FrameId('frame-b'),
    );
    const frames = [frameA, frameB];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MainCanvasBrushHost(
            activeFrameKey: frameA,
            availableFrameKeys: frames,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-a')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MainCanvasBrushHost(
            activeFrameKey: frameB,
            availableFrameKeys: frames,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-a')),
      findsNothing,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MainCanvasBrushHost(
            activeFrameKey: frameA,
            availableFrameKeys: frames,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('brush-canvas-frame-a')),
      findsOneWidget,
    );
  });
}
