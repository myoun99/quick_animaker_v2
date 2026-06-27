import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_fixture.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_workspace_view.dart';

void main() {
  testWidgets('reusable view preserves independent frame session state', (
    tester,
  ) async {
    final frameKeys = BrushWorkspaceFixture.createFrameKeys();
    final coordinator = BrushWorkspaceFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushWorkspaceView(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushWorkspaceCacheInvalidationSink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
}

Offset _canvasPoint(WidgetTester tester) {
  final finder = find.byKey(
    const ValueKey<String>('interactive-brush-edit-canvas-view-listener'),
  );
  final topLeft = tester.getTopLeft(finder);
  return topLeft + const Offset(10, 10);
}
