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
  group('Frame editing timeline controller', () {
    test('renames frame by ID, trims whitespace, and clears empty names', () {
      final fixture = _fixture(_editingLayer());

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
        name: '  A1  ',
      );
      expect(
        _frame(_latestLayer(fixture.repository), const FrameId('a')).name,
        'A1',
      );

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
        name: '   ',
      );
      expect(
        _frame(_latestLayer(fixture.repository), const FrameId('a')).name,
        isNull,
      );
    });

    test('rename is undo and redo able', () {
      final history = HistoryManager();
      final fixture = _fixture(_editingLayer(), historyManager: history);

      fixture.controller.renameFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
        name: 'A1',
      );
      expect(
        _frame(_latestLayer(fixture.repository), const FrameId('a')).name,
        'A1',
      );

      history.undo();
      expect(
        _frame(_latestLayer(fixture.repository), const FrameId('a')).name,
        isNull,
      );

      history.redo();
      expect(
        _frame(_latestLayer(fixture.repository), const FrameId('a')).name,
        'A1',
      );
    });

    test(
      'delete cell removes mark first without changing frame resolution',
      () {
        final fixture = _fixture(
          _editingLayer(marks: const {5: TimelineMark.inbetween()}),
        );
        fixture.controller.selectFrameIndex(5);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.marks, isEmpty);
        expect(layer.timeline.keys, orderedEquals([0, 3, 5, 9]));
        expect(
          fixture.controller.resolveFrameIdForLayer(
            layer: layer,
            frameIndex: 5,
          ),
          const FrameId('b'),
        );
      },
    );

    test(
      'delete drawing start removes entry and unreferenced backing frame',
      () {
        final fixture = _fixture(
          _editingLayer(marks: const {2: TimelineMark.inbetween()}),
        );
        fixture.controller.selectFrameIndex(5);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.timeline.keys, orderedEquals([0, 3, 9]));
        expect(
          layer.frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a')]),
        );
        expect(layer.marks.keys, orderedEquals([2]));
        expect(layer.timeline[9]?.frameId, const FrameId('a'));
      },
    );

    test(
      'delete drawing start keeps backing frame while referenced elsewhere',
      () {
        final fixture = _fixture(_editingLayer());
        fixture.controller.selectFrameIndex(9);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.timeline.keys, orderedEquals([0, 3, 5]));
        expect(
          layer.frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a'), const FrameId('b')]),
        );
        expect(layer.timeline[0]?.frameId, const FrameId('a'));
      },
    );

    test(
      'delete blank start removes only blank entry and previous drawing holds through',
      () {
        final fixture = _fixture(_editingLayer());
        fixture.controller.selectFrameIndex(3);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.timeline.keys, orderedEquals([0, 5, 9]));
        expect(
          layer.frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a'), const FrameId('b')]),
        );
        expect(
          fixture.controller.resolveFrameIdForLayer(
            layer: layer,
            frameIndex: 4,
          ),
          const FrameId('a'),
        );
      },
    );

    test(
      'delete cell does nothing on held drawing, blank held, and empty cells',
      () {
        final drawingHeld = _fixture(_editingLayer());
        drawingHeld.controller.selectFrameIndex(1);
        drawingHeld.controller.deleteCellForLayer(
          layerId: const LayerId('layer'),
        );
        expect(_latestLayer(drawingHeld.repository), _editingLayer());

        final blankHeld = _fixture(_editingLayer());
        blankHeld.controller.selectFrameIndex(4);
        blankHeld.controller.deleteCellForLayer(
          layerId: const LayerId('layer'),
        );
        expect(_latestLayer(blankHeld.repository), _editingLayer());

        final empty = _fixture(
          Layer(
            id: const LayerId('layer'),
            name: 'Layer',
            frames: const [],
            timeline: const {},
          ),
        );
        empty.controller.selectFrameIndex(4);
        empty.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        expect(_latestLayer(empty.repository).timeline, isEmpty);
      },
    );

    test('delete operations are undo and redo able', () {
      final markHistory = HistoryManager();
      final markFixture = _fixture(
        _editingLayer(marks: const {1: TimelineMark.inbetween()}),
        historyManager: markHistory,
      );
      markFixture.controller.selectFrameIndex(1);
      markFixture.controller.deleteCellForLayer(
        layerId: const LayerId('layer'),
      );
      expect(_latestLayer(markFixture.repository).marks, isEmpty);
      markHistory.undo();
      expect(
        _latestLayer(markFixture.repository).marks[1],
        const TimelineMark.inbetween(),
      );
      markHistory.redo();
      expect(_latestLayer(markFixture.repository).marks, isEmpty);

      final drawingHistory = HistoryManager();
      final drawingFixture = _fixture(
        _editingLayer(),
        historyManager: drawingHistory,
      );
      drawingFixture.controller.selectFrameIndex(5);
      drawingFixture.controller.deleteCellForLayer(
        layerId: const LayerId('layer'),
      );
      expect(
        _latestLayer(drawingFixture.repository).timeline.containsKey(5),
        isFalse,
      );
      drawingHistory.undo();
      expect(
        _latestLayer(drawingFixture.repository).timeline[5]?.frameId,
        const FrameId('b'),
      );
      drawingHistory.redo();
      expect(
        _latestLayer(drawingFixture.repository).timeline.containsKey(5),
        isFalse,
      );

      final blankHistory = HistoryManager();
      final blankFixture = _fixture(
        _editingLayer(),
        historyManager: blankHistory,
      );
      blankFixture.controller.selectFrameIndex(3);
      blankFixture.controller.deleteCellForLayer(
        layerId: const LayerId('layer'),
      );
      expect(
        _latestLayer(blankFixture.repository).timeline.containsKey(3),
        isFalse,
      );
      blankHistory.undo();
      expect(
        _latestLayer(blankFixture.repository).timeline[3],
        const TimelineExposure.blank(),
      );
      blankHistory.redo();
      expect(
        _latestLayer(blankFixture.repository).timeline.containsKey(3),
        isFalse,
      );
    });

    test('can delete and rename checks match Phase 16 cell rules', () {
      final fixture = _fixture(
        _editingLayer(marks: const {4: TimelineMark.inbetween()}),
      );
      final layer = fixture.layer;

      expect(
        fixture.controller.canRenameFrameAt(layer: layer, frameIndex: 1),
        isTrue,
      );
      expect(
        fixture.controller.canRenameFrameAt(layer: layer, frameIndex: 4),
        isFalse,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 4),
        isTrue,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 5),
        isTrue,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 3),
        isTrue,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 1),
        isFalse,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: -1),
        isFalse,
      );
    });
  });
}

