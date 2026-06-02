import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/canvas_controller.dart';
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
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_view.dart';

void main() {
  testWidgets('CanvasView renders', (tester) async {
    final fixture = _createFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CanvasView(controller: fixture.controller),
          ),
        ),
      ),
    );

    expect(find.byType(CanvasView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag gesture creates stroke', (tester) async {
    final fixture = _createFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CanvasView(controller: fixture.controller),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CanvasView), const Offset(50, 50));
    await tester.pump();

    expect(_findFrame(fixture.repository).strokes, hasLength(1));
  });
}

const _frameId = FrameId('frame-1');

_CanvasFixture _createFixture() {
  final repository = ProjectRepository(initialProject: _createSampleProject());
  final controller = CanvasController(
    repository: repository,
    historyManager: HistoryManager(),
    frameId: _frameId,
  );

  return _CanvasFixture(repository: repository, controller: controller);
}

Project _createSampleProject() {
  return Project(
    id: const ProjectId('project-1'),
    name: 'Test Project',
    createdAt: DateTime.utc(2026),
    tracks: [
      Track(
        id: const TrackId('track-1'),
        name: 'Track 1',
        cuts: [
          Cut(
            id: const CutId('cut-1'),
            name: 'Cut 1',
            duration: 1,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [
              Layer(
                id: const LayerId('layer-1'),
                name: 'Layer 1',
                frames: [Frame(id: _frameId, duration: 1, strokes: const [])],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Frame _findFrame(ProjectRepository repository) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        for (final frame in layer.frames) {
          if (frame.id == _frameId) {
            return frame;
          }
        }
      }
    }
  }

  throw StateError('Frame not found.');
}

class _CanvasFixture {
  const _CanvasFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final CanvasController controller;
}
