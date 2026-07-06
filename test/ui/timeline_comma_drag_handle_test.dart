import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_cells_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

/// Comma-drag: the drag handle at the trailing edge of the active layer's
/// selected exposure block, shared by the horizontal timeline and X-sheet.
void main() {
  const handleKey = ValueKey<String>(
    'timeline-exposure-comma-drag-handle-layer-a',
  );

  // A two-frame drawing block on frames [0, 2).
  TimelineCellExposureState blockState(Layer layer, int frameIndex) {
    if (frameIndex == 0) {
      return TimelineCellExposureState.drawingStart;
    }
    if (frameIndex == 1) {
      return TimelineCellExposureState.heldExposure;
    }
    return TimelineCellExposureState.empty;
  }

  group('TimelineFrameCellsRow comma-drag handle', () {
    testWidgets('renders at the block end edge for the active layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _rowHarness(
          layer: _layer('layer-a'),
          active: true,
          exposureStateForLayer: blockState,
          onTryIncreaseExposure: () => true,
          onTryDecreaseExposure: () => true,
        ),
      );

      final handleFinder = find.byKey(handleKey);
      expect(handleFinder, findsOneWidget);
      // End edge of frames [0, 2) at the default 48px cell width is x = 96;
      // the 14px hit strip straddles it.
      expect(tester.getTopLeft(handleFinder).dx, 96 - 7);
      expect(tester.getSize(handleFinder).width, 14);
      expect(
        tester.getSize(handleFinder).height,
        TimelineGridMetrics.defaults.layerRowHeight,
      );
    });

    testWidgets('does not render for an inactive layer', (tester) async {
      await tester.pumpWidget(
        _rowHarness(
          layer: _layer('layer-a'),
          active: false,
          exposureStateForLayer: blockState,
          onTryIncreaseExposure: () => true,
          onTryDecreaseExposure: () => true,
        ),
      );

      expect(find.byKey(handleKey), findsNothing);
    });

    testWidgets('does not render on the camera layer', (tester) async {
      await tester.pumpWidget(
        _rowHarness(
          layer: _layer('layer-a', kind: LayerKind.camera),
          active: true,
          exposureStateForLayer: blockState,
          onTryIncreaseExposure: () => true,
          onTryDecreaseExposure: () => true,
        ),
      );

      expect(find.byKey(handleKey), findsNothing);
    });

    testWidgets('does not render when step callbacks are absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _rowHarness(
          layer: _layer('layer-a'),
          active: true,
          exposureStateForLayer: blockState,
        ),
      );

      expect(find.byKey(handleKey), findsNothing);
    });

    testWidgets(
      'does not render when the block is truncated by the visible window',
      (tester) async {
        await tester.pumpWidget(
          _rowHarness(
            layer: _layer('layer-a'),
            active: true,
            // The block continues past every queried frame, so its true end
            // lies beyond the window.
            exposureStateForLayer: (layer, frameIndex) => frameIndex == 0
                ? TimelineCellExposureState.drawingStart
                : TimelineCellExposureState.heldExposure,
            onTryIncreaseExposure: () => true,
            onTryDecreaseExposure: () => true,
          ),
        );

        expect(find.byKey(handleKey), findsNothing);
      },
    );
  });

  group('LayerTimelineGrid comma-drag', () {
    testWidgets('dragging the handle along the frame axis steps exposure', (
      tester,
    ) async {
      var increases = 0;
      var decreases = 0;

      await tester.pumpWidget(
        _horizontalGridHarness(
          layer: _layer('layer-a'),
          exposureStateForLayer: blockState,
          onTryIncreaseExposure: () {
            increases += 1;
            return true;
          },
          onTryDecreaseExposure: () {
            decreases += 1;
            return true;
          },
        ),
      );

      final handleFinder = find.byKey(handleKey);
      expect(handleFinder, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(handleFinder),
      );
      // Pass the touch slop, then cross exactly one cell right and back.
      await gesture.moveBy(const Offset(19, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(48, 0));
      await tester.pump();
      expect(increases, 1);
      expect(decreases, 0);

      await gesture.moveBy(const Offset(-48, 0));
      await tester.pump();
      expect(decreases, 1);

      await gesture.up();
      await tester.pump();
      expect(increases, 1);
      expect(decreases, 1);
    });
  });

  group('XSheetTimelineGrid comma-drag', () {
    testWidgets('dragging the handle along the frame axis steps exposure', (
      tester,
    ) async {
      var increases = 0;
      var decreases = 0;

      await tester.pumpWidget(
        _xsheetGridHarness(
          layer: _layer('layer-a'),
          exposureStateForLayer: blockState,
          onTryIncreaseExposure: () {
            increases += 1;
            return true;
          },
          onTryDecreaseExposure: () {
            decreases += 1;
            return true;
          },
        ),
      );

      final handleFinder = find.byKey(handleKey);
      expect(handleFinder, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(handleFinder),
      );
      // The X-sheet frame axis runs vertically; one frame row is 36px.
      await gesture.moveBy(const Offset(0, 19));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 36));
      await tester.pump();
      expect(increases, 1);
      expect(decreases, 0);

      await gesture.moveBy(const Offset(0, -36));
      await tester.pump();
      expect(decreases, 1);

      await gesture.up();
      await tester.pump();
      expect(increases, 1);
      expect(decreases, 1);
    });
  });
}

