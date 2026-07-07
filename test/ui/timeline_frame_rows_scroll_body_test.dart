import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/property_lane_model.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_cells_row.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_frame_rows_scroll_body.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';

void main() {
  group('TimelineFrameRowsScrollBody', () {
    testWidgets('exposes the stable body key exactly once', (tester) async {
      await tester.pumpWidget(_body(layers: [_layer('layer-a')]));

      expect(_bodyFinder, findsOneWidget);
      expect(
        _stableKeyFinder('timeline-frame-rows-scroll-body'),
        findsOneWidget,
      );
    });

    testWidgets('renders one frame row per provided layer', (tester) async {
      final layers = [_layer('layer-a'), _layer('layer-b'), _layer('layer-c')];

      await tester.pumpWidget(_body(layers: layers));

      expect(find.byType(TimelineFrameCellsRow), findsNWidgets(layers.length));
      for (final layer in layers) {
        expect(
          find.byKey(ValueKey<String>('timeline-frame-row-area-${layer.id}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('preserves provided layer order', (tester) async {
      final layers = [_layer('layer-a'), _layer('layer-b'), _layer('layer-c')];

      await tester.pumpWidget(_body(layers: layers));

      final firstTop = tester.getTopLeft(_rowFinder(layers[0])).dy;
      final secondTop = tester.getTopLeft(_rowFinder(layers[1])).dy;
      final thirdTop = tester.getTopLeft(_rowFinder(layers[2])).dy;

      expect(firstTop, lessThan(secondTop));
      expect(secondTop, lessThan(thirdTop));
    });

    testWidgets('renders frame cells for the visible frame range', (
      tester,
    ) async {
      const layerId = LayerId('layer-a');

      await tester.pumpWidget(
        _body(
          layers: [_layer(layerId.value)],
          frameStartIndex: 0,
          frameEndIndexExclusive: 3,
        ),
      );

      expect(_cellFinder(layerId, 0), findsOneWidget);
      expect(_cellFinder(layerId, 1), findsOneWidget);
      expect(_cellFinder(layerId, 2), findsOneWidget);
      expect(_cellFinder(layerId, 3), findsNothing);
    });

    testWidgets('renders empty layer placeholder without rows or cells', (
      tester,
    ) async {
      const metrics = TimelineGridMetrics(layerRowHeight: 64);
      const totalFrameContentWidth = 320.0;

      await tester.pumpWidget(
        _body(
          layers: const [],
          metrics: metrics,
          totalFrameContentWidth: totalFrameContentWidth,
        ),
      );

      expect(_bodyFinder, findsOneWidget);
      expect(_keyStartingWith('timeline-frame-row-area-'), findsNothing);
      expect(_keyStartingWith('timeline-cell-'), findsNothing);
      expect(
        find.descendant(
          of: _bodyFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.width == totalFrameContentWidth &&
                widget.height == metrics.layerRowHeight,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('forwards active layer state to downstream cells', (
      tester,
    ) async {
      const activeLayerId = LayerId('layer-active');

      await tester.pumpWidget(
        _body(
          layers: [_layer(activeLayerId.value), _layer('layer-inactive')],
          activeLayerId: activeLayerId,
          currentFrameIndex: 1,
          exposureStateForLayer: (layer, frameIndex) => frameIndex == 1
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.uncovered,
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'timeline-selected-exposure-range-outline-layer-active',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('timeline-selected-cell')),
        findsOneWidget,
      );
    });

    testWidgets('forwards layer and frame selection callbacks from cells', (
      tester,
    ) async {
      final layer = _layer('layer-a');
      LayerId? selectedLayerId;
      int? selectedFrameIndex;

      await tester.pumpWidget(
        _body(
          layers: [layer],
          onSelectLayer: (layerId) => selectedLayerId = layerId,
          onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex,
        ),
      );

      await tester.tap(_cellFinder(layer.id, 1));

      expect(selectedLayerId, layer.id);
      expect(selectedFrameIndex, 1);
    });

    testWidgets('forwards exposure, mark, and frame name providers to cells', (
      tester,
    ) async {
      final layer = _layer('layer-a');

      await tester.pumpWidget(
        _body(
          layers: [layer],
          frameStartIndex: 0,
          frameEndIndexExclusive: 3,
          exposureStateForLayer: (_, frameIndex) => frameIndex == 2
              ? TimelineCellExposureState.markUncovered
              : TimelineCellExposureState.drawingStart,
          frameNameForLayer: (_, frameIndex) =>
              frameIndex == 1 ? 'Pose A' : null,
        ),
      );

      expect(find.text('○'), findsOneWidget);
      expect(find.text('Pose A'), findsOneWidget);
      expect(find.text('●'), findsOneWidget);
    });
  });
}

Finder get _bodyFinder =>
    find.byKey(const ValueKey<String>('timeline-frame-rows-scroll-body'));

Finder _stableKeyFinder(String key) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> && widget.key == ValueKey<String>(key),
);

Finder _keyStartingWith(String prefix) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith(prefix);
});

Finder _rowFinder(Layer layer) =>
    find.byKey(ValueKey<String>('timeline-frame-row-area-${layer.id}'));

Finder _cellFinder(LayerId layerId, int frameIndex) =>
    find.byKey(ValueKey<String>('timeline-cell-$layerId-$frameIndex'));

Widget _body({
  required List<Layer> layers,
  LayerId? activeLayerId,
  int currentFrameIndex = 0,
  int playbackFrameCount = 24,
  int frameStartIndex = 0,
  int frameEndIndexExclusive = 3,
  double leadingFrameSpacerWidth = 0,
  double trailingFrameSpacerWidth = 0,
  double totalFrameContentWidth = 144,
  TimelineGridMetrics metrics = TimelineGridMetrics.defaults,
  TimelineCellExposureState Function(Layer layer, int frameIndex)?
  exposureStateForLayer,
  String? Function(Layer layer, int frameIndex)? frameNameForLayer,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<int>? onSelectFrame,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Material(
        child: TimelineFrameRowsScrollBody(
          layers: layers,
          rows: buildTimelineDisplayRows(
            layers: layers,
            expandedLayerIds: const {},
            lanesForLayer: (_) => const [],
          ),
          activeLayerId: activeLayerId,
          currentFrameIndex: currentFrameIndex,
          playbackFrameCount: playbackFrameCount,
          frameStartIndex: frameStartIndex,
          frameEndIndexExclusive: frameEndIndexExclusive,
          leadingFrameSpacerWidth: leadingFrameSpacerWidth,
          trailingFrameSpacerWidth: trailingFrameSpacerWidth,
          totalFrameContentWidth: totalFrameContentWidth,
          metrics: metrics,
          exposureStateForLayer:
              exposureStateForLayer ??
              ((_, _) => TimelineCellExposureState.uncovered),
          frameNameForLayer: frameNameForLayer,
          onSelectLayer: onSelectLayer ?? (_) {},
          onSelectFrame: onSelectFrame ?? (_) {},
        ),
      ),
    ),
  );
}

Layer _layer(String id) {
  return Layer(id: LayerId(id), name: 'Layer $id', frames: const []);
}
