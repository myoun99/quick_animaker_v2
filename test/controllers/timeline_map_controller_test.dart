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
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('Timeline map controller', () {
    test('empty timeline resolves null', () {
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: const [],
          timeline: const {},
        ),
      );

      expect(
        fixture.controller.resolveFrameForLayer(
          layer: fixture.layer,
          frameIndex: 0,
        ),
        isNull,
      );
    });

    test('drawing and blank entries hold until next exposure entry', () {
      final layer = Layer(
        id: const LayerId('layer'),
        name: 'Layer',
        frames: [
          Frame(id: const FrameId('a'), duration: 1, strokes: const []),
          Frame(id: const FrameId('b'), duration: 1, strokes: const []),
        ],
        timeline: {
          5: TimelineExposure.drawing(const FrameId('a')),
          8: const TimelineExposure.blank(),
          10: TimelineExposure.drawing(const FrameId('b')),
        },
      );
      final fixture = _fixture(layer);

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 4),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 5),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 7),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 8),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 9),
        isNull,
      );
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 10),
        const FrameId('b'),
      );
      expect(
        fixture.controller.isDrawingStartForLayer(layer: layer, frameIndex: 5),
        isTrue,
      );
      expect(
        fixture.controller.isHeldExposureForLayer(layer: layer, frameIndex: 6),
        isTrue,
      );
      expect(
        fixture.controller.isBlankStartForLayer(layer: layer, frameIndex: 8),
        isTrue,
      );
      expect(
        fixture.controller.isBlankHeldForLayer(layer: layer, frameIndex: 9),
        isTrue,
      );
    });

    test('last blank holds forward as null', () {
      final layer = Layer(
        id: const LayerId('layer'),
        name: 'Layer',
        frames: [Frame(id: const FrameId('a'), duration: 1, strokes: const [])],
        timeline: {
          0: TimelineExposure.drawing(const FrameId('a')),
          3: const TimelineExposure.blank(),
        },
      );
      final fixture = _fixture(layer);

      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 100),
        isNull,
      );
      expect(
        fixture.controller.isBlankHeldForLayer(layer: layer, frameIndex: 100),
        isTrue,
      );
    });

    test(
      'new drawing and blank are undoable and do not create dense frames',
      () {
        final history = HistoryManager();
        final fixture = _fixture(
          Layer(
            id: const LayerId('layer'),
            name: 'Layer',
            frames: const [],
            timeline: const {},
          ),
          historyManager: history,
        );

        fixture.controller.selectFrameIndex(6);
        fixture.controller.createBlankExposureForLayer(
          layerId: const LayerId('layer'),
        );
        expect(_latestLayer(fixture.repository).frames, isEmpty);
        expect(
          _latestLayer(fixture.repository).timeline[6]?.type,
          TimelineExposureType.blank,
        );

        history.undo();
        expect(_latestLayer(fixture.repository).timeline, isEmpty);

        fixture.controller.selectFrameIndex(8);
        fixture.controller.createDrawingFrameForLayer(
          layerId: const LayerId('layer'),
          frameId: const FrameId('draw'),
        );
        expect(_latestLayer(fixture.repository).frames, hasLength(1));
        expect(_latestLayer(fixture.repository).timeline, hasLength(1));

        history.undo();
        expect(_latestLayer(fixture.repository).frames, isEmpty);
        expect(_latestLayer(fixture.repository).timeline, isEmpty);
      },
    );

    test('+ and - exposure move following timeline entry and are undoable', () {
      final history = HistoryManager();
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 3, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            6: TimelineExposure.drawing(const FrameId('b')),
          },
        ),
        historyManager: history,
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      expect(_latestLayer(fixture.repository).timeline.containsKey(7), isTrue);
      history.undo();
      expect(_latestLayer(fixture.repository).timeline.containsKey(6), isTrue);

      fixture.controller.decreaseExposure(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      expect(_latestLayer(fixture.repository).timeline.containsKey(5), isTrue);
      history.undo();
      expect(_latestLayer(fixture.repository).timeline.containsKey(6), isTrue);
    });

    test('increase exposure pushes blank into drawing collision chain', () {
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 4, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            5: const TimelineExposure.blank(),
            6: TimelineExposure.drawing(const FrameId('b')),
          },
        ),
      );

      expect(
        () => fixture.controller.increaseExposure(
          layerId: const LayerId('layer'),
          frameId: const FrameId('a'),
        ),
        returnsNormally,
      );

      final timeline = _latestLayer(fixture.repository).timeline;
      expect(timeline.keys, orderedEquals([0, 6, 7]));
      expect(timeline[6]?.type, TimelineExposureType.blank);
      expect(timeline[7]?.frameId, const FrameId('b'));
    });

    test('increase exposure pushes B into C collision chain', () {
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 2, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
            Frame(id: const FrameId('c'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            2: TimelineExposure.drawing(const FrameId('b')),
            3: TimelineExposure.drawing(const FrameId('c')),
          },
        ),
      );

      expect(
        () => fixture.controller.increaseExposure(
          layerId: const LayerId('layer'),
          frameId: const FrameId('a'),
        ),
        returnsNormally,
      );

      final timeline = _latestLayer(fixture.repository).timeline;
      expect(timeline.keys, orderedEquals([0, 3, 4]));
      expect(timeline[3]?.frameId, const FrameId('b'));
      expect(timeline[4]?.frameId, const FrameId('c'));
    });

    test('repeated increase exposure keeps sorted unique timeline indexes', () {
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 1, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
            Frame(id: const FrameId('c'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            2: TimelineExposure.drawing(const FrameId('b')),
            3: TimelineExposure.drawing(const FrameId('c')),
          },
        ),
      );

      for (var count = 0; count < 5; count += 1) {
        expect(
          () => fixture.controller.increaseExposure(
            layerId: const LayerId('layer'),
            frameId: const FrameId('a'),
          ),
          returnsNormally,
        );
        _expectSortedUniqueTimelineIndexes(_latestLayer(fixture.repository));
      }

      expect(_latestLayer(fixture.repository).timeline.keys, [0, 7, 8]);
    });

    test('decrease exposure does not create duplicate indexes', () {
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 5, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
            Frame(id: const FrameId('c'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            4: TimelineExposure.drawing(const FrameId('b')),
            5: TimelineExposure.drawing(const FrameId('c')),
          },
        ),
      );

      expect(
        () => fixture.controller.decreaseExposure(
          layerId: const LayerId('layer'),
          frameId: const FrameId('a'),
        ),
        returnsNormally,
      );

      final timeline = _latestLayer(fixture.repository).timeline;
      expect(timeline.keys, orderedEquals([0, 3, 5]));
      expect(timeline[3]?.frameId, const FrameId('b'));
      expect(timeline[5]?.frameId, const FrameId('c'));
      _expectSortedUniqueTimelineIndexes(_latestLayer(fixture.repository));
    });

    test('undo and redo restore collision-chain timeline map', () {
      final history = HistoryManager();
      final fixture = _fixture(
        Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: [
            Frame(id: const FrameId('a'), duration: 4, strokes: const []),
            Frame(id: const FrameId('b'), duration: 1, strokes: const []),
          ],
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            5: const TimelineExposure.blank(),
            6: TimelineExposure.drawing(const FrameId('b')),
          },
        ),
        historyManager: history,
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      expect(_latestLayer(fixture.repository).timeline.keys, [0, 6, 7]);

      history.undo();
      expect(_latestLayer(fixture.repository).timeline.keys, [0, 5, 6]);
      expect(
        _latestLayer(fixture.repository).timeline[5]?.type,
        TimelineExposureType.blank,
      );

      history.redo();
      expect(_latestLayer(fixture.repository).timeline.keys, [0, 6, 7]);
      expect(
        _latestLayer(fixture.repository).timeline[6]?.type,
        TimelineExposureType.blank,
      );
      expect(
        _latestLayer(fixture.repository).timeline[7]?.frameId,
        const FrameId('b'),
      );
    });
  });
}

