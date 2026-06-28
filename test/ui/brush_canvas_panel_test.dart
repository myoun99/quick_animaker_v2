import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_fixture.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

void main() {
  testWidgets('renders embedded canvas without temporary debug controls', (
    tester,
  ) async {
    final frameKeys = BrushWorkspaceFixture.createFrameKeys();
    final coordinator = BrushWorkspaceFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushWorkspaceCacheInvalidationSink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('brush-canvas-panel')),
      findsOneWidget,
    );
    expect(find.byType(InteractiveBrushEditCanvasView), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('interactive-brush-edit-canvas-view-listener'),
      ),
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
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-undo-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-redo-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-reset-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-active-frame-label')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-status-text')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-workspace-debug-reset-help')),
      findsNothing,
    );
    expect(find.text('Debug Reset Session'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Redo'), findsNothing);
    expect(find.text('Black'), findsNothing);
    expect(find.text('Red'), findsNothing);
  });

  testWidgets('passes custom initial input settings to canvas view', (
    tester,
  ) async {
    final frameKeys = BrushWorkspaceFixture.createFrameKeys();
    final coordinator = BrushWorkspaceFixture.createCoordinator(
      frameKeys: frameKeys,
    );
    const settings = BrushEditCanvasInputSettings(
      color: 0xFFFF0000,
      size: 12,
      opacity: 0.75,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushWorkspaceCacheInvalidationSink(),
            initialInputSettings: settings,
          ),
        ),
      ),
    );

    final canvas = tester.widget<InteractiveBrushEditCanvasView>(
      find.byType(InteractiveBrushEditCanvasView),
    );
    expect(canvas.inputSettings, settings);
  });
}
