import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/canvas_controller.dart';
import 'package:quick_animaker_v2/src/controllers/layer_controller.dart';
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

      final strokes = _findLayerFrame(
        fixture.repository,
        const LayerId('layer-1'),
      ).strokes;
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

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
    });

    test('undo stroke', () {
      final fixture = _createFixture();

      _drawStroke(fixture.controller);
      fixture.controller.undo();

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
    });

    test('redo stroke', () {
      final fixture = _createFixture();

      _drawStroke(fixture.controller);
      fixture.controller.undo();
      fixture.controller.redo();

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        hasLength(1),
      );
    });

    test('cancel stroke', () {
      final fixture = _createFixture();

      fixture.controller.beginStroke(const Offset(10, 20));
      fixture.controller.updateStroke(const Offset(30, 40));
      fixture.controller.cancelStroke();
      fixture.controller.endStroke();

      expect(fixture.controller.activePoints, isEmpty);
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
    });

    test('drawing targets active layer', () {
      final fixture = _createFixture();

      fixture.layerController.selectLayer(const LayerId('layer-1'));
      _drawStroke(fixture.controller);

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        hasLength(1),
      );
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
        isEmpty,
      );

      fixture.layerController.selectLayer(const LayerId('layer-2'));
      _drawStroke(fixture.controller);

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        hasLength(1),
      );
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
        hasLength(1),
      );
    });

    test('undo active layer stroke', () {
      final fixture = _createFixture();

      fixture.layerController.selectLayer(const LayerId('layer-2'));
      _drawStroke(fixture.controller);
      fixture.controller.undo();

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
        isEmpty,
      );
    });

    test('drawing uses current timeline frame', () {
      final fixture = _createFixture(
        layers: [
          Layer(
            id: const LayerId('layer-1'),
            name: 'Layer 1',
            frames: [
              Frame(
                id: const FrameId('frame-a'),
                duration: 1,
                strokes: const [],
              ),
              Frame(
                id: const FrameId('frame-b'),
                duration: 1,
                strokes: const [],
              ),
            ],
          ),
        ],
      );

      fixture.timelineController.selectFrameIndex(0);
      _drawStroke(fixture.controller);
      fixture.timelineController.selectFrameIndex(1);
      _drawStroke(fixture.controller);

      expect(
        _findFrameById(fixture.repository, const FrameId('frame-a')).strokes,
        hasLength(1),
      );
      expect(
        _findFrameById(fixture.repository, const FrameId('frame-b')).strokes,
        hasLength(1),
      );
    });

    test('drawing creates one sparse frame when no frame exists', () {
      final fixture = _createFixture(
        layers: [
          Layer(
            id: const LayerId('layer-1'),
            name: 'Layer 1',
            frames: const [],
          ),
        ],
      );

      fixture.timelineController.selectFrameIndex(10);
      _drawStroke(fixture.controller);

      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));
      expect(layer.frames, hasLength(1));
      expect(layer.frames.single.duration, 1);
      expect(layer.frames.single.strokes, hasLength(1));
      expect(
        fixture.timelineController.resolveFrameForLayer(
          layer: layer,
          frameIndex: 9,
        ),
        isNull,
      );
      expect(
        fixture.timelineController.resolveFrameForLayer(
          layer: layer,
          frameIndex: 10,
        ),
        isNotNull,
      );
    });

    test('drawing still targets active layer at current timeline frame', () {
      final fixture = _createFixture();

      fixture.layerController.selectLayer(const LayerId('layer-2'));
      fixture.timelineController.selectFrameIndex(0);
      _drawStroke(fixture.controller);

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
        hasLength(1),
      );
    });

    test(
      'undo on different timeline frame moves first then removes stroke',
      () {
        final fixture = _createFixture();

        fixture.timelineController.selectFrameIndex(0);
        _drawStroke(fixture.controller);
        fixture.timelineController.selectFrameIndex(5);

        fixture.controller.undo();

        expect(fixture.timelineController.currentFrameIndex, 0);
        expect(
          _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
          hasLength(1),
        );

        fixture.controller.undo();

        expect(
          _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
          isEmpty,
        );
      },
    );

    test('undo on same timeline frame removes stroke immediately', () {
      final fixture = _createFixture();

      fixture.timelineController.selectFrameIndex(0);
      _drawStroke(fixture.controller);
      fixture.controller.undo();

      expect(fixture.timelineController.currentFrameIndex, 0);
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
    });

    test('redo active layer stroke', () {
      final fixture = _createFixture();

      fixture.layerController.selectLayer(const LayerId('layer-2'));
      _drawStroke(fixture.controller);
      fixture.controller.undo();
      fixture.controller.redo();

      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
        isEmpty,
      );
      expect(
        _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
        hasLength(1),
      );
    });
  });
}

const _cutId = CutId('cut-1');
const _frameId = FrameId('frame-1');

_CanvasFixture _createFixture({List<Layer>? layers}) {
  final repository = ProjectRepository(
    initialProject: _createSampleProject(layers: layers),
  );
  final historyManager = HistoryManager();
  final layerController = LayerController(
    repository: repository,
    historyManager: historyManager,
    cutId: _cutId,
    frameId: _frameId,
  );
  final timelineController = TimelineController(
    repository: repository,
    cutId: _cutId,
  );
  final controller = CanvasController(
    repository: repository,
    historyManager: historyManager,
    frameId: _frameId,
    layerController: layerController,
    timelineController: timelineController,
  );

  return _CanvasFixture(
    repository: repository,
    controller: controller,
    layerController: layerController,
    timelineController: timelineController,
  );
}

Project _createSampleProject({List<Layer>? layers}) {
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
            layers:
                layers ??
                [
                  Layer(
                    id: const LayerId('layer-1'),
                    name: 'Layer 1',
                    frames: [
                      Frame(id: _frameId, duration: 1, strokes: const []),
                    ],
                  ),
                  Layer(
                    id: const LayerId('layer-2'),
                    name: 'Layer 2',
                    frames: [
                      Frame(
                        id: const FrameId('frame-2'),
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

Frame _findFrameById(ProjectRepository repository, FrameId frameId) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        for (final frame in layer.frames) {
          if (frame.id == frameId) {
            return frame;
          }
        }
      }
    }
  }

  throw StateError('Frame not found.');
}

Frame _findLayerFrame(ProjectRepository repository, LayerId layerId) {
  for (final track in repository.requireProject().tracks) {
    for (final cut in track.cuts) {
      for (final layer in cut.layers) {
        if (layer.id == layerId) {
          return layer.frames.single;
        }
      }
    }
  }

  throw StateError('Layer not found.');
}

void _drawStroke(CanvasController controller) {
  controller.beginStroke(const Offset(10, 20));
  controller.updateStroke(const Offset(30, 40));
  controller.endStroke();
}

class _CanvasFixture {
  const _CanvasFixture({
    required this.repository,
    required this.controller,
    required this.layerController,
    required this.timelineController,
  });

  final ProjectRepository repository;
  final CanvasController controller;
  final LayerController layerController;
  final TimelineController timelineController;
}
