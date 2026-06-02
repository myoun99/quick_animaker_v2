import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/layers/layer_panel.dart';

void main() {
  testWidgets('renders layer names', (tester) async {
    await tester.pumpWidget(_panel());

    expect(find.text('Layer 1'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
  });

  testWidgets('select layer callback', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _panel(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(find.text('Layer 2'));

    expect(selectedLayerId, const LayerId('layer-2'));
  });

  testWidgets('add layer callback', (tester) async {
    var addCalled = false;

    await tester.pumpWidget(_panel(onAddLayer: () => addCalled = true));

    await tester.tap(find.text('Add Layer'));

    expect(addCalled, isTrue);
  });

  testWidgets('visibility callback', (tester) async {
    LayerId? toggledLayerId;

    await tester.pumpWidget(
      _panel(onToggleVisibility: (layerId) => toggledLayerId = layerId),
    );

    await tester.tap(find.byTooltip('Hide layer').first);

    expect(toggledLayerId, const LayerId('layer-1'));
  });
}

Widget _panel({
  ValueChanged<LayerId>? onSelectLayer,
  VoidCallback? onAddLayer,
  ValueChanged<LayerId>? onToggleVisibility,
  void Function(LayerId layerId, double opacity)? onOpacityChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 300,
        height: 500,
        child: LayerPanel(
          layers: _layers,
          activeLayerId: const LayerId('layer-1'),
          onSelectLayer: onSelectLayer ?? (_) {},
          onAddLayer: onAddLayer ?? () {},
          onToggleVisibility: onToggleVisibility ?? (_) {},
          onOpacityChanged: onOpacityChanged ?? (_, _) {},
        ),
      ),
    ),
  );
}

final _layers = [
  Layer(
    id: const LayerId('layer-1'),
    name: 'Layer 1',
    frames: [
      Frame(id: const FrameId('frame-1'), duration: 1, strokes: const []),
    ],
  ),
  Layer(
    id: const LayerId('layer-2'),
    name: 'Layer 2',
    frames: [
      Frame(id: const FrameId('frame-2'), duration: 1, strokes: const []),
    ],
  ),
];
