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
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('Timeline marks', () {
    test('empty layer has no mark and rejects negative toggle checks', () {
      final fixture = _fixture(_markedTestLayer());

      expect(
        fixture.controller.hasMarkAt(layer: fixture.layer, frameIndex: 2),
        isFalse,
      );
      expect(
        fixture.controller.canToggleMarkAt(
          layer: fixture.layer,
          frameIndex: -1,
        ),
        isFalse,
      );
    });

    test('toggle mark on and off without creating frames or exposures', () {
      final fixture = _fixture(_markedTestLayer());
      fixture.controller.selectFrameIndex(4);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      var layer = _latestLayer(fixture.repository);
      expect(layer.marks[4], const TimelineMark.inbetween());
      expect(layer.frames, hasLength(1));
      expect(layer.timeline.keys, orderedEquals([0, 3]));

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      layer = _latestLayer(fixture.repository);
      expect(layer.marks.containsKey(4), isFalse);
      expect(layer.frames, hasLength(1));
      expect(layer.timeline.keys, orderedEquals([0, 3]));
    });

    test('marks are allowed on drawing, held, blank, blank-held, and empty cells', () {
      final fixture = _fixture(_markedTestLayer());

      for (final index in [0, 1, 3, 4, 8]) {
        fixture.controller.selectFrameIndex(index);
        fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      }

      final layer = _latestLayer(fixture.repository);
      expect(layer.marks.keys, orderedEquals([0, 1, 3, 4, 8]));
    });

    test('marks do not affect drawing, blank, duration, or exposure edits', () {
      final fixture = _fixture(_markedTestLayer());
      fixture.controller.selectFrameIndex(1);
      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      fixture.controller.selectFrameIndex(4);
      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      fixture.controller.selectFrameIndex(8);
      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));

      var layer = _latestLayer(fixture.repository);
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('a'),
      );
      expect(
        fixture.controller.resolveFrameForLayer(layer: layer, frameIndex: 4),
        isNull,
      );
      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        3,
      );

      fixture.controller.increaseExposure(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      layer = _latestLayer(fixture.repository);
      expect(layer.marks.keys, orderedEquals([1, 4, 8]));
      expect(layer.timeline.keys, orderedEquals([0, 4]));

      fixture.controller.decreaseExposure(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      layer = _latestLayer(fixture.repository);
      expect(layer.marks.keys, orderedEquals([1, 4, 8]));
      expect(layer.timeline.keys, orderedEquals([0, 3]));
    });

    test('undo and redo mark add and remove', () {
      final history = HistoryManager();
      final fixture = _fixture(_markedTestLayer(), historyManager: history);
      fixture.controller.selectFrameIndex(2);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      expect(
        _latestLayer(fixture.repository).marks[2],
        const TimelineMark.inbetween(),
      );

      history.undo();
      expect(_latestLayer(fixture.repository).marks, isEmpty);

      history.redo();
      expect(
        _latestLayer(fixture.repository).marks[2],
        const TimelineMark.inbetween(),
      );

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      expect(_latestLayer(fixture.repository).marks, isEmpty);

      history.undo();
      expect(
        _latestLayer(fixture.repository).marks[2],
        const TimelineMark.inbetween(),
      );

      history.redo();
      expect(_latestLayer(fixture.repository).marks, isEmpty);
    });
  });
}

const _cutId = CutId('cut');

Layer _markedTestLayer() {
  return Layer(
    id: const LayerId('layer'),
    name: 'Layer',
    frames: [Frame(id: const FrameId('a'), duration: 3, strokes: const [])],
    timeline: {
      0: TimelineExposure.drawing(const FrameId('a')),
      3: const TimelineExposure.blank(),
    },
  );
}

_TimelineMarkFixture _fixture(Layer layer, {HistoryManager? historyManager}) {
  final repository = ProjectRepository(initialProject: _project(layer));
  final controller = TimelineController(
    repository: repository,
    historyManager: historyManager,
    cutId: _cutId,
  );
  return _TimelineMarkFixture(
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

class _TimelineMarkFixture {
  const _TimelineMarkFixture({
    required this.repository,
    required this.controller,
    required this.layer,
  });

  final ProjectRepository repository;
  final TimelineController controller;
  final Layer layer;
}
