import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/layer_timeline_grid.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_orientation.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';
import 'package:quick_animaker_v2/src/ui/timeline/xsheet_timeline_grid.dart';

void main() {
  testWidgets('renders horizontal mode', (tester) async {
    await tester.pumpWidget(_panel(orientation: TimelineOrientation.horizontal));

    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byType(LayerTimelineGrid), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('timeline-cell-layer-1-0')),
      findsOneWidget,
    );
  });

  testWidgets('renders vertical mode', (tester) async {
    await tester.pumpWidget(_panel(orientation: TimelineOrientation.vertical));

    expect(find.byType(TimelinePanel), findsOneWidget);
    expect(find.byType(XSheetTimelineGrid), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('xsheet-cell-layer-1-0')),
      findsOneWidget,
    );
  });

  testWidgets('orientation toggle callback', (tester) async {
    TimelineOrientation? selectedOrientation;

    await tester.pumpWidget(
      _panel(
        orientation: TimelineOrientation.horizontal,
        onOrientationChanged: (orientation) => selectedOrientation = orientation,
      ),
    );

    await tester.tap(find.text('Show X-sheet'));

    expect(selectedOrientation, TimelineOrientation.vertical);
  });

  testWidgets('select frame callback still works', (tester) async {
    int? selectedFrameIndex;

    await tester.pumpWidget(
      _panel(onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex),
    );

    await tester.tap(find.byKey(const ValueKey<String>('timeline-cell-layer-1-3')));

    expect(selectedFrameIndex, 3);
  });

  testWidgets('select layer callback still works', (tester) async {
    LayerId? selectedLayerId;

    await tester.pumpWidget(
      _panel(onSelectLayer: (layerId) => selectedLayerId = layerId),
    );

    await tester.tap(find.byKey(const ValueKey<String>('timeline-layer-row-layer-2')));

    expect(selectedLayerId, const LayerId('layer-2'));
  });

  testWidgets('highlights current frame', (tester) async {
    await tester.pumpWidget(_panel(currentFrameIndex: 3));

    expect(find.text('▶ 3'), findsOneWidget);
    expect(find.textContaining('Current frame: 3'), findsOneWidget);
  });
}

Widget _panel({
  int currentFrameIndex = 0,
  int frameCount = 12,
  TimelineOrientation orientation = TimelineOrientation.horizontal,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<int>? onSelectFrame,
  ValueChanged<TimelineOrientation>? onOrientationChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: TimelinePanel(
        layers: _layers,
        activeLayerId: const LayerId('layer-1'),
        currentFrameIndex: currentFrameIndex,
        frameCount: frameCount,
        resolveFrameForLayer: (layer, frameIndex) => frameIndex == 0
            ? layer.frames.first
            : null,
        onSelectLayer: onSelectLayer ?? (_) {},
        onSelectFrame: onSelectFrame ?? (_) {},
        orientation: orientation,
        onOrientationChanged: onOrientationChanged ?? (_) {},
      ),
    ),
  );
}

final _layers = [
  Layer(
    id: const LayerId('layer-1'),
    name: 'Layer 1',
    frames: [Frame(id: const FrameId('frame-1'), duration: 1, strokes: const [])],
  ),
  Layer(
    id: const LayerId('layer-2'),
    name: 'Layer 2',
    frames: [Frame(id: const FrameId('frame-2'), duration: 1, strokes: const [])],
  ),
];
