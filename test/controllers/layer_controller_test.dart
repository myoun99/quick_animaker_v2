import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/layer_controller.dart';
import 'package:quick_animaker_v2/src/models/canvas_size.dart';
import 'package:quick_animaker_v2/src/models/cut.dart';
import 'package:quick_animaker_v2/src/models/cut_id.dart';
import 'package:quick_animaker_v2/src/models/frame.dart';
import 'package:quick_animaker_v2/src/models/frame_id.dart';
import 'package:quick_animaker_v2/src/models/layer.dart';
import 'package:quick_animaker_v2/src/models/layer_id.dart';
import 'package:quick_animaker_v2/src/models/project.dart';
import 'package:quick_animaker_v2/src/models/project_id.dart';
import 'package:quick_animaker_v2/src/models/timeline_exposure_type.dart';
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';

void main() {
  group('LayerController', () {
    test('exposes layers', () {
      final fixture = _createFixture();

      expect(fixture.controller.layers, hasLength(2));
    });

    test('selects active layer', () {
      final fixture = _createFixture();

      fixture.controller.selectLayer(const LayerId('layer-2'));

      expect(fixture.controller.activeLayerId, const LayerId('layer-2'));
      expect(fixture.controller.activeLayer?.name, 'Layer 2');
    });

    test('adds a layer', () {
      final fixture = _createFixture();

      fixture.controller.addLayerWithDefaults(
        layerId: const LayerId('layer-3'),
        name: 'Layer 3',
      );

      expect(fixture.controller.layers, hasLength(3));
      fixture.controller.selectLayer(const LayerId('layer-3'));
      expect(fixture.controller.activeLayer?.name, 'Layer 3');
      expect(fixture.controller.activeLayer?.frames, isEmpty);
      expect(fixture.controller.activeLayer?.timeline, hasLength(1));
      expect(
        fixture.controller.activeLayer?.timeline[0]?.type,
        TimelineExposureType.blank,
      );
    });

    test('toggles visibility', () {
      final fixture = _createFixture();

      fixture.controller.toggleLayerVisibility(const LayerId('layer-1'));
      expect(
        _findLayer(fixture.repository, const LayerId('layer-1')).isVisible,
        isFalse,
      );

      fixture.controller.toggleLayerVisibility(const LayerId('layer-1'));
      expect(
        _findLayer(fixture.repository, const LayerId('layer-1')).isVisible,
        isTrue,
      );
    });

    test('sets opacity', () {
      final fixture = _createFixture();

      fixture.controller.setLayerOpacity(
        layerId: const LayerId('layer-1'),
        opacity: 0.5,
      );

      expect(
        _findLayer(fixture.repository, const LayerId('layer-1')).opacity,
        0.5,
      );
    });

    test('throws for missing layers', () {
      final fixture = _createFixture();

      expect(
        () => fixture.controller.selectLayer(const LayerId('missing')),
        throwsStateError,
      );
      expect(
        () =>
            fixture.controller.toggleLayerVisibility(const LayerId('missing')),
        throwsStateError,
      );
      expect(
        () => fixture.controller.setLayerOpacity(
          layerId: const LayerId('missing'),
          opacity: 0.5,
        ),
        throwsStateError,
      );
    });
  });
}

const _cutId = CutId('cut-1');
const _frameId = FrameId('frame-1');

_LayerFixture _createFixture() {
  final repository = ProjectRepository(initialProject: _createSampleProject());
  final controller = LayerController(
    repository: repository,
    historyManager: HistoryManager(),
    cutId: _cutId,
    frameId: _frameId,
  );

  return _LayerFixture(repository: repository, controller: controller);
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
                frames: [Frame(id: _frameId, duration: 1, strokes: const [])],
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

class _LayerFixture {
  const _LayerFixture({required this.repository, required this.controller});

  final ProjectRepository repository;
  final LayerController controller;
}
