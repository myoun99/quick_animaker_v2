import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_repeat.dart';
import 'package:quick_animaker_v2/src/models/timeline_run_edit.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_comma_drag_handle.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_comma_drag_policy.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_cell.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_run_end_handles.dart';

/// UI-R8: the run-edge [+]/[↻] handles and the repeat GHOST display.
void main() {
  TimelineCellExposureState stateFor(Layer layer, int frameIndex) {
    if (layer.timeline[frameIndex]?.isDrawing ?? false) {
      return TimelineCellExposureState.drawingStart;
    }
    if (coveringDrawingBlockAt(layer.timeline, frameIndex) != null) {
      return TimelineCellExposureState.held;
    }
    return TimelineCellExposureState.uncovered;
  }

  Layer plainLayer() => Layer(
    id: const LayerId('layer-a'),
    name: 'A',
    frames: [
      Frame(id: const FrameId('f1'), duration: 1, strokes: const []),
      Frame(id: const FrameId('f2'), duration: 1, strokes: const []),
    ],
    timeline: {
      0: const TimelineExposure.drawing(FrameId('f1'), length: 2),
      6: const TimelineExposure.drawing(FrameId('f2'), length: 2),
    },
  );

  Layer repeatedLayer() => rederiveRepeatRegions(
    Layer(
      id: const LayerId('layer-r'),
      name: 'R',
      frames: [Frame(id: const FrameId('rf'), duration: 1, strokes: const [])],
      timeline: {0: const TimelineExposure.drawing(FrameId('rf'), length: 2)},
      repeatRegions: const [
        TimelineRepeatRegion(
          id: 'r1',
          anchorFrameId: FrameId('rf'),
          sourceSpanFrames: 2,
          frameCount: 4,
        ),
      ],
    ),
  );

  Widget harness({
    required List<Layer> layers,
    required TimelineRunEditCallbacks runEdit,
    ValueNotifier<TimelineDragPreview?>? dragPreview,
  }) {
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);
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
          runEdit: runEdit,
          dragPreview: dragPreview,
          // Classic geometry: drags below assume 48px cells.
          metrics: const TimelineGridMetrics(
            frameCellWidth: 48,
            layerRowHeight: 52,
          ),
        ),
      ),
    );
  }

  TimelineRunEditCallbacks recordingCallbacks({
    List<int>? addCounts,
    List<int>? repeatCounts,
    void Function(LayerId, int, bool)? onAddBegin,
    void Function(LayerId, int, String?)? onRepeatBegin,
  }) {
    return TimelineRunEditCallbacks(
      onAddBegin: (layerId, blockStartIndex, {required atEnd}) {
        onAddBegin?.call(layerId, blockStartIndex, atEnd);
        return true;
      },
      onAddUpdate: (count) => addCounts?.add(count),
      onAddEnd: () {},
      onAddCancel: () {},
      onRepeatBegin: (layerId, blockStartIndex, regionId) {
        onRepeatBegin?.call(layerId, blockStartIndex, regionId);
        return true;
      },
      onRepeatUpdate: (count) => repeatCounts?.add(count),
      onRepeatEnd: () {},
      onRepeatCancel: () {},
    );
  }

  testWidgets('[+] and [↻] mount at a free run end; [+] also before a run '
      'with space; dragging [+] reports frame counts', (tester) async {
    final addCounts = <int>[];
    final begins = <(LayerId, int, bool)>[];
    await tester.pumpWidget(
      harness(
        layers: [plainLayer()],
        runEdit: recordingCallbacks(
          addCounts: addCounts,
          onAddBegin: (layerId, start, atEnd) =>
              begins.add((layerId, start, atEnd)),
        ),
      ),
    );

    // Keys carry the run ANCHOR frameId, never an index (UI-R9 A1).
    expect(
      find.byKey(const ValueKey<String>('timeline-run-add-end-layer-a-f1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('timeline-run-repeat-layer-a-f1')),
      findsOneWidget,
    );
    // The second run (frame 6) has free space before it too.
    expect(
      find.byKey(const ValueKey<String>('timeline-run-add-start-layer-a-f2')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('timeline-run-add-end-layer-a-f1')),
      const Offset(96, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(begins.single, (const LayerId('layer-a'), 0, true));
    expect(addCounts, isNotEmpty);
    expect(addCounts.last, 2);
  });

  testWidgets('start-side [+] keeps accumulating across preview steps '
      '(UI-R9 A1 regression: the prepend preview shifts the run start, and '
      'an index-keyed/preview-mounted handle remounted mid-gesture, '
      'committing one frame)', (tester) async {
    final layer = plainLayer();
    final dragPreview = ValueNotifier<TimelineDragPreview?>(null);
    addTearDown(dragPreview.dispose);
    final addCounts = <int>[];
    var ends = 0;
    final callbacks = TimelineRunEditCallbacks(
      onAddBegin: (_, _, {required atEnd}) => true,
      onAddUpdate: (count) {
        addCounts.add(count);
        // The session's feedback loop: every step republishes a preview
        // layer whose run start has shifted LEFT by the count.
        final previewed = count == 0
            ? null
            : layerWithNewFramesAtRunEdge(
                layer,
                blockStartIndex: 6,
                atEnd: false,
                count: count,
                frameIdAt: (ordinal) => FrameId('new-$ordinal'),
              );
        dragPreview.value = previewed == null
            ? null
            : ExposureEdgeDragPreview(previewLayer: previewed.layer);
      },
      onAddEnd: () {
        ends += 1;
        dragPreview.value = null;
      },
      onAddCancel: () => dragPreview.value = null,
      onRepeatBegin: (_, _, _) => false,
      onRepeatUpdate: (_) {},
      onRepeatEnd: () {},
      onRepeatCancel: () {},
    );
    await tester.pumpWidget(
      harness(layers: [layer], runEdit: callbacks, dragPreview: dragPreview),
    );

    final handle = find.byKey(
      const ValueKey<String>('timeline-run-add-start-layer-a-f2'),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(handle),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 3; step += 1) {
      await gesture.moveBy(const Offset(-48, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(addCounts.last, 3);
    expect(ends, 1);
  });

  testWidgets('a run carrying a repeat shows the RESIZE handle at the ghost '
      'tail instead of [+]/[↻], and its drag offsets the existing count', (
    tester,
  ) async {
    final repeatCounts = <int>[];
    final begins = <(LayerId, int, String?)>[];
    await tester.pumpWidget(
      harness(
        layers: [repeatedLayer()],
        runEdit: recordingCallbacks(
          repeatCounts: repeatCounts,
          onRepeatBegin: (layerId, start, regionId) =>
              begins.add((layerId, start, regionId)),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('timeline-run-add-end-layer-r-rf')),
      findsNothing,
    );
    final resize = find.byKey(
      const ValueKey<String>('timeline-repeat-resize-layer-r-r1'),
    );
    expect(resize, findsOneWidget);

    // Shrink by one frame (48px left): 4 existing − 1 = 3.
    await tester.drag(
      resize,
      const Offset(-48, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(begins.single, (const LayerId('layer-r'), 0, 'r1'));
    expect(repeatCounts.last, 3);
  });

  testWidgets('ghost cells dim and ghost blocks carry no edge grips', (
    tester,
  ) async {
    final cursor = ValueNotifier<int>(0);
    addTearDown(cursor.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerTimelineGrid(
            layers: [repeatedLayer()],
            activeLayerId: const LayerId('layer-r'),
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
            commaDrag: TimelineCommaDragCallbacks(
              onBegin: (_, _, _) => true,
              onUpdate: (_) {},
              onEnd: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    TimelineFrameCell cellAt(int index) => tester.widget<TimelineFrameCell>(
      find.ancestor(
        of: find.byKey(ValueKey<String>('timeline-cell-layer-r-$index')),
        matching: find.byType(TimelineFrameCell),
      ),
    );
    expect(cellAt(0).ghost, isFalse);
    expect(cellAt(1).ghost, isFalse);
    expect(cellAt(2).ghost, isTrue);
    expect(cellAt(3).ghost, isTrue);
    expect(cellAt(4).ghost, isTrue);
    expect(cellAt(6).ghost, isFalse);

    // Grips: only the SOURCE block's two — the ghost blocks carry none.
    expect(find.byType(TimelineBlockEdgeGrip), findsNWidgets(2));
  });
}