const _cutId = CutId('cut');

Layer _editingLayer({Map<int, TimelineMark> marks = const {}}) {
  return Layer(
    id: const LayerId('layer'),
    name: 'Layer',
    frames: [
      Frame(id: const FrameId('a'), duration: 3, strokes: const []),
      Frame(id: const FrameId('b'), duration: 4, strokes: const []),
    ],
    timeline: {
      0: TimelineExposure.drawing(const FrameId('a')),
      3: const TimelineExposure.blank(),
      5: TimelineExposure.drawing(const FrameId('b')),
      9: TimelineExposure.drawing(const FrameId('a')),
    },
    marks: marks,
  );
}

_FrameEditingFixture _fixture(Layer layer, {HistoryManager? historyManager}) {
  final repository = ProjectRepository(initialProject: _project(layer));
  final controller = TimelineController(
    repository: repository,
    cutId: _cutId,
    historyManager: historyManager,
  );
  return _FrameEditingFixture(
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
            duration: 24,
            canvasSize: const CanvasSize(width: 1920, height: 1080),
            layers: [layer],
          ),
        ],
      ),
    ],
  );
}

Layer _latestLayer(ProjectRepository repository) {
  return repository.currentProject!.tracks.single.cuts.single.layers.single;
}

Frame _frame(Layer layer, FrameId frameId) {
  return layer.frames.singleWhere((frame) => frame.id == frameId);
}

class _FrameEditingFixture {
  const _FrameEditingFixture({
    required this.repository,
    required this.controller,
    required this.layer,
  });

  final ProjectRepository repository;
  final TimelineController controller;
  final Layer layer;
}
