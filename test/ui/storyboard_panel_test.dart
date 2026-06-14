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
import 'package:quick_animaker_v2/src/models/storyboard_frame_metadata.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/ui/storyboard_panel.dart';

void main() {
  testWidgets('shows storyboard shell, V tracks, cut blocks, and empty state', (
    tester,
  ) async {
    final project = _project(storyboardLayer: null);

    await _pumpPanel(tester, project);

    expect(
      find.byKey(const ValueKey<String>('storyboard-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('storyboard-panel-title')),
      findsOneWidget,
    );
    expect(find.text('STORYBOARD'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('storyboard-track-label-track-a')),
      findsOneWidget,
    );
    expect(find.text('V1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('storyboard-track-label-track-b')),
      findsOneWidget,
    );
    expect(find.text('V2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('storyboard-cut-block-cut-a')),
      findsOneWidget,
    );
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
      find.byKey(const ValueKey<String>('storyboard-layer-empty-cut-a')),
      findsOneWidget,
    );
    expect(find.text('No Storyboard Layer'), findsOneWidget);
  });

  testWidgets(
    'shows storyboard strip and name when a storyboard layer exists',
    (tester) async {
      await _pumpPanel(
        tester,
        _project(
          storyboardLayer: _layer(kind: LayerKind.storyboard, name: 'SB'),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('storyboard-layer-strip-cut-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('storyboard-layer-name-cut-a')),
        findsOneWidget,
      );
      expect(find.text('SB'), findsOneWidget);
      expect(find.text('No Storyboard Layer'), findsNothing);
    },
  );

  testWidgets('cut block width roughly represents cut duration', (
    tester,
  ) async {
    await _pumpPanel(tester, _twoCutProject());

    final shortSize = tester.getSize(
      find.byKey(const ValueKey<String>('storyboard-cut-block-cut-short')),
    );
    final longSize = tester.getSize(
      find.byKey(const ValueKey<String>('storyboard-cut-block-cut-long')),
    );

    expect(longSize.width, greaterThan(shortSize.width));
  });

  testWidgets('building the panel does not mutate the project', (tester) async {
    final project = _project(
      storyboardLayer: _layer(kind: LayerKind.storyboard, name: 'Storyboard'),
    );
    final beforeJson = project.toJson().toString();

    await _pumpPanel(tester, project);

    expect(project.toJson().toString(), beforeJson);
    expect(
      project,
      _project(
        storyboardLayer: _layer(kind: LayerKind.storyboard, name: 'Storyboard'),
      ),
    );
  });
}

Future<void> _pumpPanel(WidgetTester tester, Project project) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: StoryboardPanel(project: project)),
    ),
  );
}

Project _project({required Layer? storyboardLayer}) {
  return Project(
    id: const ProjectId('project-a'),
    name: 'Project A',
    createdAt: DateTime.utc(2026, 6, 14),
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
              _layer(kind: LayerKind.animation, name: 'A'),
              ?storyboardLayer,
            ],
          ),
        ],
      ),
      Track(id: const TrackId('track-b'), name: 'Track B', cuts: const []),
    ],
  );
}

Project _twoCutProject() {
  return Project(
    id: const ProjectId('project-b'),
    name: 'Project B',
    createdAt: DateTime.utc(2026, 6, 14),
    tracks: [
      Track(
        id: const TrackId('track-a'),
        name: 'Track A',
        cuts: [
          Cut(
            id: const CutId('cut-short'),
            name: 'Short',
            duration: 12,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: [_layer(kind: LayerKind.animation, name: 'A')],
          ),
          Cut(
            id: const CutId('cut-long'),
            name: 'Long',
            duration: 36,
            canvasSize: const CanvasSize(width: 1280, height: 720),
            layers: [_layer(kind: LayerKind.animation, name: 'A')],
          ),
        ],
      ),
    ],
  );
}

Layer _layer({required LayerKind kind, required String name}) {
  return Layer(
    id: LayerId('layer-$name-${kind.name}'),
    name: name,
    kind: kind,
    frames: [
      Frame(
        id: FrameId('frame-$name'),
        duration: 1,
        strokes: const [],
        storyboardMetadata: const StoryboardFrameMetadata(
          note: 'metadata kept',
        ),
      ),
    ],
  );
}
