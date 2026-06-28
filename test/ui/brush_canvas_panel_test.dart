import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_fixture.dart';

void main() {
  testWidgets('defaults to embedded mode without temporary debug controls', (
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
      find.byKey(const ValueKey<String>('brush-workspace-reset-button')),
      findsNothing,
    );
    expect(find.text('Debug Reset Session'), findsNothing);
    expect(find.text('Black'), findsNothing);
    expect(find.text('Red'), findsNothing);
  });

  testWidgets('reusable panel preserves independent frame session state', (
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
            showDebugControls: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('brush-canvas-panel')),
      findsOneWidget,
    );

    await tester.tapAt(_canvasPoint(tester));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('frame-1 commands: 1 total | 1 live'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-frame-2-button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Active Frame: Frame 2'), findsOneWidget);
    expect(
      find.textContaining('frame-2 commands: 0 total | 0 live'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('brush-frame-1-button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Active Frame: Frame 1'), findsOneWidget);
    expect(
      find.textContaining('frame-1 commands: 1 total | 1 live'),
      findsOneWidget,
    );
  });

  testWidgets(
    'debug reset is labeled as session-only and keeps history metadata',
    (tester) async {
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
              showDebugControls: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Debug Reset Session'), findsOneWidget);
      expect(
        find.textContaining('resets only the interactive session'),
        findsOneWidget,
      );

      await tester.tapAt(_canvasPoint(tester));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 global undo'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('brush-workspace-reset-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('frame-1 commands: 1 total | 1 live'),
        findsOneWidget,
      );
      expect(find.textContaining('1 global undo'), findsOneWidget);
      expect(
        find.textContaining('does not clear BrushFrameStore commands'),
        findsOneWidget,
      );
    },
  );
}

Offset _canvasPoint(WidgetTester tester) {
  final finder = find.byKey(
    const ValueKey<String>('interactive-brush-edit-canvas-view-listener'),
  );
  final topLeft = tester.getTopLeft(finder);
  return topLeft + const Offset(10, 10);
}
