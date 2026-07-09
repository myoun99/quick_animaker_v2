import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_cell_exposure_state.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_orientation.dart';
import 'package:quick_animaker_v2/src/ui/timeline/timeline_panel.dart';

void main() {
  group('TimelinePanel baseline smoke', () {
    testWidgets('renders without throwing with a minimal project cut', (
      tester,
    ) async {
      await tester.pumpWidget(_panel());

      expect(tester.takeException(), isNull);
      expect(find.byType(TimelinePanel), findsOneWidget);
    });

    testWidgets('renders LayerTimelineGrid structure through TimelinePanel', (
      tester,
    ) async {
      await tester.pumpWidget(_panel(currentFrameIndex: 2));

      _expectKeyOnce('timeline-layer-controls-rail');
      _expectKeyOnce('timeline-frame-grid-area');
      _expectKeyOnce('timeline-horizontal-scrollbar-viewport');
      _expectKeyOnce('timeline-frame-scroll-viewport');
      _expectKeyOnce('timeline-frame-scroll-content');
      _expectKeyOnce('timeline-frame-rows-scroll-body');
    });

    testWidgets('renders frame ruler and header structure when horizontal', (
      tester,
    ) async {
      await tester.pumpWidget(_panel(currentFrameIndex: 2));

      _expectKeyOnce('timeline-frame-ruler');
      _expectKeyOnce('timeline-frame-header-row');
    });

    testWidgets('renders layer row, frame row area, and frame cell keys', (
      tester,
    ) async {
      await tester.pumpWidget(_panel(currentFrameIndex: 2));

      _expectKeyOnce('timeline-layer-row-layer-1');
      _expectKeyOnce('timeline-frame-row-area-layer-1');
      _expectKeyOnce('timeline-cell-layer-1-0');
    });

    testWidgets('renders current-frame playhead baseline', (tester) async {
      await tester.pumpWidget(_panel(currentFrameIndex: 2));

      _expectKeyOnce('timeline-playhead');
      _expectKeyOnce('timeline-playhead-column');
    });

    testWidgets('forwards add-layer callback from grid header boundary', (
      tester,
    ) async {
      var addLayerCallCount = 0;

      await tester.pumpWidget(_panel(onAddLayer: () => addLayerCallCount += 1));
      await tester.tap(_key('timeline-add-layer-button'));

      expect(addLayerCallCount, 1);
    });

    testWidgets('forwards frame-selection callback from a frame cell', (
      tester,
    ) async {
      int? selectedFrameIndex;

      await tester.pumpWidget(
        _panel(onSelectFrame: (frameIndex) => selectedFrameIndex = frameIndex),
      );
      await tester.tap(_key('timeline-cell-layer-1-3'));

      expect(selectedFrameIndex, 3);
    });

    testWidgets('forwards layer-selection callback from a layer name', (
      tester,
    ) async {
      LayerId? selectedLayerId;

      await tester.pumpWidget(
        _panel(onSelectLayer: (layerId) => selectedLayerId = layerId),
      );
      await tester.tap(_key('timeline-layer-name-layer-1'));

      expect(selectedLayerId, const LayerId('layer-1'));
    });

    testWidgets('does not duplicate structural keys', (tester) async {
      await tester.pumpWidget(_panel(currentFrameIndex: 2));

      for (final key in _structuralKeys) {
        _expectKeyOnce(key);
      }
    });
  });
}

const _structuralKeys = <String>[
  'timeline-layer-controls-rail',
  'timeline-frame-grid-area',
  'timeline-horizontal-scrollbar-viewport',
  'timeline-frame-scroll-viewport',
  'timeline-frame-scroll-content',
  'timeline-frame-rows-scroll-body',
  'timeline-horizontal-scrollbar',
  'timeline-bottom-scrollbar-rail',
  'timeline-vertical-scrollbar-slot',
];

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void _expectKeyOnce(String key) {
  expect(_key(key), findsOneWidget, reason: key);
}

Widget _panel({
  int currentFrameIndex = 0,
  ValueChanged<LayerId>? onSelectLayer,
  ValueChanged<int>? onSelectFrame,
  VoidCallback? onAddLayer,
}) {
  final cut = _project.tracks.single.cuts.single;

  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 320,
        child: TimelinePanel(
          layers: cut.layers,
          activeLayerId: cut.layers.single.id,
          frameCursor: ValueNotifier<int>(currentFrameIndex),
          playbackFrameCount: cut.duration,
          exposureStateForLayer: (_, frameIndex) => frameIndex == 0
              ? TimelineCellExposureState.drawingStart
              : TimelineCellExposureState.uncovered,
          onSelectLayer: onSelectLayer ?? (_) {},
          onSelectFrame: onSelectFrame ?? (_) {},
          onAddLayer: onAddLayer ?? () {},
          onToggleLayerVisibility: (_) {},
          onLayerOpacityChanged: (_, _) {},
          onToggleLayerTimesheet: (_) {},
          onLayerMarkSelected: (_, _) {},
          orientation: TimelineOrientation.horizontal,
          onOrientationChanged: (_) {},
        ),
      ),
    ),
  );
}

final _project = Project(
  id: const ProjectId('project-1'),
  name: 'Smoke Project',
  createdAt: DateTime.utc(2026),
  tracks: [
    Track(
      id: const TrackId('track-1'),
      name: 'V1',
      cuts: [
        Cut(
          id: const CutId('cut-1'),
          name: 'Cut 1',
          duration: 12,
          canvasSize: const CanvasSize(width: 1920, height: 1080),
          layers: [
            Layer(
              id: const LayerId('layer-1'),
              name: 'Layer 1',
              frames: [
                Frame(
                  id: const FrameId('frame-1'),
                  duration: 1,
                  strokes: const [],
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
