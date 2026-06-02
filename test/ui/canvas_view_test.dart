import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_animaker_v2/src/controllers/canvas_controller.dart';
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
import 'package:quick_animaker_v2/src/models/track.dart';
import 'package:quick_animaker_v2/src/models/track_id.dart';
import 'package:quick_animaker_v2/src/services/history_manager.dart';
import 'package:quick_animaker_v2/src/services/project_repository.dart';
import 'package:quick_animaker_v2/src/ui/canvas/canvas_view.dart';

void main() {
  testWidgets('CanvasView renders', (tester) async {
    final fixture = _createFixture();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CanvasView(controller: fixture.controller, cutId: _cutId),
          ),
        ),
      ),
    );

    expect(find.byType(CanvasView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag gesture creates stroke in active layer', (tester) async {
    final fixture = _createFixture();
    fixture.layerController.selectLayer(const LayerId('layer-2'));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: CanvasView(controller: fixture.controller, cutId: _cutId),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(CanvasView), const Offset(50, 50));
    await tester.pump();

    expect(
      _findLayerFrame(fixture.repository, const LayerId('layer-1')).strokes,
      isEmpty,
    );
    expect(
      _findLayerFrame(fixture.repository, const LayerId('layer-2')).strokes,
      hasLength(1),
    );
  });
}

const _cutId = CutId('cut-1');
const _frameId = FrameId('frame-1');

_CanvasFixture _createFixture() {
  final repository = ProjectRepository(initialProject: _createSampleProject());
  final historyManager = HistoryManager();
  final layerController = LayerController(
    repository: repository,
    historyManager: historyManager,
    cutId: _cutId,
    frameId: _frameId,
  );
  final controller = CanvasController(
    repository: repository,
    historyManager: historyManager,
    frameId: _frameId,
    getCurrentFrameId: () => layerController.frameId,
  );

  return _CanvasFixture(
    repository: repository,
    controller: controller,
    layerController: layerController,
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

class _CanvasFixture {
  const _CanvasFixture({
    required this.repository,
    required this.controller,
    required this.layerController,
  });

  final ProjectRepository repository;
  final CanvasController controller;
  final LayerController layerController;
}
