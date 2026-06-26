import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_cache_operation_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_state.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/canvas_surface_state.dart';
import 'package:quick_animaker_v2/src/models/frame_composite_cache_key.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_tile_cache_key.dart';
import 'package:quick_animaker_v2/src/models/playback_preview_cache_key.dart';
import 'package:quick_animaker_v2/src/services/cache_invalidation_executor.dart';
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_canvas_smoke_host.dart';
import 'package:quick_animaker_v2/src/ui/canvas/interactive_brush_edit_canvas_view.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

class FakeCacheInvalidationSink implements CacheInvalidationSink {
  final layerTiles = <LayerTileCacheKey>[];
  final frameComposites = <FrameCompositeCacheKey>[];
  final playbackPreviews = <PlaybackPreviewCacheKey>[];

  int get totalCalls =>
      layerTiles.length + frameComposites.length + playbackPreviews.length;

  @override
  void invalidateLayerTile(LayerTileCacheKey key) => layerTiles.add(key);

  @override
  void invalidateFrameComposite(FrameCompositeCacheKey key) =>
      frameComposites.add(key);

  @override
  void invalidatePlaybackPreview(PlaybackPreviewCacheKey key) =>
      playbackPreviews.add(key);
}

void main() {
  group('InteractiveBrushCanvasSmokeHost', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');
    const inputSettings = BrushEditCanvasInputSettings(color: 0xFFFF0000);

    testWidgets('builds and passes configuration to interactive canvas', (
      tester,
    ) async {
      final sessionState = _sessionState();
      final sink = FakeCacheInvalidationSink();

      await tester.pumpWidget(
        _app(
          InteractiveBrushCanvasSmokeHost(
            initialSessionState: sessionState,
            layerId: layerId,
            frameId: frameId,
            inputSettings: inputSettings,
            cacheInvalidationSink: sink,
            showTransparentBackground: false,
          ),
        ),
      );

      final hostFinder = find.byType(InteractiveBrushCanvasSmokeHost);
      expect(hostFinder, findsOneWidget);
      expect(
        find.descendant(
          of: hostFinder,
          matching: find.byType(InteractiveBrushEditCanvasView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: hostFinder,
          matching: find.byKey(
            const ValueKey<String>('interactive-brush-canvas-smoke-host-view'),
          ),
        ),
        findsOneWidget,
      );

      final view = tester.widget<InteractiveBrushEditCanvasView>(
        find.byType(InteractiveBrushEditCanvasView),
      );
      expect(identical(view.sessionState, sessionState), isTrue);
      expect(view.layerId, layerId);
      expect(view.frameId, frameId);
      expect(view.inputSettings, inputSettings);
      expect(identical(view.cacheInvalidationSink, sink), isTrue);
      expect(view.showTransparentBackground, isFalse);
    });

    testWidgets('stores operation result session state and rebuilds canvas', (
      tester,
    ) async {
      final sessionState = _sessionState();
      final originalCanvasState = sessionState.canvasState;
      final originalHistoryState = sessionState.historyState;
      final originalSessionSnapshot = sessionState.toString();
      final originalCanvasSnapshot = originalCanvasState.toString();
      final originalHistorySnapshot = originalHistoryState.toString();
      final sink = FakeCacheInvalidationSink();
      final results = <BrushEditSessionCacheOperationResult>[];

      await tester.pumpWidget(
        _app(
          InteractiveBrushCanvasSmokeHost(
            initialSessionState: sessionState,
            layerId: layerId,
            frameId: frameId,
            inputSettings: inputSettings,
            cacheInvalidationSink: sink,
            onOperationResult: results.add,
          ),
        ),
      );

      await _tap(tester, const Offset(1.5, 1.5));

      expect(results, hasLength(1));
      expect(sink.totalCalls, greaterThan(0));
      expect(identical(results.single.sessionState, sessionState), isFalse);

      final view = tester.widget<InteractiveBrushEditCanvasView>(
        find.byType(InteractiveBrushEditCanvasView),
      );
      expect(identical(view.sessionState, results.single.sessionState), isTrue);
      expect(identical(view.sessionState, sessionState), isFalse);
      expect(view.sessionState.canvasState.currentSurface.tiles, isNotEmpty);

      expect(identical(sessionState.canvasState, originalCanvasState), isTrue);
      expect(
        identical(sessionState.historyState, originalHistoryState),
        isTrue,
      );
      expect(sessionState.toString(), originalSessionSnapshot);
      expect(originalCanvasState.toString(), originalCanvasSnapshot);
      expect(originalHistoryState.toString(), originalHistorySnapshot);
    });

    testWidgets('does not add GestureDetector outside interactive canvas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          InteractiveBrushCanvasSmokeHost(
            initialSessionState: _sessionState(),
            layerId: layerId,
            frameId: frameId,
            inputSettings: inputSettings,
            cacheInvalidationSink: FakeCacheInvalidationSink(),
          ),
        ),
      );

      final hostFinder = find.byType(InteractiveBrushCanvasSmokeHost);
      expect(
        find.descendant(of: hostFinder, matching: find.byType(GestureDetector)),
        findsNothing,
      );
    });

    test('does not include forbidden state management or app wiring', () {
      final source = File(
        'lib/src/ui/canvas/interactive_brush_canvas_smoke_host.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Provider')));
      expect(source, isNot(contains('Riverpod')));
      expect(source, isNot(contains('Bloc')));
      expect(source, isNot(contains('ChangeNotifier')));
      expect(source, isNot(contains('commitBrushDabSequence')));
      expect(source, isNot(contains('undoLatestBrushEdit')));
      expect(source, isNot(contains('redoLatestBrushEdit')));
    });

    testWidgets('does not affect StoryboardPanel or TimelinePanel', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          InteractiveBrushCanvasSmokeHost(
            initialSessionState: _sessionState(),
            layerId: layerId,
            frameId: frameId,
            inputSettings: inputSettings,
            cacheInvalidationSink: FakeCacheInvalidationSink(),
          ),
        ),
      );

      expect(find.byType(StoryboardPanel), findsNothing);
      expect(find.byType(TimelinePanel), findsNothing);
    });
  });
}

BrushEditSessionState _sessionState() {
  return BrushEditSessionState(
    canvasState: CanvasSurfaceState(
      currentSurface: BitmapSurface(
        canvasSize: CanvasSize(width: 8, height: 8),
        tileSize: 2,
      ),
    ),
    historyState: BrushEditHistoryState(),
  );
}

Future<void> _tap(WidgetTester tester, Offset offset) async {
  final gesture = await tester.startGesture(offset, pointer: 1);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
}
