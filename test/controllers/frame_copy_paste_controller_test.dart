import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/timeline_controller.dart';
import 'package:quick_animaker_v2/src/models/brush_settings.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/stroke.dart';
import 'package:quick_animaker_v2/src/models/stroke_id.dart';
import 'package:quick_animaker_v2/src/models/stroke_point.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';
import 'package:quick_animaker_v2/src/models/timeline_mark.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('linked frame copy/paste controller APIs', () {
    test('canPasteLinkedFrameAt validates index and frame existence', () {
      final fixture = _fixture(_layer());
      final layer = fixture.layer;

      expect(
        fixture.controller.canPasteLinkedFrameAt(
          layer: layer,
          frameIndex: -1,
          copiedFrameId: const FrameId('a'),
        ),
        isFalse,
      );
      expect(
        fixture.controller.canPasteLinkedFrameAt(
          layer: layer,
          frameIndex: 0,
          copiedFrameId: const FrameId('missing'),
        ),
        isFalse,
      );
      expect(
        fixture.controller.canPasteLinkedFrameAt(
          layer: layer,
          frameIndex: 0,
          copiedFrameId: const FrameId('a'),
        ),
        isTrue,
      );
    });

    test('paste linked frame on X replaces blank entry with drawing entry', () {
      final fixture = _fixture(_layer());
      fixture.controller.selectFrameIndex(3);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      final layer = _latestLayer(fixture.repository);

      expect(layer.timeline[3]?.type, TimelineExposureType.drawing);
      expect(layer.timeline[3]?.frameId, const FrameId('a'));
      expect(
        layer.frames.map((frame) => frame.id),
        contains(const FrameId('a')),
      );
    });

    test('paste linked frame on drawingStart replaces old drawing entry', () {
      final fixture = _fixture(_layer());
      fixture.controller.selectFrameIndex(5);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      final layer = _latestLayer(fixture.repository);

      expect(layer.timeline[5]?.frameId, const FrameId('a'));
      expect(
        layer.timeline.values.where((e) => e.frameId == const FrameId('a')),
        hasLength(3),
      );
    });

    test(
      'replacing drawingStart removes old backing frame only when unreferenced',
      () {
        final fixture = _fixture(_layer());
        fixture.controller.selectFrameIndex(5);

        fixture.controller.pasteLinkedFrameForLayer(
          layerId: const LayerId('layer'),
          frameId: const FrameId('a'),
        );

        expect(
          _latestLayer(fixture.repository).frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a')]),
        );
      },
    );

    test(
      'replacing drawingStart keeps old backing frame while still referenced',
      () {
        final fixture = _fixture(
          _layer(
            timeline: {
              0: TimelineExposure.drawing(const FrameId('a')),
              5: TimelineExposure.drawing(const FrameId('b')),
              9: TimelineExposure.drawing(const FrameId('b')),
            },
          ),
        );
        fixture.controller.selectFrameIndex(5);

        fixture.controller.pasteLinkedFrameForLayer(
          layerId: const LayerId('layer'),
          frameId: const FrameId('a'),
        );

        expect(
          _latestLayer(fixture.repository).frames.map((frame) => frame.id),
          orderedEquals([const FrameId('a'), const FrameId('b')]),
        );
        expect(
          _latestLayer(fixture.repository).timeline[9]?.frameId,
          const FrameId('b'),
        );
      },
    );

    test(
      'paste linked frame on held drawing creates authored drawingStart',
      () {
        final fixture = _fixture(_layer());
        fixture.controller.selectFrameIndex(1);

        fixture.controller.pasteLinkedFrameForLayer(
          layerId: const LayerId('layer'),
          frameId: const FrameId('b'),
        );

        expect(
          _latestLayer(fixture.repository).timeline[1]?.frameId,
          const FrameId('b'),
        );
      },
    );

    test('paste linked frame on blankHeld creates authored drawingStart', () {
      final fixture = _fixture(_layer());
      fixture.controller.selectFrameIndex(4);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );

      expect(
        _latestLayer(fixture.repository).timeline[4]?.frameId,
        const FrameId('a'),
      );
    });

    test('paste linked frame on empty creates authored drawingStart', () {
      final fixture = _fixture(_layer(timeline: const {}));
      fixture.controller.selectFrameIndex(6);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );

      expect(
        _latestLayer(fixture.repository).timeline[6]?.frameId,
        const FrameId('a'),
      );
    });

    test('paste linked frame preserves existing mark at same index', () {
      final fixture = _fixture(
        _layer(marks: const {3: TimelineMark.inbetween()}),
      );
      fixture.controller.selectFrameIndex(3);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );

      expect(
        _latestLayer(fixture.repository).marks[3],
        const TimelineMark.inbetween(),
      );
    });

    test('paste linked frame does not create a new Frame or clone strokes', () {
      final fixture = _fixture(_layer());
      final beforeFrames = fixture.layer.frames;
      fixture.controller.selectFrameIndex(3);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      final layer = _latestLayer(fixture.repository);

      expect(layer.frames, beforeFrames);
      expect(_frame(layer, const FrameId('a')).strokes, _sampleStrokes);
    });

    test('pasted linked end exposure edits selected authored use only', () {
      final fixture = _fixture(
        _layer(
          timeline: {
            0: TimelineExposure.drawing(const FrameId('a')),
            4: const TimelineExposure.blank(),
          },
        ),
      );
      fixture.controller.selectFrameIndex(8);
      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );

      fixture.controller.increaseExposure(layerId: const LayerId('layer'));

      final layer = _latestLayer(fixture.repository);
      expect(layer.timeline.keys, orderedEquals([0, 4, 8]));
      expect(_frame(layer, const FrameId('a')).strokes, _sampleStrokes);
      expect(
        fixture.controller.linkedUseCountForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        2,
      );
      expect(
        fixture.controller.effectiveDurationForLayerAt(
          layer: layer,
          frameIndex: 8,
        ),
        3,
      );
      expect(
        fixture.controller.effectiveDurationForLayerFrame(
          layer: layer,
          frameId: const FrameId('a'),
        ),
        4,
      );
    });

    test('paste linked frame is undo and redo able', () {
      final history = HistoryManager();
      final fixture = _fixture(_layer(), historyManager: history);
      fixture.controller.selectFrameIndex(3);

      fixture.controller.pasteLinkedFrameForLayer(
        layerId: const LayerId('layer'),
        frameId: const FrameId('a'),
      );
      expect(
        _latestLayer(fixture.repository).timeline[3]?.frameId,
        const FrameId('a'),
      );

      history.undo();
      expect(
        _latestLayer(fixture.repository).timeline[3],
        const TimelineExposure.blank(),
      );

      history.redo();
      expect(
        _latestLayer(fixture.repository).timeline[3]?.frameId,
        const FrameId('a'),
      );
    });

    test(
      'linked use count tracks authored drawing exposures without dense frames',
      () {
        final fixture = _fixture(_layer());

        expect(
          fixture.controller.linkedUseCountForLayerFrame(
            layer: fixture.layer,
            frameId: const FrameId('b'),
          ),
          1,
        );

        fixture.controller.selectFrameIndex(3);
        fixture.controller.pasteLinkedFrameForLayer(
          layerId: const LayerId('layer'),
          frameId: const FrameId('b'),
        );
        final layer = _latestLayer(fixture.repository);

        expect(
          fixture.controller.linkedUseCountForLayerFrame(
            layer: layer,
            frameId: const FrameId('b'),
          ),
          2,
        );
        expect(layer.timeline.keys, orderedEquals([0, 3, 5, 9]));
        expect(layer.frames, hasLength(2));
      },
    );
  });
}

