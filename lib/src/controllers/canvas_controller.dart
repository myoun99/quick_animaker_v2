import 'package:flutter/widgets.dart';

import '../models/brush_settings.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/stroke.dart';
import '../models/stroke_id.dart';
import '../models/stroke_point.dart';
import '../services/commands/add_stroke_command.dart';
import 'layer_controller.dart';
import 'timeline_controller.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

class CanvasController {
  CanvasController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required FrameId frameId,
    FrameId Function()? getCurrentFrameId,
    LayerController? layerController,
    TimelineController? timelineController,
    BrushSettings brushSettings = const BrushSettings(),
  }) : _repository = repository,
       _historyManager = historyManager,
       _frameId = frameId,
       _getCurrentFrameId = getCurrentFrameId,
       _layerController = layerController,
       _timelineController = timelineController,
       _brushSettings = brushSettings;

  final ProjectRepository _repository;
  final HistoryManager _historyManager;
  final FrameId _frameId;
  final FrameId Function()? _getCurrentFrameId;
  final LayerController? _layerController;
  final TimelineController? _timelineController;
  final BrushSettings _brushSettings;
  final List<StrokePoint> _activePoints = <StrokePoint>[];

  int _strokeSequence = 0;

  FrameId get currentFrameId =>
      _resolveCurrentFrameId(createIfMissing: false) ??
      _getCurrentFrameId?.call() ??
      _frameId;

  List<Stroke> get strokes {
    if (_layerController != null && _timelineController != null) {
      return _resolveActiveFrame()?.strokes ?? const <Stroke>[];
    }

    return _findFrame(currentFrameId)?.strokes ?? const <Stroke>[];
  }

  List<StrokePoint> get activePoints => List.unmodifiable(_activePoints);

  bool get canUndo => _historyManager.canUndo;

  bool get canRedo => _historyManager.canRedo;

  void beginStroke(Offset position) {
    _activePoints
      ..clear()
      ..add(_pointFromOffset(position));
  }

  void updateStroke(Offset position) {
    if (_activePoints.isEmpty) {
      beginStroke(position);
      return;
    }

    _activePoints.add(_pointFromOffset(position));
  }

  void endStroke() {
    if (_activePoints.length < 2) {
      _activePoints.clear();
      return;
    }

    final stroke = Stroke(
      id: StrokeId(_nextStrokeId()),
      points: List<StrokePoint>.unmodifiable(_activePoints),
      brushSettings: _brushSettings,
    );

    final frameId = _resolveCurrentFrameId(createIfMissing: true);
    if (frameId == null) {
      _activePoints.clear();
      return;
    }

    _historyManager.execute(
      AddStrokeCommand(
        repository: _repository,
        frameId: frameId,
        stroke: stroke,
      ),
    );
    _activePoints.clear();
  }

  void cancelStroke() {
    _activePoints.clear();
  }

  void undo() {
    if (canUndo) {
      _historyManager.undo();
    }
  }

  void redo() {
    if (canRedo) {
      _historyManager.redo();
    }
  }

  StrokePoint _pointFromOffset(Offset position) {
    return StrokePoint(x: position.dx, y: position.dy);
  }

  String _nextStrokeId() {
    _strokeSequence += 1;
    return 'stroke-${DateTime.now().microsecondsSinceEpoch}-$_strokeSequence';
  }

  String _nextFrameId(LayerId layerId) {
    return 'frame-${layerId.value}-${DateTime.now().microsecondsSinceEpoch}-$_strokeSequence';
  }

  List<LayerFrame> layerFramesForCut(CutId cutId) {
    final project = _repository.currentProject;
    if (project == null) {
      return const <LayerFrame>[];
    }

    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id != cutId) {
          continue;
        }

        final timelineController = _timelineController;
        if (timelineController == null) {
          return cut.layers
              .where((layer) => layer.frames.isNotEmpty)
              .map(
                (layer) => LayerFrame(layer: layer, frame: layer.frames.first),
              )
              .toList(growable: false);
        }

        return cut.layers
            .map((layer) {
              final frame = timelineController.resolveFrameForLayer(
                layer: layer,
              );
              if (frame == null) {
                return null;
              }
              return LayerFrame(layer: layer, frame: frame);
            })
            .nonNulls
            .toList(growable: false);
      }
    }

    return const <LayerFrame>[];
  }

  Frame? _resolveActiveFrame() {
    final layerController = _layerController;
    final timelineController = _timelineController;
    if (layerController == null || timelineController == null) {
      return null;
    }

    final layer = layerController.activeLayer;
    if (layer == null) {
      return null;
    }

    return timelineController.resolveFrameForLayer(layer: layer);
  }

  FrameId? _resolveCurrentFrameId({required bool createIfMissing}) {
    final layerController = _layerController;
    final timelineController = _timelineController;
    if (layerController == null || timelineController == null) {
      return null;
    }

    final layer = layerController.activeLayer;
    if (layer == null) {
      return null;
    }

    final resolvedFrame = timelineController.resolveFrameForLayer(layer: layer);
    if (resolvedFrame != null) {
      return resolvedFrame.id;
    }

    if (!createIfMissing) {
      return null;
    }

    final frameId = FrameId(_nextFrameId(layer.id));
    timelineController.createDrawingFrameForLayer(
      layerId: layer.id,
      frameId: frameId,
    );
    return frameId;
  }

  Frame? _findFrame(FrameId frameId) {
    final project = _repository.currentProject;
    if (project == null) {
      return null;
    }

    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        for (final layer in cut.layers) {
          for (final frame in layer.frames) {
            if (frame.id == frameId) {
              return frame;
            }
          }
        }
      }
    }

    return null;
  }
}

class LayerFrame {
  const LayerFrame({required this.layer, required this.frame});

  final Layer layer;
  final Frame frame;
}