Layer _layer(String id, {LayerKind kind = LayerKind.animation}) {
  return Layer(id: LayerId(id), name: 'Layer $id', frames: const [], kind: kind);
}

Widget _rowHarness({
  required Layer layer,
  required bool active,
  required TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  bool Function()? onTryIncreaseExposure,
  bool Function()? onTryDecreaseExposure,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Material(
        child: TimelineFrameCellsRow(
          layer: layer,
          active: active,
          currentFrameIndex: 0,
          playbackFrameCount: 24,
          frameStartIndex: 0,
          frameEndIndexExclusive: 6,
          leadingFrameSpacerWidth: 0,
          trailingFrameSpacerWidth: 0,
          metrics: TimelineGridMetrics.defaults,
          exposureStateForLayer: exposureStateForLayer,
          onSelectLayer: (_) {},
          onSelectFrame: (_) {},
          onTryIncreaseExposure: onTryIncreaseExposure,
          onTryDecreaseExposure: onTryDecreaseExposure,
        ),
      ),
    ),
  );
}

Widget _horizontalGridHarness({
  required Layer layer,
  required TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  required bool Function() onTryIncreaseExposure,
  required bool Function() onTryDecreaseExposure,
}) {
  return MaterialApp(
    home: Scaffold(
      body: LayerTimelineGrid(
        layers: [layer],
        activeLayerId: layer.id,
        currentFrameIndex: 0,
        playbackFrameCount: 24,
        exposureStateForLayer: exposureStateForLayer,
        onSelectLayer: (_) {},
        onSelectFrame: (_) {},
        onAddLayer: () {},
        onToggleLayerVisibility: (_) {},
        onLayerOpacityChanged: (_, _) {},
        onTryIncreaseExposure: onTryIncreaseExposure,
        onTryDecreaseExposure: onTryDecreaseExposure,
      ),
    ),
  );
}

Widget _xsheetGridHarness({
  required Layer layer,
  required TimelineCellExposureState Function(Layer layer, int frameIndex)
  exposureStateForLayer,
  required bool Function() onTryIncreaseExposure,
  required bool Function() onTryDecreaseExposure,
}) {
  return MaterialApp(
    home: Scaffold(
      body: XSheetTimelineGrid(
        layers: [layer],
        activeLayerId: layer.id,
        currentFrameIndex: 0,
        frameCount: 24,
        exposureStateForLayer: exposureStateForLayer,
        onSelectLayer: (_) {},
        onSelectFrame: (_) {},
        onAddLayer: () {},
        onToggleLayerVisibility: (_) {},
        onLayerOpacityChanged: (_, _) {},
        onTryIncreaseExposure: onTryIncreaseExposure,
        onTryDecreaseExposure: onTryDecreaseExposure,
      ),
    ),
  );
}
