import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_viewport.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_defaults.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_canvas_panel.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_edit_cache_invalidation_sink.dart';
import 'package:quick_animaker_v2/src/ui/brush/brush_tool_state.dart';
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
      tester
          .widget<InteractiveBrushEditCanvasView>(
            find.byType(InteractiveBrushEditCanvasView),
          )
          .inputSettings,
      const BrushEditCanvasInputSettings(size: 10),
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

  testWidgets('renders production brush tool options and updates settings', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );
    var toolState = BrushToolState.defaults;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              brushToolState: toolState,
              onBrushToolStateChanged: (state) {
                setState(() => toolState = state);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('brush-tool-options-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('brush-tool-current-display')),
      findsOneWidget,
    );
    expect(find.text('Brush 10px / 100%'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-size-slider')),
      const Offset(60, 0),
    );
    await tester.pumpAndSettle();
    expect(toolState.size, greaterThan(10));

    await tester.drag(
      find.byKey(const ValueKey<String>('brush-tool-opacity-slider')),
      const Offset(-80, 0),
    );
    await tester.pumpAndSettle();
    expect(toolState.opacity, lessThan(1));

    final blueSwatch = find.byKey(
      const ValueKey<String>('brush-tool-color-swatch-Blue'),
    );

    await tester.ensureVisible(blueSwatch);
    await tester.pumpAndSettle();

    await tester.tap(blueSwatch);
    await tester.pumpAndSettle();

    expect(toolState.color, 0xFF1E88E5);
    expect(find.text('Black'), findsNothing);
    expect(find.text('Red'), findsNothing);
  });

  testWidgets(
    'renders compact canvas editor panel shell and viewport controls',
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
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('canvas-editor-panel-shell')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-editor-panel-title-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-editor-panel-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-editor-panel-right-strip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-editor-panel-bottom-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-viewport-zoom-label')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-viewport-zoom-out')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-viewport-zoom-in')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-viewport-fit')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('canvas-viewport-reset')),
        findsOneWidget,
      );
    },
  );

  testWidgets('keeps inner drawing canvas at Cut canvas size', (tester) async {
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

    final drawingCanvasSize = tester.getSize(find.byType(BrushEditCanvasView));
    expect(drawingCanvasSize.width, BrushCanvasDefaults.canvasSize.width);
    expect(drawingCanvasSize.height, BrushCanvasDefaults.canvasSize.height);
  });

  testWidgets('fit action uses the available editor viewport size', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
      canvasSize: const CanvasSize(width: 100, height: 50),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              canvasSize: const CanvasSize(width: 100, height: 50),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final viewportSize = tester.getSize(
      find.byKey(const ValueKey<String>('brush-canvas-editor-viewport')),
    );

    await tester.tap(find.byKey(const ValueKey<String>('canvas-viewport-fit')));
    await tester.pump();

    final canvas = tester.widget<InteractiveBrushEditCanvasView>(
      find.byType(InteractiveBrushEditCanvasView),
    );
    final expected = CanvasViewport.fitToView(
      canvasWidth: 100,
      canvasHeight: 50,
      viewportWidth: viewportSize.width,
      viewportHeight: viewportSize.height,
    );

    expect(canvas.viewport.zoom, expected.zoom);
    expect(canvas.viewport.panX, expected.panX);
    expect(canvas.viewport.panY, expected.panY);
  });

  testWidgets('reset action restores the identity viewport', (tester) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
      canvasSize: const CanvasSize(width: 100, height: 50),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              canvasSize: const CanvasSize(width: 100, height: 50),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('canvas-viewport-fit')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('canvas-viewport-reset')),
    );
    await tester.pump();

    final canvas = tester.widget<InteractiveBrushEditCanvasView>(
      find.byType(InteractiveBrushEditCanvasView),
    );

    expect(canvas.viewport, CanvasViewport());
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
            brushToolState: BrushToolState.clamped(
              color: settings.color,
              size: settings.size,
              opacity: settings.opacity,
            ),
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
            brushToolState: BrushToolState.clamped(size: 8),
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

  testWidgets('prepares display cache after drawing', (tester) async {
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
            brushToolState: BrushToolState.clamped(size: 8),
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

    expect(
      coordinator.frameStore.displayCacheOrNull(coordinator.activeFrameKey),
      isNull,
    );

    await tester.pump();

    expect(
      coordinator.frameStore.displayCacheOrNull(coordinator.activeFrameKey),
      isNull,
    );

    final canvasView = tester.widget<BrushEditCanvasView>(
      find.byType(BrushEditCanvasView),
    );

    expect(canvasView.committedSourceDabStrokes, hasLength(1));
    expect(canvasView.committedSourceDabStrokes.single, isNotEmpty);
  });

  testWidgets('canvas editor panel shell remains safe at very small heights', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 80,
            child: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('canvas-editor-panel-title-bar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('canvas-editor-panel-content')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('canvas-editor-panel-right-strip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('canvas-editor-panel-bottom-bar')),
      findsOneWidget,
    );
  });

  testWidgets('panbar drag syncs parent once at drag end', (tester) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
      canvasSize: const CanvasSize(width: 300, height: 300),
    );
    final syncedViewports = <CanvasViewport>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              canvasSize: const CanvasSize(width: 300, height: 300),
              viewport: CanvasViewport(zoom: 2),
              onViewportChanged: syncedViewports.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(
          const ValueKey<String>('canvas-viewport-horizontal-scrollbar'),
        ),
      ),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    expect(syncedViewports, isEmpty);

    await gesture.up();
    await tester.pump();

    expect(syncedViewports, hasLength(1));
    expect(syncedViewports.single.panX, isNot(0));
  });

  testWidgets('panbar drag cancel syncs parent once with final viewport', (
    tester,
  ) async {
    final frameKeys = BrushCanvasFixture.createFrameKeys();
    final coordinator = BrushCanvasFixture.createCoordinator(
      frameKeys: frameKeys,
      canvasSize: const CanvasSize(width: 300, height: 300),
    );
    final syncedViewports = <CanvasViewport>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: BrushCanvasPanel(
              coordinator: coordinator,
              availableFrameKeys: frameKeys,
              cacheInvalidationSink: BrushEditCacheInvalidationSink(),
              canvasSize: const CanvasSize(width: 300, height: 300),
              viewport: CanvasViewport(zoom: 2),
              onViewportChanged: syncedViewports.add,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(
        find.byKey(
          const ValueKey<String>('canvas-viewport-horizontal-scrollbar'),
        ),
      ),
    );
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    expect(syncedViewports, isEmpty);

    await gesture.cancel();
    await tester.pump();

    expect(syncedViewports, hasLength(1));
    expect(syncedViewports.single.panX, isNot(0));
  });
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
