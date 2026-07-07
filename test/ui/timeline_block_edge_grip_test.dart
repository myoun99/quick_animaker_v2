import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/timeline_coverage.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_exposure_comma_drag_policy.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_cells_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

/// TVPaint-style comma grips: every drawing block shows inset bars inside
/// BOTH edges, in both orientations; dragging reports cumulative frame
/// deltas.
void main() {
  group('comma drag pixel policy', () {
    test('rounds at cell midpoints, both directions', () {
      expect(commaDragFrameDelta(accumulatedDelta: 20, frameCellExtent: 48), 0);
      expect(commaDragFrameDelta(accumulatedDelta: 25, frameCellExtent: 48), 1);
      expect(
        commaDragFrameDelta(accumulatedDelta: 100, frameCellExtent: 48),
        2,
      );
      expect(
        commaDragFrameDelta(accumulatedDelta: -25, frameCellExtent: 48),
        -1,
      );
    });
  });

  group('horizontal row grips', () {
    testWidgets('every block gets a start and an end grip', (tester) async {
      await tester.pumpWidget(_rowHarness(layer: _twoBlockLayer()));

      expect(_gripFinder('start', 0), findsOneWidget);
      expect(_gripFinder('end', 0), findsOneWidget);
      expect(_gripFinder('start', 1), findsOneWidget);
      expect(_gripFinder('end', 1), findsOneWidget);
    });

    testWidgets('grips sit inside the block edges', (tester) async {
      await tester.pumpWidget(_rowHarness(layer: _twoBlockLayer()));

      // Block [0,2) at 48px cells: start hit strip begins at the block's
      // left edge, end strip ends at its right edge (x = 96).
      expect(tester.getTopLeft(_gripFinder('start', 0)).dx, 0);
      expect(tester.getBottomRight(_gripFinder('end', 0)).dx, 96);
    });

    testWidgets('camera layers show no grips', (tester) async {
      await tester.pumpWidget(
        _rowHarness(layer: _twoBlockLayer(kind: LayerKind.camera)),
      );

      expect(_anyGripFinder(), findsNothing);
    });

    testWidgets('no grips without commaDrag callbacks', (tester) async {
      await tester.pumpWidget(
        _rowHarness(layer: _twoBlockLayer(), commaDrag: null),
      );

      expect(_anyGripFinder(), findsNothing);
    });

    testWidgets('dragging the end grip reports cumulative frame deltas', (
      tester,
    ) async {
      final log = _DragLog();
      await tester.pumpWidget(
        _rowHarness(layer: _twoBlockLayer(), commaDrag: log.callbacks),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_gripFinder('end', 0)),
      );
      await gesture.moveBy(const Offset(19, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(48, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(48, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-96, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(log.begins, [
        (const LayerId('layer-a'), 0, TimelineBlockEdge.end),
      ]);
      expect(log.updates, [1, 2, 0]);
      expect(log.ends, 1);
      expect(log.cancels, 0);
    });

    testWidgets('dragging the start grip reports the start edge', (
      tester,
    ) async {
      final log = _DragLog();
      await tester.pumpWidget(
        _rowHarness(layer: _twoBlockLayer(), commaDrag: log.callbacks),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_gripFinder('start', 1)),
      );
      await gesture.moveBy(const Offset(-19, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-48, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(log.begins, [
        (const LayerId('layer-a'), 4, TimelineBlockEdge.start),
      ]);
      expect(log.updates, [-1]);
      expect(log.ends, 1);
    });

    testWidgets('a rejected begin reports nothing further', (tester) async {
      final log = _DragLog(acceptBegin: false);
      await tester.pumpWidget(
        _rowHarness(layer: _twoBlockLayer(), commaDrag: log.callbacks),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(_gripFinder('end', 0)),
      );
      await gesture.moveBy(const Offset(67, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(log.begins.length, 1);
      expect(log.updates, isEmpty);
      expect(log.ends, 0);
    });
  });

  group('X-sheet grips', () {
    testWidgets('grips render and drag along the vertical frame axis', (
      tester,
    ) async {
      final log = _DragLog();
      await tester.pumpWidget(
        _xsheetHarness(layer: _twoBlockLayer(), commaDrag: log.callbacks),
      );

      expect(_gripFinder('start', 0), findsOneWidget);
      expect(_gripFinder('end', 1), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(_gripFinder('end', 0)),
      );
      // X-sheet frame rows are 36px tall.
      await gesture.moveBy(const Offset(0, 19));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 36));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(log.begins, [
        (const LayerId('layer-a'), 0, TimelineBlockEdge.end),
      ]);
      expect(log.updates, [1]);
      expect(log.ends, 1);
    });
  });
}

Finder _gripFinder(String edge, int ordinal) => find.byKey(
  ValueKey<String>('timeline-block-edge-grip-$edge-layer-a-$ordinal'),
);

Finder _anyGripFinder() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('timeline-block-edge-grip-');
});

class _DragLog {
  _DragLog({this.acceptBegin = true});

  final bool acceptBegin;
  final begins = <(LayerId, int, TimelineBlockEdge)>[];
  final updates = <int>[];
  var ends = 0;
  var cancels = 0;

  late final callbacks = TimelineCommaDragCallbacks(
    onBegin: (layerId, blockStartIndex, edge) {
      begins.add((layerId, blockStartIndex, edge));
      return acceptBegin;
    },
    onUpdate: updates.add,
    onEnd: () => ends += 1,
    onCancel: () => cancels += 1,
  );
}

/// Blocks [0,2) and [4,6) with an X gap between.
Layer _twoBlockLayer({LayerKind kind = LayerKind.animation}) {
  return Layer(
    id: const LayerId('layer-a'),
    name: 'A',
    kind: kind,
    frames: [
      Frame(id: const FrameId('f1'), duration: 1, strokes: const []),
      Frame(id: const FrameId('f2'), duration: 1, strokes: const []),
    ],
    timeline: {
      0: TimelineExposure.drawing(const FrameId('f1'), length: 2),
      4: TimelineExposure.drawing(const FrameId('f2'), length: 2),
    },
  );
}

TimelineCellExposureState _stateFor(Layer layer, int frameIndex) {
  if (layer.timeline[frameIndex]?.isDrawing ?? false) {
    return TimelineCellExposureState.drawingStart;
  }
  if (coveringDrawingBlockAt(layer.timeline, frameIndex) != null) {
    return TimelineCellExposureState.held;
  }
  return TimelineCellExposureState.uncovered;
}

final _defaultCallbacks = TimelineCommaDragCallbacks(
  onBegin: (_, _, _) => true,
  onUpdate: (_) {},
  onEnd: () {},
  onCancel: () {},
);

Widget _rowHarness({required Layer layer, Object? commaDrag = const _Unset()}) {
  return MaterialApp(
    home: Scaffold(
      body: Material(
        child: TimelineFrameCellsRow(
          layer: layer,
          active: true,
          currentFrameIndex: 0,
          playbackFrameCount: 24,
          frameStartIndex: 0,
          frameEndIndexExclusive: 8,
          leadingFrameSpacerWidth: 0,
          trailingFrameSpacerWidth: 0,
          metrics: TimelineGridMetrics.defaults,
          exposureStateForLayer: _stateFor,
          onSelectLayer: (_) {},
          onSelectFrame: (_) {},
          commaDrag: commaDrag is _Unset
              ? _defaultCallbacks
              : commaDrag as TimelineCommaDragCallbacks?,
        ),
      ),
    ),
  );
}

Widget _xsheetHarness({
  required Layer layer,
  required TimelineCommaDragCallbacks commaDrag,
}) {
  return MaterialApp(
    home: Scaffold(
      body: XSheetTimelineGrid(
        layers: [layer],
        activeLayerId: layer.id,
        currentFrameIndex: 0,
        frameCount: 24,
        exposureStateForLayer: _stateFor,
        onSelectLayer: (_) {},
        onSelectFrame: (_) {},
        onAddLayer: () {},
        onToggleLayerVisibility: (_) {},
        onLayerOpacityChanged: (_, _) {},
        onToggleLayerTimesheet: (_) {},
        onLayerMarkSelected: (_, _) {},
        commaDrag: commaDrag,
      ),
    ),
  );
}

class _Unset {
  const _Unset();
}