const _cutId = CutId('cut');

_TimelineMapFixture _fixture(Layer layer, {HistoryManager? historyManager}) {
  final repository = ProjectRepository(initialProject: _project(layer));
  final controller = TimelineController(
    repository: repository,
    historyManager: historyManager,
    cutId: _cutId,
  );
  return _TimelineMapFixture(
    repository: repository,
    controller: controller,
    layer: layer,
  );
}

Project _project(Layer layer) {
  return Project(
    id: const ProjectId('project'),
    name: 'Project',
    createdAt: DateTime.utc(2026),
    tracks: [
      Track(
        id: const TrackId('track'),
        name: 'Track',
        cuts: [
          Cut(
            id: _cutId,
            name: 'Cut',
            duration: 1,
            canvasSize: const CanvasSize(width: 100, height: 100),
            layers: [layer],
          ),
        ],
      ),
    ],
  );
}

Layer _latestLayer(ProjectRepository repository) {
  return repository.requireProject().tracks.single.cuts.single.layers.single;
}

void _expectSortedUniqueTimelineIndexes(Layer layer) {
  final indexes = layer.timeline.keys.toList(growable: false);
  final sortedIndexes = indexes.toList(growable: false)..sort();
  expect(indexes.toSet(), hasLength(indexes.length));
  expect(indexes, orderedEquals(sortedIndexes));
}

class _TimelineMapFixture {
  const _TimelineMapFixture({
    required this.repository,
    required this.controller,
    required this.layer,
  });

  final ProjectRepository repository;
  final TimelineController controller;
  final Layer layer;
}
