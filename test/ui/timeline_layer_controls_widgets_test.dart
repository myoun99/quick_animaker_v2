import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/layer_mark.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_grid_metrics.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_layer_controls_header.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_layer_controls_row.dart';

void main() {
  group('TimelineLayerControlsHeader', () {
    testWidgets('exposes the stable add layer button key', (tester) async {
      await tester.pumpWidget(_header(onAddLayer: () {}));

      expect(
        find.byKey(const ValueKey<String>('timeline-add-layer-button')),
        findsOneWidget,
      );
    });

    testWidgets('tapping add layer button invokes callback once', (
      tester,
    ) async {
      var addLayerCount = 0;
      await tester.pumpWidget(_header(onAddLayer: () => addLayerCount += 1));

      await tester.tap(
        find.byKey(const ValueKey<String>('timeline-add-layer-button')),
      );

      expect(addLayerCount, 1);
    });
  });

  group('TimelineLayerControlsRow', () {
    testWidgets('exposes stable row keys', (tester) async {
      final layer = _layer();

      await tester.pumpWidget(_row(layer: layer));

      expect(
        find.byKey(ValueKey<String>('timeline-layer-row-${layer.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('timeline-layer-name-${layer.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('timeline-layer-kind-icon-${layer.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('timeline-layer-visibility-${layer.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('timeline-layer-opacity-${layer.id}')),
        findsOneWidget,
      );
    });

    testWidgets('tapping row selects layer', (tester) async {
      final layer = _layer();
      LayerId? selectedLayerId;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onSelectLayer: (layerId) => selectedLayerId = layerId,
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('timeline-layer-row-${layer.id}')),
      );

      expect(selectedLayerId, layer.id);
    });

    testWidgets('tapping layer name selects layer', (tester) async {
      final layer = _layer();
      LayerId? selectedLayerId;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onSelectLayer: (layerId) => selectedLayerId = layerId,
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('timeline-layer-name-${layer.id}')),
      );

      expect(selectedLayerId, layer.id);
    });

    testWidgets('tapping visibility button toggles layer visibility', (
      tester,
    ) async {
      final layer = _layer();
      LayerId? toggledLayerId;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onToggleLayerVisibility: (layerId) => toggledLayerId = layerId,
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('timeline-layer-visibility-${layer.id}')),
      );

      expect(toggledLayerId, layer.id);
    });

    testWidgets('changing opacity invokes callback with layer id and value', (
      tester,
    ) async {
      final layer = _layer();
      LayerId? changedLayerId;
      double? changedOpacity;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onLayerOpacityChanged: (layerId, opacity) {
            changedLayerId = layerId;
            changedOpacity = opacity;
          },
        ),
      );

      final slider = tester.widget<Slider>(
        find.byKey(ValueKey<String>('timeline-layer-opacity-${layer.id}')),
      );
      slider.onChanged?.call(0.25);

      expect(changedLayerId, layer.id);
      expect(changedOpacity, 0.25);
    });

    testWidgets('active row exposes selected-layer semantic key', (
      tester,
    ) async {
      final layer = _layer();

      await tester.pumpWidget(_row(layer: layer, active: true));

      expect(
        find.byKey(const ValueKey<String>('timeline-selected-layer')),
        findsOneWidget,
      );

      await tester.pumpWidget(_row(layer: layer));

      expect(
        find.byKey(const ValueKey<String>('timeline-selected-layer')),
        findsNothing,
      );
    });

    testWidgets('tapping timesheet toggle reports the layer', (tester) async {
      final layer = _layer();
      LayerId? toggledLayerId;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onToggleLayerTimesheet: (layerId) => toggledLayerId = layerId,
        ),
      );

      expect(find.byTooltip('Remove from timesheet'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey<String>('timeline-layer-timesheet-${layer.id}')),
      );

      expect(toggledLayerId, layer.id);
    });

    testWidgets('excluded layer offers the add-to-timesheet tooltip', (
      tester,
    ) async {
      final layer = _layer().copyWith(onTimesheet: false);

      await tester.pumpWidget(_row(layer: layer));

      expect(find.byTooltip('Add to timesheet'), findsOneWidget);
      expect(find.byTooltip('Remove from timesheet'), findsNothing);
    });

    testWidgets('selecting a mark from the chip popup reports it', (
      tester,
    ) async {
      final layer = _layer();
      LayerId? markedLayerId;
      LayerMark? selectedMark;

      await tester.pumpWidget(
        _row(
          layer: layer,
          onLayerMarkSelected: (layerId, mark) {
            markedLayerId = layerId;
            selectedMark = mark;
          },
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('timeline-layer-mark-${layer.id}')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('layer-mark-option-blue')),
      );
      await tester.pumpAndSettle();

      expect(markedLayerId, layer.id);
      expect(selectedMark, LayerMark.blue);
    });

    testWidgets('non-animation layers hide the timesheet toggle', (
      tester,
    ) async {
      final storyboardLayer = _layer().copyWith(kind: LayerKind.storyboard);

      await tester.pumpWidget(_row(layer: storyboardLayer));

      expect(
        find.byKey(
          ValueKey<String>('timeline-layer-timesheet-${storyboardLayer.id}'),
        ),
        findsNothing,
      );
      // The mark chip stays available for storyboard layers.
      expect(
        find.byKey(
          ValueKey<String>('timeline-layer-mark-${storyboardLayer.id}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('camera layer hides both chips', (tester) async {
      final cameraLayer = _layer().copyWith(kind: LayerKind.camera);

      await tester.pumpWidget(_row(layer: cameraLayer));

      expect(
        find.byKey(
          ValueKey<String>('timeline-layer-timesheet-${cameraLayer.id}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey<String>('timeline-layer-mark-${cameraLayer.id}')),
        findsNothing,
      );
    });
  });
}

Widget _header({required VoidCallback onAddLayer}) {
  return MaterialApp(
    home: Material(
      child: TimelineLayerControlsHeader(
        metrics: TimelineGridMetrics.defaults,
        onAddLayer: onAddLayer,
      ),
    ),
  );
}

Widget _row({
  required Layer layer,
  bool active = false,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<LayerId>? onToggleLayerVisibility,
  void Function(LayerId layerId, double opacity)? onLayerOpacityChanged,
  ValueChanged<LayerId>? onToggleLayerTimesheet,
  void Function(LayerId layerId, LayerMark mark)? onLayerMarkSelected,
}) {
  return MaterialApp(
    home: Material(
      child: TimelineLayerControlsRow(
        layer: layer,
        active: active,
        metrics: TimelineGridMetrics.defaults,
        onSelectLayer: onSelectLayer ?? (_) {},
        onToggleLayerVisibility: onToggleLayerVisibility ?? (_) {},
        onLayerOpacityChanged: onLayerOpacityChanged ?? (_, _) {},
        onToggleLayerTimesheet: onToggleLayerTimesheet ?? (_) {},
        onLayerMarkSelected: onLayerMarkSelected ?? (_, _) {},
      ),
    ),
  );
}

Layer _layer() {
  return Layer(
    id: const LayerId('layer-test'),
    name: 'Layer Test',
    frames: const [],
  );
}
