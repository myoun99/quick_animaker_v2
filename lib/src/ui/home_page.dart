import 'package:flutter/material.dart';

import '../controllers/canvas_controller.dart';
import '../controllers/layer_controller.dart';
import '../models/canvas_size.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/project.dart';
import '../models/project_id.dart';
import '../models/track.dart';
import '../models/track_id.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';
import 'canvas/canvas_view.dart';
import 'layers/layer_panel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const CutId _cutId = CutId('sample-cut');
  static const FrameId _frameId = FrameId('sample-frame');

  late final ProjectRepository _repository;
  late final HistoryManager _historyManager;
  late final CanvasController _canvasController;
  late final LayerController _layerController;

  int _layerSequence = 2;

  @override
  void initState() {
    super.initState();
    _repository = ProjectRepository(initialProject: _createSampleProject());
    _historyManager = HistoryManager();
    _layerController = LayerController(
      repository: _repository,
      historyManager: _historyManager,
      cutId: _cutId,
      frameId: _frameId,
    );
    _canvasController = CanvasController(
      repository: _repository,
      historyManager: _historyManager,
      frameId: _frameId,
      getCurrentFrameId: () => _layerController.frameId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QuickAnimaker v2.1')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Text('Active strokes: ${_canvasController.strokes.length}'),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: _canvasController.canUndo
                      ? () => setState(_canvasController.undo)
                      : null,
                  child: const Text('Undo'),
                ),
                TextButton(
                  onPressed: _canvasController.canRedo
                      ? () => setState(_canvasController.redo)
                      : null,
                  child: const Text('Redo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFBDBDBD)),
                      ),
                      child: CanvasView(
                        controller: _canvasController,
                        cutId: _cutId,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ),
                ),
                LayerPanel(
                  layers: _layerController.layers,
                  activeLayerId: _layerController.activeLayerId,
                  onSelectLayer: (layerId) {
                    setState(() => _layerController.selectLayer(layerId));
                  },
                  onAddLayer: () {
                    setState(() {
                      _layerSequence += 1;
                      _layerController.addLayerWithDefaults(
                        layerId: LayerId('sample-layer-$_layerSequence'),
                        name: 'Layer $_layerSequence',
                      );
                    });
                  },
                  onToggleVisibility: (layerId) {
                    setState(() {
                      _layerController.toggleLayerVisibility(layerId);
                    });
                  },
                  onOpacityChanged: (layerId, opacity) {
                    setState(() {
                      _layerController.setLayerOpacity(
                        layerId: layerId,
                        opacity: opacity,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Project _createSampleProject() {
    return Project(
      id: const ProjectId('sample-project'),
      name: 'Sample Project',
      createdAt: DateTime.utc(2026),
      tracks: [
        Track(
          id: const TrackId('sample-track'),
          name: 'Video Track',
          cuts: [
            Cut(
              id: _cutId,
              name: 'Cut 1',
              duration: 1,
              canvasSize: const CanvasSize(width: 1280, height: 720),
              layers: [
                Layer(
                  id: const LayerId('sample-layer-1'),
                  name: 'Layer 1',
                  frames: [Frame(id: _frameId, duration: 1, strokes: const [])],
                ),
                Layer(
                  id: const LayerId('sample-layer-2'),
                  name: 'Layer 2',
                  frames: [
                    Frame(
                      id: const FrameId('sample-frame-layer-2'),
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
}
