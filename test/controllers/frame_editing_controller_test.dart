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

    test('delete cell does nothing on blank start / X', () {
      final fixture = _fixture(_editingLayer());
      fixture.controller.selectFrameIndex(3);

      fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));

      expect(_latestLayer(fixture.repository), _editingLayer());
    });

    test('delete cell does nothing on mark-only cell', () {
      final markOnlyLayer = Layer(
        id: const LayerId('layer'),
        name: 'Layer',
        frames: const [],
        timeline: const {4: TimelineExposure.mark()},
      );
      final fixture = _fixture(markOnlyLayer);
      fixture.controller.selectFrameIndex(4);

      fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));

      expect(_latestLayer(fixture.repository), markOnlyLayer);
    });

    test(
      'delete drawing start removes entry and unreferenced backing frame',
      () {
        final fixture = _fixture(_editingLayer(markIndex: 2));
        fixture.controller.selectFrameIndex(5);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.timeline.keys, orderedEquals([0, 2, 9]));
        expect(
          layer.frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a')]),
        );
        expect(layer.timeline[2], const TimelineExposure.mark());
        expect(layer.timeline[9]?.frameId, const FrameId('a'));
      },
    );

    test('delete drawing start keeps unrelated marks in the timeline', () {
      final fixture = _fixture(_editingLayer(markIndex: 7));
      fixture.controller.selectFrameIndex(5);

      fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
      final layer = _latestLayer(fixture.repository);

      expect(layer.timeline.keys, orderedEquals([0, 7, 9]));
      expect(
        layer.frames.map((frame) => frame.id),
        orderedEquals([const FrameId('a')]),
      );
      expect(layer.timeline[7], const TimelineExposure.mark());
    });

    test(
      'delete drawing start keeps backing frame while referenced elsewhere',
      () {
        final fixture = _fixture(_editingLayer());
        fixture.controller.selectFrameIndex(9);

        fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        final layer = _latestLayer(fixture.repository);

        expect(layer.timeline.keys, orderedEquals([0, 5]));
        expect(
          layer.frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a'), const FrameId('b')]),
        );
        expect(layer.timeline[0]?.frameId, const FrameId('a'));
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

        final emptyLayer = Layer(
          id: const LayerId('layer'),
          name: 'Layer',
          frames: const [],
          timeline: const {},
        );
        final empty = _fixture(emptyLayer);
        empty.controller.selectFrameIndex(4);
        empty.controller.deleteCellForLayer(layerId: const LayerId('layer'));
        expect(_latestLayer(empty.repository), emptyLayer);
      },
    );

    test('delete drawing start is undo and redo able', () {
      final history = HistoryManager();
      final fixture = _fixture(_editingLayer(), historyManager: history);
      fixture.controller.selectFrameIndex(5);

      fixture.controller.deleteCellForLayer(layerId: const LayerId('layer'));
      expect(_latestLayer(fixture.repository).timeline.containsKey(5), isFalse);

      history.undo();
      expect(
        _latestLayer(fixture.repository).timeline[5]?.frameId,
        const FrameId('b'),
      );

      history.redo();
      expect(_latestLayer(fixture.repository).timeline.containsKey(5), isFalse);
    });

    test('mark toggle can still remove marks', () {
      final fixture = _fixture(_editingLayer(markIndex: 4));
      fixture.controller.selectFrameIndex(4);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));

      final layer = _latestLayer(fixture.repository);
      expect(layer.timeline.containsKey(4), isFalse);
      expect(layer.timeline, _editingLayer().timeline);
    });

    test('can delete and rename checks match follow-up cell rules', () {
      final fixture = _fixture(_editingLayer(markIndex: 4));
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
        isFalse,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 5),
        isTrue,
      );
      expect(
        fixture.controller.canDeleteCellAt(layer: layer, frameIndex: 3),
        isFalse,
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

/// a[0,3) .. X[3,5) .. b[5,9) .. a[9,12); optional mark entry.
Layer _editingLayer({int? markIndex}) {
  final timeline = <int, TimelineExposure>{
    0: TimelineExposure.drawing(const FrameId('a'), length: 3),
    5: TimelineExposure.drawing(const FrameId('b'), length: 4),
    9: TimelineExposure.drawing(const FrameId('a'), length: 3),
  };
  if (markIndex != null) {
    timeline[markIndex] = const TimelineExposure.mark();
  }
  return Layer(
    id: const LayerId('layer'),
    name: 'Layer',
    frames: [
      Frame(id: const FrameId('a'), duration: 3, strokes: const []),
      Frame(id: const FrameId('b'), duration: 4, strokes: const []),
    ],
    timeline: timeline,
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
