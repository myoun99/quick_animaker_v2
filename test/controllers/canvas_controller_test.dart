import 'package:flutter/widgets.dart';
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

void main() {
  group('CanvasController', () {
    test('starts with no strokes', () {
      final fixture = _createFixture();

      expect(fixture.controller.strokes, isEmpty);
    });

    test('draw stroke', () {
      final fixture = _createFixture();

      fixture.controller.beginStroke(const Offset(10, 20));
      fixture.controller.updateStroke(const Offset(30, 40));
      fixture.controller.endStroke();

      final strokes = _findFrame(fixture.repository).strokes;
      expect(strokes, hasLength(1));
      expect(strokes.single.points, hasLength(2));
      expect(strokes.single.points[0].x, 10);
      expect(strokes.single.points[0].y, 20);
      expect(strokes.single.points[1].x, 30);
      expect(strokes.single.points[1].y, 40);
    });

    test('ignores short stroke', () {
      final fixture = _createFixture();

      fixture.controller.beginStroke(const Offset(10, 20));
      fixture.controller.endStroke();

      expect(_findFrame(fixture.repository).strokes, isEmpty);
    });

    test('undo stroke', () {
      final fixture = _createFixture();

      _drawStroke(fixture.controller);
      fixture.controller.undo();

      expect(_findFrame(fixture.repository).strokes, isEmpty);
    });

    test('redo stroke', () {
      final fixture = _createFixture();

      _drawStroke(fixture.controller);
      fixture.controller.undo();
      fixture.controller.redo();

      expect(_findFrame(fixture.repository).strokes, hasLength(1));
    });

    test('cancel stroke', () {
      final fixture = _createFixture();

      fixture.controller.beginStroke(const Offset(10, 20));
      fixture.controller.updateStroke(const Offset(30, 40));
      fixture.controller.cancelStroke();
      fixture.controller.endStroke();

      expect(fixture.controller.activePoints, isEmpty);
      expect(_findFrame(fixture.repository).strokes, isEmpty);
    });
  });
}

const _frameId = FrameId('frame-1');

_CanvasFixture _createFixture() {
  final repository = ProjectRepository(initialProject: _createSampleProject());
  final historyManager = HistoryManager();
  final controller = CanvasController(
    repository: repository,
    historyManager: historyManager,
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

void _drawStroke(CanvasController controller) {
  controller.beginStroke(const Offset(10, 20));
  controller.updateStroke(const Offset(30, 40));
  controller.endStroke();
}

class _CanvasFixture {
  const _CanvasFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final CanvasController controller;
}
