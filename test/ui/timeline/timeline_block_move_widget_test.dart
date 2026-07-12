import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_block_move_handle.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

/// R10-④b: the block BODY handle — pan distances become frame/row steps
/// and the grid resolves the row under the pointer to the target layer.
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
    TimelineBlockMoveCallbacks? blockMove,
    TimelineGridMetrics metrics = TimelineGridMetrics.defaults,
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
          blockMove: blockMove,
          metrics: metrics,
        ),
      ),
    );
  }

  testWidgets('pan distances report frame steps and resolve the row under '
      'the pointer to the target layer', (tester) async {
    final updates = <(int, LayerId?)>[];
    var ended = 0;
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);

    await tester.pumpWidget(
      harness(
        layers: [blockLayer('layer-a'), blockLayer('layer-b', start: 10)],
        cursor: cursor,
        blockMove: TimelineBlockMoveCallbacks(
          onBegin: (layerId, blockStartIndex) {
            expect(layerId, const LayerId('layer-a'));
            expect(blockStartIndex, 0);
            return true;
          },
          onUpdate: ({required frameDelta, targetLayerId}) =>
              updates.add((frameDelta, targetLayerId)),
          onEnd: () => ended += 1,
          onCancel: () {},
        ),
      ),
    );

    final handle = find.byKey(
      const ValueKey<String>('timeline-block-move-handle-layer-a-0'),
    );
    expect(handle, findsOneWidget);

    // Two cells right (cell width 48): frame delta 2, own row.
    await tester.drag(
      handle,
      const Offset(96, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(updates.last, (2, const LayerId('layer-a')));
    expect(ended, 1);

    // One row down (row height 52): layer B is the target.
    await tester.drag(
      handle,
      const Offset(0, 52),
      kind: PointerDeviceKind.mouse,
    );
    expect(updates.last, (0, const LayerId('layer-b')));
    expect(ended, 2);
  });

  testWidgets('blocks too narrow for a body between the grips get no '
      'handle', (tester) async {
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);

    await tester.pumpWidget(
      harness(
        layers: [blockLayer('layer-a', length: 2)],
        cursor: cursor,
        blockMove: TimelineBlockMoveCallbacks(
          onBegin: (_, _) => true,
          onUpdate: ({required frameDelta, targetLayerId}) {},
          onEnd: () {},
          onCancel: () {},
        ),
        // 10px cells: a 2-frame block (20px) is narrower than the two
        // 12px edge grips — the body handle stands down.
        metrics: TimelineGridMetrics.defaults.copyWith(frameCellWidth: 10),
      ),
    );

    expect(
      find.byKey(
        const ValueKey<String>('timeline-block-move-handle-layer-a-0'),
      ),
      findsNothing,
    );
  });

  testWidgets('the X-sheet mounts the same handles (Axis policy)', (
    tester,
  ) async {
    final updates = <(int, LayerId?)>[];
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);

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
            blockMove: TimelineBlockMoveCallbacks(
              onBegin: (_, _) => true,
              onUpdate: ({required frameDelta, targetLayerId}) =>
                  updates.add((frameDelta, targetLayerId)),
              onEnd: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    final handle = find.byKey(
      const ValueKey<String>('timeline-block-move-handle-layer-a-0'),
    );
    expect(handle, findsOneWidget);

    // Two frame rows down (X-sheet frame row height 36): frame delta 2;
    // one column right (column width 164): layer B.
    await tester.drag(
      handle,
      const Offset(0, 72),
      kind: PointerDeviceKind.mouse,
    );
    expect(updates.last, (2, const LayerId('layer-a')));
    await tester.drag(
      handle,
      const Offset(164, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(updates.last, (0, const LayerId('layer-b')));
  });

  testWidgets('a tap on the block body still selects the cell underneath', (
    tester,
  ) async {
    final selectedFrames = <int>[];
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);

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
            blockMove: TimelineBlockMoveCallbacks(
              onBegin: (_, _) => true,
              onUpdate: ({required frameDelta, targetLayerId}) {},
              onEnd: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    // Frame 1 sits mid-block, under the move handle.
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-cell-layer-a-1')),
      warnIfMissed: false,
    );
    expect(selectedFrames, [1]);
  });
}
