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

    test('last frame holds to visible timeline end', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('one-frame-layer'),
      );

      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 0),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 1),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 2),
        isTrue,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 10),
        const FrameId('one-frame'),
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 10),
        isTrue,
      );
    });

    test('frame holds until next frame starts', () {
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
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 4),
        isTrue,
      );
    });

    test('empty before first frame remains empty', () {
      final fixture = _createFixture();
      _createSparseFrame(
        fixture.controller,
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('late-frame'),
        startIndex: 5,
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 0),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 1),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 4),
        isNull,
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 5),
        isTrue,
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

    test(
      'total frame count uses max authored exposure length across layers',
      () {
        final fixture = _createFixture();

        expect(fixture.controller.totalFrameCount, 7);
      },
    );

    test('create drawing frame creates one sparse frame and holds forward', () {
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
      for (var frameIndex = 0; frameIndex < 10; frameIndex += 1) {
        expect(
          fixture.controller.resolveFrameForLayer(
            layer: layer,
            frameIndex: frameIndex,
          ),
          isNull,
        );
      }
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 10),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 11),
        isTrue,
      );
    });

    test('detects drawing starts and held exposures', () {
      final fixture = _createFixture();
      final layer = _findLayer(
        fixture.repository,
        const LayerId('exposure-layer'),
      );

      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 0),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 1),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 2),
        isTrue,
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 3),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 4),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 5),
        isTrue,
      );
    });

    test('held exposure is false for drawing starts and empty cells', () {
      final fixture = _createFixture();
      _createSparseFrame(
        fixture.controller,
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('late-frame'),
        startIndex: 5,
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 0),
        isFalse,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 4),
        isFalse,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 5),
        isFalse,
      );
    });

    test('effective duration spans to the next drawing frame start', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 6, 1),
        ],
      );
      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );

      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        6,
      );
    });

    test('increase exposure uses effective duration immediately', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 6, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        7,
      );
    });

    test('decrease exposure uses effective duration immediately', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 6, 1),
        ],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 1);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        5,
      );
    });

    test('decrease exposure does not go below effective duration one', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 1, 1),
        ],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        1,
      );
      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        1,
      );
    });

    test('increase exposure pushes directly adjacent following blocks', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 2),
          _FrameSpec(FrameId('b'), 2, 2),
          _FrameSpec(FrameId('c'), 4, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 3);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        3,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        5,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 0),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 2),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 3),
        const FrameId('b'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 5),
        const FrameId('c'),
      );
    });

    test('increase exposure does not move authored gaps after the next block', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 6, 1),
          _FrameSpec(FrameId('c'), 10, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        7,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        10,
      );
    });

    test('decrease exposure pulls directly adjacent following blocks', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 3),
          _FrameSpec(FrameId('b'), 3, 2),
          _FrameSpec(FrameId('c'), 5, 1),
        ],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(_findFrame(layer, const FrameId('a')).duration, 2);
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        2,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        4,
      );
    });

    test('decrease exposure does not move authored gaps after the next block', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 1),
          _FrameSpec(FrameId('b'), 6, 1),
          _FrameSpec(FrameId('c'), 10, 1),
        ],
      );

      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('b'),
        ),
        5,
      );
      expect(
        fixture.controller.exposureStartIndexForLayer(
          layer: layer,
          frameId: const FrameId('c'),
        ),
        10,
      );
    });

    test(
      'decrease exposure does not go below one or move following frames',
      () {
        final fixture = _createFixture();
        _createSparseBlock(
          fixture.controller,
          const LayerId('empty-layer'),
          const [
            _FrameSpec(FrameId('a'), 0, 1),
            _FrameSpec(FrameId('b'), 1, 2),
          ],
        );

        fixture.controller.decreaseExposure(
          layerId: const LayerId('empty-layer'),
          frameId: const FrameId('a'),
        );

        final layer = _findLayer(
          fixture.repository,
          const LayerId('empty-layer'),
        );
        expect(_findFrame(layer, const FrameId('a')).duration, 1);
        expect(
          fixture.controller.exposureStartIndexForLayer(
            layer: layer,
            frameId: const FrameId('b'),
          ),
          1,
        );
      },
    );

    test('dense frame duplication is not introduced', () {
      final fixture = _createFixture();
      _createSparseBlock(
        fixture.controller,
        const LayerId('empty-layer'),
        const [
          _FrameSpec(FrameId('a'), 0, 2),
          _FrameSpec(FrameId('b'), 2, 2),
          _FrameSpec(FrameId('c'), 4, 1),
        ],
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );
      fixture.controller.decreaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('a'),
      );
      fixture.controller.increaseExposure(
        layerId: const LayerId('empty-layer'),
        frameId: const FrameId('b'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('empty-layer'),
      );
      expect(layer.frames, hasLength(3));
    });

    test('increase exposure updates duration without creating frames', () {
      final fixture = _createFixture();

      fixture.controller.increaseExposure(
        layerId: const LayerId('one-frame-layer'),
        frameId: const FrameId('one-frame'),
      );

      final layer = _findLayer(
        fixture.repository,
        const LayerId('one-frame-layer'),
      );
      expect(layer.frames, hasLength(1));
      expect(layer.frames.single.duration, 2);
    });

    test('decrease exposure lowers duration', () {
      final fixture = _createFixture();

      fixture.controller.decreaseExposure(
        layerId: const LayerId('layer-1'),
        frameId: const FrameId('frame-a'),
      );

      final layer = _findLayer(fixture.repository, const LayerId('layer-1'));
      expect(layer.frames.first.duration, 3);
    });

    test('exposure editing throws clear errors for missing layer or frame', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.increaseExposure(
          layerId: const LayerId('missing-layer'),
          frameId: const FrameId('frame-a'),
        ),
        throwsStateError,
      );
      expect(
        () => fixture.controller.decreaseExposure(
          layerId: const LayerId('layer-1'),
          frameId: const FrameId('missing-frame'),
        ),
        throwsStateError,
      );
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
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('zero'),
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

void _createSparseBlock(
  TimelineController controller,
  LayerId layerId,
  List<_FrameSpec> specs,
) {
  for (final spec in specs) {
    _createSparseFrame(
      controller,
      layerId: layerId,
      frameId: spec.frameId,
      startIndex: spec.startIndex,
      duration: spec.duration,
    );
  }
}

void _createSparseFrame(
  TimelineController controller, {
  required LayerId layerId,
  required FrameId frameId,
  required int startIndex,
  int duration = 1,
}) {
  controller.selectFrameIndex(startIndex);
  controller.createDrawingFrameForLayer(
    layerId: layerId,
    frameId: frameId,
    duration: duration,
  );
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
                id: const LayerId('exposure-layer'),
                name: 'Exposure Layer',
                frames: [
                  Frame(
                    id: const FrameId('exposure-a'),
                    duration: 3,
                    strokes: const [],
                  ),
                  Frame(
                    id: const FrameId('exposure-b'),
                    duration: 2,
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
              Layer(
                id: const LayerId('one-frame-layer'),
                name: 'One Frame Layer',
                frames: [
                  Frame(
                    id: const FrameId('one-frame'),
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

Frame _findFrame(Layer layer, FrameId frameId) {
  for (final frame in layer.frames) {
    if (frame.id == frameId) {
      return frame;
    }
  }

  throw StateError('Frame not found.');
}

class _FrameSpec {
  const _FrameSpec(this.frameId, this.startIndex, this.duration);

  final FrameId frameId;
  final int startIndex;
  final int duration;
}

class _TimelineFixture {
  const _TimelineFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final TimelineController controller;
}
