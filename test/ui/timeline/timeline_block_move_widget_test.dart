import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_frame_range.dart';

import 'timeline_cell_probe.dart';
import 'package:quick_animaker_v2/src/ui/input/app_input_settings.dart';
import 'package:quick_animaker_v2/src/ui/theme/app_theme.dart' show AppColors;
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_drag_preview.dart';
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

  testWidgets('EVERY layer row mounts the range gesture layer — SE, camera '
      'and instruction rows select too (UI-R20 #2)', (tester) async {
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    final selectUpdates = <(LayerId, int, int)>[];

    await tester.pumpWidget(
      harness(
        layers: [
          blockLayer('layer-a'),
          blockLayer('se-1').copyWith(kind: LayerKind.se),
          blockLayer('cam-1').copyWith(kind: LayerKind.camera),
          blockLayer('instr-1').copyWith(kind: LayerKind.instruction),
        ],
        cursor: cursor,
        rangeHooks: hooks(
          selection: selection,
          onSelectUpdate: (layerId, anchor, head) =>
              selectUpdates.add((layerId, anchor, head)),
        ),
      ),
    );

    for (final id in ['layer-a', 'se-1', 'cam-1', 'instr-1']) {
      expect(
        find.byKey(ValueKey<String>('timeline-range-gesture-$id')),
        findsOneWidget,
        reason: '$id must carry the gesture layer',
      );
    }

    // An SE-ORIGIN drag reports select updates with the SE row's id (the
    // reported bug: selection could extend INTO SE but never start
    // there). Start on an EMPTY cell (past the block at [0,4) — the SE
    // writing overlays sit above the gesture layer over the block span).
    final seLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-se-1'),
    );
    final gesture = await tester.startGesture(
      tester.getTopLeft(seLayer) + const Offset(24 + 5 * 48, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(96, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(selectUpdates, isNotEmpty);
    expect(selectUpdates.last.$1, const LayerId('se-1'));
  });

  testWidgets('with touch-timeline-scroll ON, a TOUCH pan no longer '
      'selects (UI-R22 #6: the scroll owns touch then)', (tester) async {
    AppInput.settings.value = const AppInputSettings(touchTimelineScroll: true);
    addTearDown(() {
      // Back to the CORPUS baseline (flutter_test_config pins OFF; the
      // class default is ON since UI-R22F).
      AppInput.settings.value = const AppInputSettings(
        touchTimelineScroll: false,
      );
    });
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    final selectUpdates = <(LayerId, int, int)>[];

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
    final gesture = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24 + 5 * 48, 26),
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveBy(const Offset(96, 0));
    await gesture.up();
    await tester.pump();
    expect(
      selectUpdates,
      isEmpty,
      reason: 'touch belongs to the scroll while the toggle is ON',
    );
  });

  testWidgets('a SLOW SMALL pen drag SELECTS — it must not lose the arena '
      'to the scroll (UI-R22F #2: eager slop, no fast/slow split)', (
    tester,
  ) async {
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    final selectUpdates = <(LayerId, int, int)>[];

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

    List<double> scrollOffsets() => tester
        .stateList<ScrollableState>(
          find.byType(Scrollable, skipOffstage: false),
        )
        .map((state) => state.position.pixels)
        .toList();
    final offsetsBefore = scrollOffsets();

    // 6 × 4px stylus creeps = 24px total: past the viewport recognizers'
    // ~18px hit slop but UNDER the old ~36px pan slop — exactly the drag
    // the horizontal scroll used to steal (fast big drags selected, slow
    // small ones scrolled: the "random" split this pins away).
    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-layer-a'),
    );
    final gesture = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24 + 5 * 48, 26),
      kind: PointerDeviceKind.stylus,
    );
    for (var step = 0; step < 6; step += 1) {
      await gesture.moveBy(const Offset(4, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    expect(
      selectUpdates,
      isNotEmpty,
      reason: 'the slow pen drag must range-select, never scroll',
    );
    expect(selectUpdates.last.$1, const LayerId('layer-a'));
    expect(
      scrollOffsets(),
      offsetsBefore,
      reason: 'no viewport may have consumed the pen drag',
    );
  });

  testWidgets('a drag on a LANE BAND selects on THAT (layer, lane) — the '
      'lane-scoped domain (UI-R23 #3 part 2, superseding the R22-C '
      'owner-layer fallback) — and selected keys ring accent 1', (
    tester,
  ) async {
    final cursor = ValueNotifier<int>(0);
    final laneSelection = ValueNotifier<TimelineLaneSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(laneSelection.dispose);
    final selectUpdates = <(LayerId, String, int, int)>[];

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
            onSelectFrame: (_) {},
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            expandedLaneLayerIds: {const LayerId('layer-a')},
            lanesForLayer: (_) => [
              const PropertyLaneRow(
                laneId: 'position',
                label: 'Position',
                keyedFrames: {2},
              ),
            ],
            laneRange: TimelineLaneRangeCallbacks(
              selection: laneSelection,
              onSelectUpdate: (layerId, laneId, anchor, head) {
                selectUpdates.add((layerId, laneId, anchor, head));
                laneSelection.value = TimelineLaneSelection(
                  layerId: layerId,
                  laneId: laneId,
                  startIndex: anchor < head ? anchor : head,
                  endIndexExclusive: (anchor > head ? anchor : head) + 1,
                );
              },
              onTapClear: () => laneSelection.value = null,
              onMoveBegin: () => false,
              onMoveUpdate: (_) {},
              onMoveEnd: () {},
              onMoveCancel: () {},
            ),
            metrics: const TimelineGridMetrics(
              frameCellWidth: 48,
              layerRowHeight: 52,
            ),
          ),
        ),
      ),
    );

    final laneGesture = find.byKey(
      const ValueKey<String>('timeline-lane-range-gesture-layer-a-position'),
    );
    expect(laneGesture, findsOneWidget);

    // Drag on band cells: selects on the LANE domain (layer-a, position).
    final gesture = await tester.startGesture(
      tester.getTopLeft(laneGesture) + const Offset(5 * 48 + 24, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(96, 0));
    await gesture.up();
    await tester.pump();

    expect(selectUpdates, isNotEmpty);
    expect(selectUpdates.last.$1, const LayerId('layer-a'));
    expect(selectUpdates.last.$2, 'position');
    expect(selectUpdates.first.$3, 5, reason: 'anchor = the pressed cell');

    // Selected key markers ring in ACCENT 1 (UI-R23 #4): the LANE
    // selection covering the key at frame 2 flips the marker's border to
    // the thin accent-1 stroke; the wash overlay marks the span.
    Border markerBorder() {
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(
                const ValueKey<String>('timeline-lane-key-layer-a-position-2'),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).border! as Border;
    }

    laneSelection.value = null;
    await tester.pump();
    expect(markerBorder().top.color, isNot(AppColors.accent));
    expect(
      find.byKey(
        const ValueKey<String>('timeline-lane-selection-layer-a-position'),
      ),
      findsNothing,
    );
    laneSelection.value = const TimelineLaneSelection(
      layerId: LayerId('layer-a'),
      laneId: 'position',
      startIndex: 0,
      endIndexExclusive: 4,
    );
    await tester.pump();
    expect(markerBorder().top.color, AppColors.accent);
    expect(markerBorder().top.width, moreOrLessEquals(4 / 3));
    expect(
      find.byKey(
        const ValueKey<String>('timeline-lane-selection-layer-a-position'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the gesture layer SURVIVES mid-drag preview rebuilds that '
      'change the row\'s overlay count (UI-R22 #1: the SE row-change '
      'used to commit the move under the pointer)', (tester) async {
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(
      const TimelineFrameRangeSelection(
        layerId: LayerId('se-1'),
        startIndex: 0,
        endIndexExclusive: 4,
      ),
    );
    final dragPreview = ValueNotifier<TimelineDragPreview?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    addTearDown(dragPreview.dispose);
    var ended = 0;
    final se1 = blockLayer('se-1').copyWith(kind: LayerKind.se);
    final se2 = blockLayer('se-2', start: 10).copyWith(kind: LayerKind.se);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerTimelineGrid(
            layers: [se1, se2],
            activeLayerId: const LayerId('se-1'),
            frameCursor: cursor,
            playbackFrameCount: 24,
            dragPreview: dragPreview,
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: (_) {},
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            rangeHooks: TimelineFrameRangeHooks(
              selection: selection,
              onSelectUpdate: (_, _, _, {headLayerId}) {},
              onClear: () {},
              move: TimelineRangeMoveCallbacks(
                onBegin: () => true,
                // The session's row-change preview: the SOURCE row loses
                // its blocks — its SE overlays (labels/marks) vanish, so
                // the row's Stack children count CHANGES mid-drag.
                onUpdate: ({required frameDelta, targetLayerId}) {
                  dragPreview.value = BlockMoveDragPreview(
                    previewLayers: {
                      const LayerId('se-1'): se1.copyWith(
                        frames: const [],
                        timeline: const {},
                      ),
                      const LayerId('se-2'): se2,
                    },
                  );
                },
                onEnd: () => ended += 1,
                onCancel: () {},
              ),
            ),
            metrics: const TimelineGridMetrics(
              frameCellWidth: 48,
              layerRowHeight: 52,
            ),
          ),
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-se-1'),
    );
    // Start a MOVE inside the selection, drag toward the sibling row.
    final gesture = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24 + 48, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, 52));
    await tester.pump();
    await tester.pump();
    expect(
      ended,
      0,
      reason: 'the preview rebuild must NOT commit the move mid-drag',
    );

    await gesture.up();
    await tester.pump();
    expect(ended, 1, reason: 'the release commits exactly once');
  });

  testWidgets('a press INSIDE the selection never seeks — sparse rows '
      'follow the painter rule now (UI-R22 #2)', (tester) async {
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(
      const TimelineFrameRangeSelection(
        layerId: LayerId('se-1'),
        startIndex: 0,
        endIndexExclusive: 4,
      ),
    );
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    final seeks = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerTimelineGrid(
            layers: [blockLayer('se-1').copyWith(kind: LayerKind.se)],
            activeLayerId: const LayerId('se-1'),
            frameCursor: cursor,
            playbackFrameCount: 24,
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: seeks.add,
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            rangeHooks: hooks(selection: selection),
            metrics: const TimelineGridMetrics(
              frameCellWidth: 48,
              layerRowHeight: 52,
            ),
          ),
        ),
      ),
    );

    final gestureLayer = find.byKey(
      const ValueKey<String>('timeline-range-gesture-se-1'),
    );
    // Press INSIDE the selected span (cell 1): no seek.
    var gesture = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24 + 48, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();
    expect(seeks, isEmpty, reason: 'inside the selection = a move press');

    // Press OUTSIDE (cell 6): seeks as always.
    gesture = await tester.startGesture(
      tester.getTopLeft(gestureLayer) + const Offset(24 + 6 * 48, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pump();
    expect(seeks, [6]);
  });

  testWidgets('with touch-timeline-scroll ON, a TOUCH press never SEEKS '
      '(UI-R23 feedback #2: the first scroll touch kept moving the '
      'playhead) — painter and sparse rows alike; pen/mouse still seek '
      'and OFF keeps touch-as-pen', (tester) async {
    AppInput.settings.value = const AppInputSettings(touchTimelineScroll: true);
    addTearDown(() {
      AppInput.settings.value = const AppInputSettings(
        touchTimelineScroll: false,
      );
    });
    final cursor = ValueNotifier<int>(0);
    final selection = ValueNotifier<TimelineFrameRangeSelection?>(null);
    addTearDown(cursor.dispose);
    addTearDown(selection.dispose);
    final seeks = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayerTimelineGrid(
            layers: [
              blockLayer('anim-1'), // painter row
              blockLayer('se-1').copyWith(kind: LayerKind.se), // sparse row
            ],
            activeLayerId: const LayerId('anim-1'),
            frameCursor: cursor,
            playbackFrameCount: 24,
            exposureStateForLayer: stateFor,
            onSelectLayer: (_) {},
            onSelectFrame: seeks.add,
            onAddLayer: () {},
            onToggleLayerVisibility: (_) {},
            onLayerOpacityChanged: (_, _) {},
            onToggleLayerTimesheet: (_) {},
            onLayerMarkSelected: (_, _) {},
            rangeHooks: hooks(selection: selection),
            metrics: const TimelineGridMetrics(
              frameCellWidth: 48,
              layerRowHeight: 52,
            ),
          ),
        ),
      ),
    );

    Future<void> press(String layerId, {required PointerDeviceKind kind}) {
      final layerGesture = find.byKey(
        ValueKey<String>('timeline-range-gesture-$layerId'),
      );
      return tester
          .startGesture(
            tester.getTopLeft(layerGesture) + const Offset(24 + 2 * 48, 26),
            kind: kind,
          )
          .then((g) => g.up())
          .then((_) => tester.pump());
    }

    // TOUCH press = pure scroll intent: no seek on either row shape.
    await press('anim-1', kind: PointerDeviceKind.touch);
    await press('se-1', kind: PointerDeviceKind.touch);
    expect(seeks, isEmpty, reason: 'touch must not move the playhead');

    // Pen and mouse keep the instant seek.
    await press('anim-1', kind: PointerDeviceKind.stylus);
    await press('se-1', kind: PointerDeviceKind.mouse);
    expect(seeks, [2, 2]);

    // Toggle OFF (touch-as-pen, R17-⑥): touch seeks again.
    AppInput.settings.value = const AppInputSettings(
      touchTimelineScroll: false,
    );
    await press('anim-1', kind: PointerDeviceKind.touch);
    expect(seeks, [2, 2, 2]);
  });

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
