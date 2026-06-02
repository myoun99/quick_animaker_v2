import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

void main() {
  testWidgets('renders layer headers', (tester) async {
    await tester.pumpWidget(_grid());

    expect(find.text('Layer 1'), findsOneWidget);
    expect(find.text('Layer 2'), findsOneWidget);
  });

  testWidgets('renders frame rows and cells', (tester) async {
    await tester.pumpWidget(_grid());

    expect(
      find.byKey(const ValueKey<String>('xsheet-frame-row-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-2-0')),
      findsOneWidget,
    );
  });

  testWidgets('selects frame', (tester) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _grid(onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-3')),
    );

    expect(selectedFrameIndex, 3);
  });

  testWidgets('selects layer', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _grid(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('xsheet-layer-header-layer-2')),
    );

    expect(selectedLayerId, const LayerId('layer-2'));
  });

  testWidgets('shows drawing marker', (tester) async {
    await tester.pumpWidget(
      _grid(
        resolveFrameForLayer: (layer, frameIndex) =>
            layer.id == const LayerId('layer-2') && frameIndex == 2
            ? layer.frames.first
            : null,
      ),
    );

    expect(find.text('●'), findsOneWidget);
  });

  testWidgets('highlights current frame', (tester) async {
    await tester.pumpWidget(_grid(currentFrameIndex: 3));

    expect(
      find.byKey(const ValueKey<String>('xsheet-frame-row-3')),
      findsOneWidget,
    );
    expect(find.text('▶ 3'), findsOneWidget);
  });
}

Widget _grid({
  int currentFrameIndex = 0,
  int frameCount = 12,
  Frame? Function(Layer layer, int frameIndex)? resolveFrameForLayer,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<int>? onSelectFrame,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 600,
        child: XSheetTimelineGrid(
          layers: _layers,
          activeLayerId: const LayerId('layer-1'),
          currentFrameIndex: currentFrameIndex,
          frameCount: frameCount,
          resolveFrameForLayer: resolveFrameForLayer ?? (_, _) => null,
          onSelectLayer: onSelectLayer ?? (_) {},
          onSelectFrame: onSelectFrame ?? (_) {},
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
