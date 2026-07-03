import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_defaults.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_edit_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';

import '../helpers/brush_canvas_fixture.dart';
import 'brush_canvas_test_helpers.dart';

void main() {
  testWidgets('renders embedded canvas without temporary debug controls', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushEditCacheInvalidationSink(),
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

  testWidgets('uses default embedded canvas size when canvasSize is omitted', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: BrushEditCacheInvalidationSink(),
          ),
        ),
      ),
    );

    final sizedBox = tester.widget<SizedBox>(
      find
          .ancestor(
            of: find.byType(InteractiveBrushEditCanvasView),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(sizedBox.width, BrushCanvasDefaults.canvasSize.width.toDouble());
    expect(sizedBox.height, BrushCanvasDefaults.canvasSize.height.toDouble());
  });

  testWidgets('passes custom initial input settings to canvas view', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
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
            cacheInvalidationSink: BrushEditCacheInvalidationSink(),
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

  testWidgets('commits sampled source dabs into the brush frame store', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    final sink = BrushEditCacheInvalidationSink();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BrushCanvasPanel(
            coordinator: coordinator,
            availableFrameKeys: frameKeys,
            cacheInvalidationSink: sink,
            initialInputSettings: const BrushEditCanvasInputSettings(size: 8),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      canvasGlobalOffset(tester, const Offset(1, 1)),
      pointer: 1,
    );
    await gesture.moveTo(canvasGlobalOffset(tester, const Offset(7, 1)));
    await gesture.up();
    await tester.pump();

    final command = coordinator.frameStore
        .getOrCreateFrame(coordinator.activeFrameKey)
        .visibleActivePaintCommands
        .single;
    final sequences = command.sourceDabs.map((dab) => dab.sequence).toList();
    expect(command.sourceDabs.length, greaterThan(2));
    expect(sequences, everyElement(greaterThanOrEqualTo(0)));
    expect(_isStrictlyIncreasing(sequences), isTrue);
    expect(sink.brushFrames, isEmpty);
    expect(sink.layerTiles, isEmpty);
    expect(sink.frameComposites, isEmpty);
    expect(sink.playbackPreviews, isEmpty);
  });

  testWidgets(
    'does not prepare inactive display cache from active panel build',
    (tester) async {
      final frameKeys = BrushCanvasFixture.createFrameKeys();
      final coordinator = BrushCanvasFixture.createCoordinator(
        frameKeys: frameKeys,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              initialInputSettings: const BrushEditCanvasInputSettings(size: 8),
              canvasSize: BrushCanvasFixture.canvasSize,
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(
        canvasGlobalOffset(tester, const Offset(1, 1)),
        pointer: 1,
      );
      await gesture.moveTo(canvasGlobalOffset(tester, const Offset(7, 1)));
      await gesture.up();

      for (var i = 0; i < 3; i += 1) {
        await tester.pump();
        expect(
          coordinator.frameStore.displayCacheOrNull(coordinator.activeFrameKey),
          isNull,
        );
      }

      final canvasView = tester.widget<BrushEditCanvasView>(
        find.byType(BrushEditCanvasView),
      );
      expect(canvasView.displayPreviewSurface, isNull);
      expect(canvasView.activeEditCompositeSurface.tiles, isNotEmpty);
    },
  );
}

bool _isStrictlyIncreasing(Iterable<int> values) {
  int? previous;
  for (final value in values) {
    if (previous != null && value <= previous) {
      return false;
    }
    previous = value;
  }
  return true;
}
