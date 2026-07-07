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

/// Inbetween marks in the UNIFIED timeline map: one entry per index, a mark
/// or a drawing — marks live on held or empty cells only and never affect
/// blocks or canvas resolution.
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

    test('toggle mark on and off records a mark entry without touching the '
        'drawing block', () {
      final fixture = _fixture(_markedTestLayer());
      fixture.controller.selectFrameIndex(4);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      var layer = _latestLayer(fixture.repository);
      expect(layer.timeline[4], const TimelineExposure.mark());
      expect(layer.frames, hasLength(1));
      expect(layer.timeline[0]!.isDrawing, isTrue);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      layer = _latestLayer(fixture.repository);
      expect(layer.timeline.containsKey(4), isFalse);
      expect(layer.frames, hasLength(1));
    });

    test(
      'marks are allowed on held and empty cells but not drawing starts',
      () {
        final fixture = _fixture(_markedTestLayer());

        expect(
          fixture.controller.canToggleMarkAt(
            layer: fixture.layer,
            frameIndex: 0,
          ),
          isFalse,
        );
        for (final index in [1, 4, 8]) {
          expect(
            fixture.controller.canToggleMarkAt(
              layer: fixture.layer,
              frameIndex: index,
            ),
            isTrue,
            reason: 'index $index',
          );
        }

        // Toggling on the drawing start is a no-op.
        fixture.controller.selectFrameIndex(0);
        fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
        expect(_latestLayer(fixture.repository).timeline[0]!.isDrawing, isTrue);
      },
    );

    test('marks never affect blocks, canvas resolution, or block length', () {
      final fixture = _fixture(_markedTestLayer());
      fixture.controller.selectFrameIndex(1);
      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      fixture.controller.selectFrameIndex(4);
      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));

      final layer = _latestLayer(fixture.repository);
      // Mark inside the hold: the covering frame still shows.
      expect(
        fixture.controller.resolveFrameIdForLayer(layer: layer, frameIndex: 1),
        const FrameId('a'),
      );
      // Mark in empty space: no block forms and nothing shows.
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
    });

    test('undo and redo mark add and remove', () {
      final history = HistoryManager();
      final fixture = _fixture(_markedTestLayer(), historyManager: history);
      fixture.controller.selectFrameIndex(2);

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      expect(
        _latestLayer(fixture.repository).timeline[2],
        const TimelineExposure.mark(),
      );

      history.undo();
      expect(_latestLayer(fixture.repository).timeline.containsKey(2), isFalse);

      history.redo();
      expect(
        _latestLayer(fixture.repository).timeline[2],
        const TimelineExposure.mark(),
      );

      fixture.controller.toggleMarkForLayer(layerId: const LayerId('layer'));
      expect(_latestLayer(fixture.repository).timeline.containsKey(2), isFalse);

      history.undo();
      expect(
        _latestLayer(fixture.repository).timeline[2],
        const TimelineExposure.mark(),
      );
    });
  });
}

const _cutId = CutId('cut');

/// Drawing block [0,3), empty (X) cells from 3 on.
Layer _markedTestLayer() {
  return Layer(
    id: const LayerId('layer'),
    name: 'Layer',
    frames: [Frame(id: const FrameId('a'), duration: 3, strokes: const [])],
    timeline: {0: TimelineExposure.drawing(const FrameId('a'), length: 3)},
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
