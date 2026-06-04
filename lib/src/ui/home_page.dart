import 'package:flutter/material.dart';

import '../controllers/canvas_controller.dart';
import '../controllers/layer_controller.dart';
import '../controllers/timeline_controller.dart';
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
import 'timeline/timeline_cell_exposure_state.dart';
import 'timeline/timeline_orientation.dart';
import 'timeline/timeline_panel.dart';

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
  late final TimelineController _timelineController;

  int _layerSequence = 2;
  int _frameSequence = 0;
  TimelineOrientation _timelineOrientation = TimelineOrientation.horizontal;

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
    _timelineController = TimelineController(
      repository: _repository,
      cutId: _cutId,
    );
    _canvasController = CanvasController(
      repository: _repository,
      historyManager: _historyManager,
      frameId: _frameId,
      layerController: _layerController,
      timelineController: _timelineController,
    );
  }

  Layer? get _activeLayer => _layerController.activeLayer;

  Frame? get _selectedFrame {
    final layer = _activeLayer;
    if (layer == null) {
      return null;
    }

    return _timelineController.getSelectedFrameForLayer(layer);
  }

  void _createDrawingAtCurrentFrame() {
    final layer = _activeLayer;
    if (layer == null || _selectedFrame != null) {
      return;
    }

    _frameSequence += 1;
    _timelineController.createDrawingFrameForLayer(
      layerId: layer.id,
      frameId: FrameId(_nextFrameId(layer.id)),
    );
  }

  String _nextFrameId(LayerId layerId) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return 'ui-frame-${layerId.value}-$timestamp-$_frameSequence';
  }

  void _increaseSelectedExposure() {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null) {
      return;
    }

    _timelineController.increaseExposure(layerId: layer.id, frameId: frame.id);
  }

  void _decreaseSelectedExposure() {
    final layer = _activeLayer;
    final frame = _selectedFrame;
    if (layer == null || frame == null || frame.duration <= 1) {
      return;
    }

    _timelineController.decreaseExposure(layerId: layer.id, frameId: frame.id);
  }

  TimelineCellExposureState _exposureStateForLayer(
    Layer layer,
    int frameIndex,
  ) {
    if (_timelineController.isDrawingStartForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.drawingStart;
    }

    if (_timelineController.isHeldExposureForLayer(
      layer: layer,
      frameIndex: frameIndex,
    )) {
      return TimelineCellExposureState.heldExposure;
    }

    return TimelineCellExposureState.empty;
  }

  @override
  Widget build(BuildContext context) {
    final activeLayer = _activeLayer;
    final selectedFrame = _selectedFrame;

    return Scaffold(
      appBar: AppBar(title: const Text('QuickAnimaker v2.1')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('Active strokes: ${_canvasController.strokes.length}'),
                  const SizedBox(width: 16),
                  Text(
                    'Current frame: ${_timelineController.currentFrameIndex}',
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Selected: ${activeLayer?.name ?? 'No layer'} / Frame '
                    '${_timelineController.currentFrameIndex}',
                  ),
                  const SizedBox(width: 16),
                  Text('Drawing: ${selectedFrame == null ? 'no' : 'yes'}'),
                  const SizedBox(width: 16),
                  Text('Duration: ${selectedFrame?.duration ?? '-'}'),
                  const SizedBox(width: 16),
                  TextButton(
                    key: const ValueKey<String>('new-drawing-button'),
                    onPressed: activeLayer != null && selectedFrame == null
                        ? () => setState(_createDrawingAtCurrentFrame)
                        : null,
                    child: const Text('New Drawing'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('decrease-exposure-button'),
                    onPressed:
                        selectedFrame != null && selectedFrame.duration > 1
                        ? () => setState(_decreaseSelectedExposure)
                        : null,
                    child: const Text('- Exposure'),
                  ),
                  TextButton(
                    key: const ValueKey<String>('increase-exposure-button'),
                    onPressed: selectedFrame != null
                        ? () => setState(_increaseSelectedExposure)
                        : null,
                    child: const Text('+ Exposure'),
                  ),
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
          ),
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
          TimelinePanel(
            layers: _layerController.layers,
            activeLayerId: _layerController.activeLayerId,
            currentFrameIndex: _timelineController.currentFrameIndex,
            frameCount: _timelineController.totalFrameCount,
            exposureStateForLayer: _exposureStateForLayer,
            onSelectLayer: (layerId) {
              setState(() => _layerController.selectLayer(layerId));
            },
            onSelectFrame: (frameIndex) {
              setState(() => _timelineController.selectFrameIndex(frameIndex));
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
            onToggleLayerVisibility: (layerId) {
              setState(() {
                _layerController.toggleLayerVisibility(layerId);
              });
            },
            onLayerOpacityChanged: (layerId, opacity) {
              setState(() {
                _layerController.setLayerOpacity(
                  layerId: layerId,
                  opacity: opacity,
                );
              });
            },
            orientation: _timelineOrientation,
            onOrientationChanged: (orientation) {
              setState(() => _timelineOrientation = orientation);
            },
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
                  frames: const [],
                ),
                Layer(
                  id: const LayerId('sample-layer-2'),
                  name: 'Layer 2',
                  frames: const [],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
