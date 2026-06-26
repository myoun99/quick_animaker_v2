import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/bitmap_surface.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_history_state.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_cache_operation_result.dart';
import 'package:quick_animaker_v2/src/models/brush_edit_session_operation_kind.dart';
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
import 'package:quick_animaker_v2/src/ui/canvas/brush_edit_canvas_view.dart';
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
  group('InteractiveBrushEditCanvasView', () {
    const layerId = LayerId('layer-a');
    const frameId = FrameId('frame-a');

    testWidgets('builds Listener and BrushEditCanvasView without GestureDetector', (
      tester,
    ) async {
      final sessionState = _sessionState();
      final sink = FakeCacheInvalidationSink();

      await tester.pumpWidget(
        _app(
          InteractiveBrushEditCanvasView(
            sessionState: sessionState,
            layerId: layerId,
            frameId: frameId,
            inputSettings: const BrushEditCanvasInputSettings(),
            cacheInvalidationSink: sink,
            onOperationResult: (_) {},
            showTransparentBackground: false,
          ),
        ),
      );

      final viewFinder = find.byType(InteractiveBrushEditCanvasView);
      expect(viewFinder, findsOneWidget);
      expect(
        find.descendant(
          of: viewFinder,
          matching: find.byKey(
            const ValueKey<String>(
              'interactive-brush-edit-canvas-view-listener',
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: viewFinder,
          matching: find.byType(BrushEditCanvasView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: viewFinder, matching: find.byType(GestureDetector)),
        findsNothing,
      );

      final canvasView = tester.widget<BrushEditCanvasView>(
        find.descendant(
          of: viewFinder,
          matching: find.byType(BrushEditCanvasView),
        ),
      );
      expect(identical(canvasView.sessionState, sessionState), isTrue);
      expect(canvasView.showTransparentBackground, isFalse);
    });

    testWidgets('pointer down/up inside surface emits changed commit result', (
      tester,
    ) async {
      final sessionState = _sessionState();
      final sink = FakeCacheInvalidationSink();
      final results = <BrushEditSessionCacheOperationResult>[];

      await tester.pumpWidget(_app(_view(sessionState, sink, results.add)));
      await _tap(tester, const Offset(1, 1));

      expect(results, hasLength(1));
      expect(results.single.kind, BrushEditSessionOperationKind.commit);
      expect(results.single.didAffectHistory, isTrue);
      expect(sink.totalCalls, greaterThan(0));
      expect(identical(results.single.sessionState, sessionState), isFalse);
    });

    testWidgets('pointer outside surface does not emit a result', (tester) async {
      final results = <BrushEditSessionCacheOperationResult>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), results.add)),
      );

      await _tap(tester, const Offset(9, 9));

      expect(results, isEmpty);
    });

    testWidgets('pointer cancel does not emit a result', (tester) async {
      final results = <BrushEditSessionCacheOperationResult>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), results.add)),
      );

      final gesture = await tester.createGesture(pointer: 1);
      await gesture.addPointer(location: const Offset(1, 1));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('pointer move without pointer down does not emit a result', (
      tester,
    ) async {
      final results = <BrushEditSessionCacheOperationResult>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), results.add)),
      );

      tester.binding.handlePointerEvent(
        const PointerMoveEvent(position: Offset(1, 1)),
      );
      tester.binding.handlePointerEvent(
        const PointerUpEvent(position: Offset(1, 1)),
      );
      await tester.pump();

      expect(results, isEmpty);
    });

    testWidgets('second pointer is ignored while first pointer is active', (
      tester,
    ) async {
      final results = <BrushEditSessionCacheOperationResult>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), results.add)),
      );

      final first = await tester.createGesture(pointer: 1);
      final second = await tester.createGesture(pointer: 2);
      await first.addPointer(location: const Offset(1, 1));
      await second.addPointer(location: const Offset(2, 2));
      await second.up();
      await first.up();
      await tester.pump();

      expect(results, hasLength(1));
    });

    testWidgets('callback is called at most once per stroke', (tester) async {
      final results = <BrushEditSessionCacheOperationResult>[];
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), results.add)),
      );

      final gesture = await tester.createGesture(pointer: 1);
      await gesture.addPointer(location: const Offset(1, 1));
      await gesture.moveTo(const Offset(2, 2));
      await gesture.moveTo(const Offset(20, 20));
      await gesture.up();
      await tester.pump();

      expect(results, hasLength(1));
    });

    testWidgets('does not mutate input states', (tester) async {
      final sessionState = _sessionState();
      final originalCanvasState = sessionState.canvasState;
      final originalHistoryState = sessionState.historyState;
      final originalSessionSnapshot = sessionState.toString();
      final originalCanvasSnapshot = originalCanvasState.toString();
      final originalHistorySnapshot = originalHistoryState.toString();
      final results = <BrushEditSessionCacheOperationResult>[];

      await tester.pumpWidget(
        _app(_view(sessionState, FakeCacheInvalidationSink(), results.add)),
      );
      await _tap(tester, const Offset(1, 1));

      expect(identical(sessionState.canvasState, originalCanvasState), isTrue);
      expect(identical(sessionState.historyState, originalHistoryState), isTrue);
      expect(sessionState.toString(), originalSessionSnapshot);
      expect(originalCanvasState.toString(), originalCanvasSnapshot);
      expect(originalHistoryState.toString(), originalHistorySnapshot);
    });

    test('does not execute undo or redo and does not add forbidden state management', () {
      final source = _readInteractiveSource();

      expect(source, isNot(contains('undoLatestBrushEdit')));
      expect(source, isNot(contains('redoLatestBrushEdit')));
      expect(source, isNot(contains('Provider')));
      expect(source, isNot(contains('Riverpod')));
      expect(source, isNot(contains('Bloc')));
      expect(source, isNot(contains('ChangeNotifier')));
    });

    testWidgets('does not affect StoryboardPanel or TimelinePanel', (tester) async {
      await tester.pumpWidget(
        _app(_view(_sessionState(), FakeCacheInvalidationSink(), (_) {})),
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

InteractiveBrushEditCanvasView _view(
  BrushEditSessionState sessionState,
  CacheInvalidationSink sink,
  ValueChanged<BrushEditSessionCacheOperationResult> onResult,
) {
  return InteractiveBrushEditCanvasView(
    sessionState: sessionState,
    layerId: const LayerId('layer-a'),
    frameId: const FrameId('frame-a'),
    inputSettings: const BrushEditCanvasInputSettings(),
    cacheInvalidationSink: sink,
    onOperationResult: onResult,
  );
}

Future<void> _tap(WidgetTester tester, Offset offset) async {
  final gesture = await tester.createGesture(pointer: 1);
  await gesture.addPointer(location: offset);
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

String _readInteractiveSource() {
  return File(
    'lib/src/ui/canvas/interactive_brush_edit_canvas_view.dart',
  ).readAsStringSync();
}
