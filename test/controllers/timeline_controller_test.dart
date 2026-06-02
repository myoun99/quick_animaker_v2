import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/timeline_controller.dart';
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
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('TimelineController', () {
    test('starts at initial frame index', () {
      final fixture = _createFixture();

      expect(fixture.controller.currentFrameIndex, 0);
    });

    test('select frame index', () {
      final fixture = _createFixture();

      fixture.controller.selectFrameIndex(10);

      expect(fixture.controller.currentFrameIndex, 10);
    });

    test('reject negative frame index', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.selectFrameIndex(-1),
        throwsArgumentError,
      );
    });

    test('resolves sparse exposure frames', () {
      final fixture = _createFixture();
      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));

      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 2),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 3),
        const FrameId('frame-a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 4),
        const FrameId('frame-b'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 5),
        const FrameId('frame-b'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 6),
        const FrameId('frame-b'),
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 7),
        isNull,
      );
    });

    test('empty layer resolves null', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 0),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 10),
        isNull,
      );
    });

    test('total frame count uses max exposure length across layers', () {
      final fixture = _createFixture();

      expect(fixture.controller.totalFrameCount, 7);
    });

    test('create drawing frame appends one sparse frame only', () {
      final fixture = _createFixture();
      fixture.controller.selectFrameIndex(10);

      fixture.controller.createDrawingFrameForLayer(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('new-frame'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(layer.frames, hasLength(1));
      expect(layer.frames.single.id, const FrameId('new-frame'));
      expect(layer.frames.single.duration, 1);
    });

    test('duration less than one is treated as one for resolution', () {
      final layer = Layer(
        id: const LayerId('duration-layer'),
        name: 'Duration Layer',
        frames: [
          Frame(id: const FrameId('zero'), duration: 0, strokes: const []),
        ],
      );
      final fixture = _createFixture();

      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('zero'),
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 1),
        isNull,
      );
    });

    test('create drawing frame rejects invalid duration', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('invalid'),
          duration: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}

const _cutId = CutId('cut-1');

_TimelineFixture _createFixture() {
  final repository = ProjectRepository(initialProject: _createSampleProject());
  final controller = TimelineController(repository: repository, cutId: _cutId);
  return _TimelineFixture(repository: repository, controller: controller);
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
            id: _cutId,
            name: 'Cut 1',
            duration: 1,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [
              Layer(
                id: const LayerId('layer-1'),
                name: 'Layer 1',
                frames: [
                  Frame(
                    id: const FrameId('frame-a'),
                    duration: 4,
                    strokes: const [],
                  ),
                  Frame(
                    id: const FrameId('frame-b'),
                    duration: 3,
                    strokes: const [],
                  ),
                ],
              ),
              Layer(
                id: const LayerId('empty-layer'),
                name: 'Empty Layer',
                frames: const [],
              ),
              Layer(
                id: const LayerId('short-layer'),
                name: 'Short Layer',
                frames: [
                  Frame(
                    id: const FrameId('short-frame'),
                    duration: 2,
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
}

Layer _findLayer(ProjectRepository repository, LayerId layerId) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        if (layer.id == layerId) {
          return layer;
        }
      }
    }
  }

  throw StateError('Layer not found.');
}

class _TimelineFixture {
  const _TimelineFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final TimelineController controller;
}
