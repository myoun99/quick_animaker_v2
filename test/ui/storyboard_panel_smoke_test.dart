import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/layer_kind.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';

void main() {
  group('StoryboardPanel baseline smoke tests', () {
    testWidgets('renders current root and title keys', (tester) async {
      await _pumpStoryboardPanel(tester, _projectWithStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-panel-title')),
        findsOneWidget,
      );
      expect(find.text('STORYBOARD'), findsOneWidget);
    });

    testWidgets('renders current track row and track label keys', (
      tester,
    ) async {
      await _pumpStoryboardPanel(tester, _projectWithStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-track-row-track-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('storyboard-track-label-row-track-a'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-track-label-track-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('storyboard-track-timeline-area-track-a'),
        ),
        findsOneWidget,
      );
      expect(find.text('V1'), findsOneWidget);
    });

    testWidgets('renders current cut positioned and block keys', (
      tester,
    ) async {
      await _pumpStoryboardPanel(tester, _projectWithStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-positioned-cut-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-a')),
        findsOneWidget,
      );
    });

    testWidgets('renders current cut title, duration, and frame range', (
      tester,
    ) async {
      await _pumpStoryboardPanel(tester, _projectWithStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-title-cut-a')),
        findsOneWidget,
      );
      expect(find.text('Cut A'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-duration-cut-a')),
        findsOneWidget,
      );
      expect(find.text('24f'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('storyboard-cut-frame-range-cut-a')),
        findsOneWidget,
      );
      expect(find.text('0f - 24f'), findsOneWidget);
    });

    testWidgets('renders current storyboard layer strip when present', (
      tester,
    ) async {
      await _pumpStoryboardPanel(tester, _projectWithStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-layer-strip-cut-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-layer-name-cut-a')),
        findsOneWidget,
      );
      expect(find.text('Storyboard'), findsOneWidget);
    });

    testWidgets('renders current active cut indicator when active', (
      tester,
    ) async {
      await _pumpStoryboardPanel(
        tester,
        _projectWithStoryboardLayer(),
        activeCutId: const CutId('cut-a'),
      );

      expect(
        find.byKey(
          const ValueKey<String>('storyboard-cut-active-indicator-cut-a'),
        ),
        findsOneWidget,
      );
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('preserves current inactive cut selection callback', (
      tester,
    ) async {
      CutId? selectedCutId;

      await _pumpStoryboardPanel(
        tester,
        _twoCutProject(),
        activeCutId: const CutId('cut-a'),
        onCutSelected: (cutId) => selectedCutId = cutId,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('storyboard-cut-block-cut-b')),
      );
      await tester.pumpAndSettle();

      expect(selectedCutId, const CutId('cut-b'));
    });

    testWidgets('renders current empty layer state when no storyboard layer', (
      tester,
    ) async {
      await _pumpStoryboardPanel(tester, _projectWithoutStoryboardLayer());

      expect(
        find.byKey(const ValueKey<String>('storyboard-layer-empty-cut-a')),
        findsOneWidget,
      );
      expect(find.text('No Storyboard Layer'), findsOneWidget);
    });
  });
}

Future<void> _pumpStoryboardPanel(
  WidgetTester tester,
  Project project, {
  CutId activeCutId = const CutId('cut-a'),
  ValueChanged<CutId>? onCutSelected,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StoryboardPanel(
          project: project,
          activeCutId: activeCutId,
          onCutSelected: onCutSelected ?? (_) {},
        ),
      ),
    ),
  );
}

Project _projectWithStoryboardLayer() {
  return _project(storyboardLayer: _layer(LayerKind.storyboard, 'Storyboard'));
}

Project _projectWithoutStoryboardLayer() {
  return _project(storyboardLayer: null);
}

Project _project({required Layer? storyboardLayer}) {
  return Project(
    id: const ProjectId('project-a'),
    name: 'Project A',
    createdAt: DateTime.utc(2026, 6, 20),
    tracks: [
      Track(
        id: const TrackId('track-a'),
        name: 'Track A',
        cuts: [
          Cut(
            id: const CutId('cut-a'),
            name: 'Cut A',
            duration: 24,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: [
              _layer(LayerKind.animation, 'Animation'),
              ?storyboardLayer,
            ],
          ),
        ],
      ),
    ],
  );
}

Project _twoCutProject() {
  return Project(
    id: const ProjectId('project-two-cut'),
    name: 'Project Two Cut',
    createdAt: DateTime.utc(2026, 6, 20),
    tracks: [
      Track(
        id: const TrackId('track-a'),
        name: 'Track A',
        cuts: [
          Cut(
            id: const CutId('cut-a'),
            name: 'Cut A',
            duration: 24,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: [_layer(LayerKind.animation, 'Animation A')],
          ),
          Cut(
            id: const CutId('cut-b'),
            name: 'Cut B',
            duration: 12,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: [_layer(LayerKind.animation, 'Animation B')],
          ),
        ],
      ),
    ],
  );
}

Layer _layer(LayerKind kind, String name) {
  return Layer(
    id: LayerId('layer-${kind.name}-$name'),
    name: name,
    kind: kind,
    frames: [
      Frame(
        id: FrameId('frame-${kind.name}-$name'),
        duration: 1,
        strokes: const [],
      ),
    ],
  );
}
