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
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_run_end_handles.dart';

import 'timeline_cell_probe.dart';

/// UI-R9 #10: the run-edge cluster — the accent [+] add chip, the N/H/R
/// property tag + flyout, and the GHOST display.
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

  /// Block [0,2) with an END REPEAT edge filling ghosts to cut frame 6.
  Layer repeatedLayer() => rederiveRunBehaviors(
    Layer(
      id: const LayerId('layer-r'),
      name: 'R',
      frames: [Frame(id: const FrameId('rf'), duration: 1, strokes: const [])],
      timeline: {0: const TimelineExposure.drawing(FrameId('rf'), length: 2)},
      runBehaviors: const [
        TimelineRunBehavior(
          anchorFrameId: FrameId('rf'),
          side: TimelineRunEdgeSide.end,
          mode: TimelineRunEdgeMode.repeat,
        ),
      ],
    ),
    cutFrameCount: 6,
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
    void Function(LayerId, int, bool)? onAddBegin,
    List<(LayerId, int, TimelineRunEdgeSide, TimelineRunEdgeMode?)>?
        modeSelections,
  }) {
    return TimelineRunEditCallbacks(
      onAddBegin: (layerId, blockStartIndex, {required atEnd}) {
        onAddBegin?.call(layerId, blockStartIndex, atEnd);
        return true;
      },
      onAddUpdate: (count) => addCounts?.add(count),
      onAddEnd: () {},
      onAddCancel: () {},
      onEdgeModeSelected: (layerId, blockStartIndex, side, mode) =>
          modeSelections?.add((layerId, blockStartIndex, side, mode)),
    );
  }

  testWidgets('[+] mounts at a free run end and before a run with space; '
      'dragging [+] reports frame counts', (tester) async {
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
      onEdgeModeSelected: (_, _, _, _) {},
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

  testWidgets('the edge tag is ALWAYS visible (UI-R10 #1) and opens the '
      'N/H/R flyout on pointer-down; picking Hold reports the selection', (
    tester,
  ) async {
    final modeSelections =
        <(LayerId, int, TimelineRunEdgeSide, TimelineRunEdgeMode?)>[];
    await tester.pumpWidget(
      harness(
        layers: [plainLayer()],
        runEdit: recordingCallbacks(modeSelections: modeSelections),
      ),
    );

    const tagKey = ValueKey<String>('timeline-run-edge-tag-layer-a-f1-end');
    expect(
      find.byKey(tagKey),
      findsOneWidget,
      reason: 'the tag shows without hover, N state included',
    );
    // Start tags mirror on the second run.
    expect(
      find.byKey(
        const ValueKey<String>('timeline-run-edge-tag-layer-a-f2-start'),
      ),
      findsOneWidget,
    );

    // The flyout opens on POINTER DOWN (UI-R10 #2) — before any tap-up.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(tagKey)),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('run-edge-mode-none')),
      findsOneWidget,
      reason: 'menu is up while the pointer is still down',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('run-edge-mode-hold')));
    await tester.pumpAndSettle();

    expect(modeSelections.single, (
      const LayerId('layer-a'),
      0,
      TimelineRunEdgeSide.end,
      TimelineRunEdgeMode.hold,
    ));
  });

  testWidgets('a repeat edge keeps its cluster ON the authored run edge '
      '(UI-R10 #3), ghosts notwithstanding', (tester) async {
    final modeSelections =
        <(LayerId, int, TimelineRunEdgeSide, TimelineRunEdgeMode?)>[];
    await tester.pumpWidget(
      harness(
        layers: [repeatedLayer()],
        runEdit: recordingCallbacks(modeSelections: modeSelections),
      ),
    );

    const tagKey = ValueKey<String>('timeline-run-edge-tag-layer-r-rf-end');
    expect(find.byKey(tagKey), findsOneWidget);

    // The [+] chip stays too: ghost coverage never blocks authored adds.
    final addKey = find.byKey(
      const ValueKey<String>('timeline-run-add-end-layer-r-rf'),
    );
    expect(addKey, findsOneWidget);
    // Both sit at the run end (frame 2), NOT after the ghost tail (6).
    final edgeLeft = timelineCellGlobalRect(tester, 'layer-r', 2).left;
    expect(
      (tester.getTopLeft(addKey).dx - edgeLeft).abs(),
      lessThan(4),
      reason: 'cluster hugs the authored edge at frame 2',
    );

    await tester.tap(find.byKey(tagKey));
    await tester.pumpAndSettle();
    // Selecting None clears the edge.
    await tester.tap(find.byKey(const ValueKey<String>('run-edge-mode-none')));
    await tester.pumpAndSettle();

    expect(modeSelections.single, (
      const LayerId('layer-r'),
      0,
      TimelineRunEdgeSide.end,
      null,
    ));
  });

  testWidgets('ghosts render TEXT-ONLY (UI-R10 #11): repeat ghosts print '
      'cel names on plain cells, hold ghosts string ㅡ dashes', (
    tester,
  ) async {
    final holdLayer = rederiveRunBehaviors(
      Layer(
        id: const LayerId('layer-h'),
        name: 'H',
        frames: [
          Frame(id: const FrameId('hf'), duration: 1, strokes: const []),
        ],
        timeline: {
          0: const TimelineExposure.drawing(FrameId('hf'), length: 2),
        },
        runBehaviors: const [
          TimelineRunBehavior(
            anchorFrameId: FrameId('hf'),
            side: TimelineRunEdgeSide.end,
            mode: TimelineRunEdgeMode.hold,
          ),
        ],
      ),
      cutFrameCount: 6,
    );
    await tester.pumpWidget(
      harness(
        layers: [repeatedLayer(), holdLayer],
        runEdit: recordingCallbacks(),
      ),
    );

    // Repeat ghosts: name glyph at ghost block starts, nothing between,
    // and NO block chrome (no radius — the cell paints as empty paper).
    expect(timelineCellModel(tester, 'layer-r', 2).glyph, '○');
    expect(timelineCellModel(tester, 'layer-r', 3).glyph, '');
    expect(timelineCellModel(tester, 'layer-r', 4).glyph, '○');
    expect(
      timelineCellDecoration(tester, 'layer-r', 2).borderRadius,
      isNull,
      reason: 'ghost cells carry no block visual',
    );

    // Hold ghosts: ㅡ dashes through the whole span.
    for (var frame = 2; frame < 6; frame += 1) {
      expect(
        timelineCellModel(tester, 'layer-h', frame).glyph,
        'ㅡ',
        reason: 'frame $frame',
      );
      expect(timelineCellModel(tester, 'layer-h', frame).ghost, isTrue);
    }
    expect(
      timelineCellDecoration(tester, 'layer-h', 2).borderRadius,
      isNull,
    );
  });

  testWidgets('a selection-scoped repeat pattern draws its span outline '
      '(UI-R10 #5)', (tester) async {
    final patterned = rederiveRunBehaviors(
      Layer(
        id: const LayerId('layer-p'),
        name: 'P',
        frames: [
          Frame(id: const FrameId('p1'), duration: 1, strokes: const []),
          Frame(id: const FrameId('p2'), duration: 1, strokes: const []),
        ],
        timeline: {
          0: const TimelineExposure.drawing(FrameId('p1'), length: 1),
          1: const TimelineExposure.drawing(FrameId('p2'), length: 1),
        },
        runBehaviors: const [
          TimelineRunBehavior(
            anchorFrameId: FrameId('p2'),
            side: TimelineRunEdgeSide.end,
            mode: TimelineRunEdgeMode.repeat,
            patternAnchorFrameId: FrameId('p2'),
          ),
        ],
      ),
      cutFrameCount: 6,
    );
    await tester.pumpWidget(
      harness(layers: [patterned], runEdit: recordingCallbacks()),
    );

    final outline = find.byKey(
      const ValueKey<String>('timeline-run-pattern-layer-p-p2-end'),
    );
    expect(outline, findsOneWidget);
    // The span wraps the pattern block [1,2) only (48px harness cells).
    expect(tester.getSize(outline).width, 48);
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

    bool ghostAt(int index) =>
        timelineCellModel(tester, 'layer-r', index).ghost;
    expect(ghostAt(0), isFalse);
    expect(ghostAt(1), isFalse);
    expect(ghostAt(2), isTrue);
    expect(ghostAt(3), isTrue);
    expect(ghostAt(4), isTrue);
    expect(ghostAt(6), isFalse, reason: 'the tail stops at cut frame 6');

    // Grips: only the SOURCE block's two — the ghost blocks carry none.
    expect(find.byType(TimelineBlockEdgeGrip), findsNWidgets(2));
  });
}