const _cutId = CutId('cut');
final _sampleStrokes = [
  Stroke(
    id: const StrokeId('stroke-a'),
    points: const [StrokePoint(x: 1, y: 2), StrokePoint(x: 3, y: 4)],
    brushSettings: BrushSettings(size: 8),
  ),
];

Layer _layer({
  Map<int, TimelineExposure>? timeline,
  Map<int, TimelineMark> marks = const {},
}) {
  return Layer(
    id: const LayerId('layer'),
    name: 'Layer',
    frames: [
      Frame(id: const FrameId('a'), duration: 3, strokes: _sampleStrokes),
      Frame(id: const FrameId('b'), duration: 4, strokes: const []),
    ],
    timeline:
        timeline ??
        {
          0: TimelineExposure.drawing(const FrameId('a')),
          3: const TimelineExposure.blank(),
          5: TimelineExposure.drawing(const FrameId('b')),
          9: TimelineExposure.drawing(const FrameId('a')),
        },
    marks: marks,
  );
}

_FrameCopyPasteFixture _fixture(Layer layer, {HistoryManager? historyManager}) {
  final repository = ProjectRepository(initialProject: _project(layer));
  final controller = TimelineController(
    repository: repository,
    cutId: _cutId,
    historyManager: historyManager,
  );
  return _FrameCopyPasteFixture(
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

class _FrameCopyPasteFixture {
  const _FrameCopyPasteFixture({
    required this.repository,
    required this.controller,
    required this.layer,
  });

  final ProjectRepository repository;
  final TimelineController controller;
  final Layer layer;
}
