import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_frame_range.dart';

import 'timeline_cell_probe.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_range_gesture.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

/// UI-R8: the row-wide range gesture layer — a cell drag SELECTS a frame
/// range, a drag starting inside the selection MOVES it (frame steps along
/// the main axis, row steps across; the grid resolves rows to layers).
void main() {
  Layer blockLayer(String id, {int length = 4, int start = 0}) => Layer(
    id: LayerId(id),
    name: id,
    frames: [Frame(id: FrameId('$id-f1'), duration: 1, strokes: const [])],
    timeline: {
      start: TimelineExposure.drawing(FrameId('$id-f1'), length: length),
    },
  );

  TimelineCellExposureState stateFor(Layer layer, int frameIndex) {
    if (layer.timeline[frameIndex]?.isDrawing ?? false) {
      return TimelineCellExposureState.drawingStart;
    }
    if (coveringDrawingBlockAt(layer.timeline, frameIndex) != null) {
      return TimelineCellExposureState.held;
    }
    return TimelineCellExposureState.uncovered;
  }

  Widget harness({
    required List<Layer> layers,
    required ValueNotifier<int> cursor,
    required TimelineFrameRangeHooks rangeHooks,
    // Classic geometry: this file's pan distances assume 48×52 cells.
    TimelineGridMetrics metrics = const TimelineGridMetrics(
      frameCellWidth: 48,
      layerRowHeight: 52,
    ),
  }) {
    return MaterialApp(
      home: Scaffold(
        body: LayerTimelineGrid(
          layers: layers,
          activeLayerId: layers.first.id,
          frameCursor: cursor,
          playbackFrameCount: 24,
          exposureStateForLayer: stateFor,
          onSelectLayer: (_) {},
          onSelectFrame: (_) {},
          onAddLayer: () {},
          onToggleLayerVisibility: (_) {},
          onLayerOpacityChanged: (_, _) {},
          onToggleLayerTimesheet: (_) {},
          onLayerMarkSelected: (_, _) {},
          rangeHooks: rangeHooks,
          metrics: metrics,
        ),
      ),
    );
  }

  TimelineFrameRangeHooks hooks({
    required ValueNotifier<TimelineFrameRangeSelection?> selection,
    void Function(LayerId, int, int)? onSelectUpdate,
    VoidCallback? onClear,
    bool Function()? onMoveBegin,
    void Function({required int frameDelta, LayerId? targetLayerId})?
    onMoveUpdate,
    VoidCallback? onMoveEnd,
  }) {
    return TimelineFrameRangeHooks(
      selection: selection,
      onSelectUpdate: onSelectUpdate == null
          ? (_, _, _, {headLayerId}) {}
          : (layerId, anchorIndex, headIndex, {headLayerId}) =>
                onSelectUpdate(layerId, anchorIndex, headIndex),
      onClear: onClear ?? () {},
      move: TimelineRangeMoveCallbacks(
        onBegin: onMoveBegin ?? () => true,
        onUpdate: onMoveUpdate ?? ({required frameDelta, targetLayerId}) {},
        onEnd: onMoveEnd ?? () {},
        onCancel: () {},
      ),
    );
  }

  testWidgets('a cell drag reports anchor/head SELECT updates, never a '
      'move', (tester) async {
    final selectUpdates = <(LayerId, int, int)>[];
    var moveBegan = 0;
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      harness(
        layers: [blockLayer('layer-a')],
        cursor: cursor,
        rangeHooks: hooks(
          selection: selection,
          onSelectUpdate: (layerId, anchor, head) =>
              selectUpdates.add((layerId, anchor, head)),
          onMoveBegin: () {
            moveBegan += 1;
            return true;
          },
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-layer-a'),
    );
    expect(gestureLayer, findsOneWidget);

    // Drag from cell 0 two cells right (48px cells): head lands on 2.
    final start = tester.getTopLeft(gestureLayer) + const Offset(24, 26);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(96, 0));
    await gesture.up();
    await tester.pump();

    expect(selectUpdates.first, (const LayerId('layer-a'), 0, 0));
    expect(selectUpdates.last, (const LayerId('layer-a'), 0, 2));
    expect(moveBegan, 0);
  });

  testWidgets('a drag starting INSIDE the selection moves it: frame steps '
      'and the row under the pointer resolve to the target layer', (
    tester,
  ) async {
    final moveUpdates = <(int, LayerId?)>[];
    var ended = 0;
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(
      const TimelineFrameRangeSelection(
        layerId: LayerId('layer-a'),
        startIndex: 0,
        endIndexExclusive: 4,
      ),
    );
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      harness(
        layers: [blockLayer('layer-a'), blockLayer('layer-b', start: 10)],
        cursor: cursor,
        rangeHooks: hooks(
          selection: selection,
          onMoveUpdate: ({required frameDelta, targetLayerId}) =>
              moveUpdates.add((frameDelta, targetLayerId)),
          onMoveEnd: () => ended += 1,
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-layer-a'),
    );
    // Press inside the selected span (cell 1), two cells right.
    final start = tester.getTopLeft(gestureLayer) + const Offset(72, 26);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(96, 0));
    await tester.pump();
    expect(moveUpdates.last, (2, const LayerId('layer-a')));

    // One row down: layer B becomes the target.
    await gesture.moveBy(const Offset(0, 52));
    await tester.pump();
    expect(moveUpdates.last, (2, const LayerId('layer-b')));

    await gesture.up();
    await tester.pump();
    expect(ended, 1, reason: 'exactly one commit, on release');
  });

  testWidgets('touch selects like the pen (UI-R17 #6, superseding R12-⑤: '
      'pens report as touch on some drivers)', (tester) async {
    final selectUpdates = <(LayerId, int, int)>[];
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      harness(
        layers: [blockLayer('layer-a')],
        cursor: cursor,
        rangeHooks: hooks(
          selection: selection,
          onSelectUpdate: (layerId, anchor, head) =>
              selectUpdates.add((layerId, anchor, head)),
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-layer-a'),
    );
    final stylus = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24, 26),
      kind: PointerDeviceKind.stylus,
    );
    await stylus.moveBy(const Offset(96, 0));
    await stylus.up();
    await tester.pump();
    expect(selectUpdates, isNotEmpty, reason: 'the pen selects');

    selectUpdates.clear();
    final touch = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24, 26),
    );
    await touch.moveBy(const Offset(96, 0));
    await touch.up();
    await tester.pump();
    expect(
      selectUpdates,
      isNotEmpty,
      reason:
          'touch joins the pan arena — pen-as-touch drivers must work; '
          'grid panning lives on the rulers/scrollbars',
    );
  });

  testWidgets('a plain tap clears the selection AND still selects the cell '
      'underneath', (tester) async {
    final selectedFrames = <int>[];
    var cleared = 0;
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerTimelineGrid(
            layers: [blockLayer('layer-a')],
            activeLayerId: const LayerId('layer-a'),
            frameCursor: cursor,
            playbackFrameCount: 24,
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: selectedFrames.add,
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            rangeHooks: hooks(
              selection: selection,
              onClear: () => cleared += 1,
            ),
          ),
        ),
      ),
    );

    await tapTimelineCell(tester, 'layer-a', 1);
    expect(selectedFrames, [1]);
    expect(cleared, 1);
  });

  testWidgets('the X-sheet mounts the same gesture layer transposed '
      '(Axis policy)', (tester) async {
    final selectUpdates = <(LayerId, int, int)>[];
    final moveUpdates = <(int, LayerId?)>[];
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: XSheetTimelineGrid(
            layers: [blockLayer('layer-a'), blockLayer('layer-b', start: 10)],
            activeLayerId: const LayerId('layer-a'),
            frameCursor: cursor,
            frameCount: 24,
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: (_) {},
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            rangeHooks: hooks(
              selection: selection,
              onSelectUpdate: (layerId, anchor, head) =>
                  selectUpdates.add((layerId, anchor, head)),
              onMoveUpdate: ({required frameDelta, targetLayerId}) =>
                  moveUpdates.add((frameDelta, targetLayerId)),
            ),
          ),
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-layer-a'),
    );
    expect(gestureLayer, findsOneWidget);

    // Two frame rows down (X-sheet frame row height 36): head = frame 2.
    final start = tester.getTopLeft(gestureLayer) + const Offset(20, 18);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 72));
    await gesture.up();
    await tester.pump();
    expect(selectUpdates.last, (const LayerId('layer-a'), 0, 2));

    // With a selection in place, dragging inside it one COLUMN right
    // (column width 164) targets layer B.
    selection.value = const TimelineFrameRangeSelection(
      layerId: LayerId('layer-a'),
      startIndex: 0,
      endIndexExclusive: 4,
    );
    final move = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await move.moveBy(const Offset(164, 0));
    await move.up();
    await tester.pump();
    expect(moveUpdates.last, (0, const LayerId('layer-b')));
  });
}
