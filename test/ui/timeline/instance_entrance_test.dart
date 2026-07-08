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
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/home_page.dart';

/// Entrance unification: EVERY layer kind opens its instance editor on
/// double-tap, and the toolbar Add / Edit Instance buttons dispatch by
/// kind. Fixture: a drawing layer with a named 4-frame entry, an empty SE
/// layer and a camera layer.
Project _project() {
  return Project(
    id: const ProjectId('entrance-project'),
    name: 'Entrance Project',
    createdAt: DateTime.utc(2026, 7, 9),
    tracks: [
      Track(
        id: const TrackId('entrance-track'),
        name: 'Video',
        cuts: [
          Cut(
            id: const CutId('entrance-cut'),
            name: 'Entrance Cut',
            duration: 12,
            canvasSize: const CanvasSize(width: 640, height: 360),
            layers: [
              Layer(
                id: const LayerId('draw'),
                name: 'A',
                frames: [
                  Frame(
                    id: const FrameId('draw-f1'),
                    duration: 4,
                    name: 'A1',
                    strokes: const [],
                  ),
                ],
                timeline: {
                  0: const TimelineExposure.drawing(
                    FrameId('draw-f1'),
                    length: 4,
                  ),
                },
              ),
              Layer(
                id: const LayerId('voice'),
                name: 'S1',
                kind: LayerKind.se,
                frames: const [],
                timeline: const {},
              ),
              Layer(
                id: const LayerId('cam'),
                name: 'Camera',
                kind: LayerKind.camera,
                frames: const [],
                timeline: const {},
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Future<ProjectRepository> _pumpHome(WidgetTester tester) async {
  late ProjectRepository repository;
  await tester.pumpWidget(
    MaterialApp(
      home: HomePage(
        initialProject: _project(),
        onRepositoryCreated: (repo) => repository = repo,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _doubleTapCell(WidgetTester tester, String cellKey) async {
  final cell = find.byKey(ValueKey<String>(cellKey));
  await tester.tap(cell);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(cell);
  await tester.pumpAndSettle();
}

Cut _cut(ProjectRepository repository) =>
    repository.requireProject().tracks.single.cuts.single;

void main() {
  testWidgets('drawing cell double-tap opens the frame-name editor; single '
      'tap still selects', (tester) async {
    final repository = await _pumpHome(tester);

    // Single tap: selection only, no dialog.
    await tester.tap(find.byKey(const ValueKey<String>('timeline-cell-draw-2')));
    await tester.pumpAndSettle();
    expect(find.text('Rename Frame'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('timeline-cell-draw-2')),
        matching: find.byKey(const ValueKey<String>('timeline-selected-cell')),
      ),
      findsOneWidget,
    );

    await _doubleTapCell(tester, 'timeline-cell-draw-1');
    expect(find.text('Rename Frame'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey<String>('rename-frame-text-field')),
      'A2',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('rename-frame-ok-button')),
    );
    await tester.pumpAndSettle();

    expect(
      _cut(repository).layers.first.frames.single.name,
      'A2',
    );
  });

  testWidgets('camera cell double-tap opens the key dialog; keying a lane '
      'commits ONE undo step', (tester) async {
    final repository = await _pumpHome(tester);

    await _doubleTapCell(tester, 'timeline-cell-cam-2');
    expect(find.text('Camera Keys — Frame 3'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('camera-key-toggle-position')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('instance-edit-ok-button')),
    );
    await tester.pumpAndSettle();

    expect(_cut(repository).camera.track.position.keyAt(2), isNotNull);
    expect(_cut(repository).camera.track.scale.keyAt(2), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('undo-button')));
    await tester.pumpAndSettle();
    expect(_cut(repository).camera.track.position.keyAt(2), isNull);
  });

  testWidgets('toolbar Add on the camera layer keys the current pose at '
      'the playhead', (tester) async {
    final repository = await _pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey<String>('timeline-cell-cam-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('new-frame-button')));
    await tester.pumpAndSettle();

    final track = _cut(repository).camera.track;
    expect(track.position.keyAt(4), isNotNull);
    expect(track.scale.keyAt(4), isNotNull);
    expect(track.rotation.keyAt(4), isNotNull);
  });

  testWidgets('toolbar Add on an empty SE cell runs the SE dialog first', (
    tester,
  ) async {
    final repository = await _pumpHome(tester);

    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-cell-voice-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('new-frame-button')));
    await tester.pumpAndSettle();
    expect(find.text('New SE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('se-dialogue-field')),
      '쿵',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('instance-edit-ok-button')),
    );
    await tester.pumpAndSettle();

    final seLayer = _cut(
      repository,
    ).layers.firstWhere((layer) => layer.kind == LayerKind.se);
    expect(seLayer.frames.single.name, '쿵');
    expect(seLayer.timeline[3], isNotNull);
  });

  testWidgets('toolbar Edit Instance opens the camera key dialog for the '
      'camera layer', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey<String>('timeline-cell-cam-0')));
    await tester.pumpAndSettle();
    // The edit group sits deep in the horizontally scrolling toolbar.
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('rename-frame-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('rename-frame-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Camera Keys — Frame 1'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('instance-edit-cancel-button')),
    );
    await tester.pumpAndSettle();
  });
}
