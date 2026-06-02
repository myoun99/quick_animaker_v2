import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../services/commands/add_layer_command.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

class LayerController {
  LayerController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required CutId cutId,
    required FrameId frameId,
    LayerId? initialActiveLayerId,
  }) : _repository = repository,
       _historyManager = historyManager,
       _cutId = cutId,
       _defaultFrameId = frameId,
       _activeLayerId = initialActiveLayerId {
    if (_activeLayerId != null && !_hasLayer(_activeLayerId!)) {
      throw StateError('Layer not found: $_activeLayerId');
    }
    _activeLayerId ??= layers.isEmpty ? null : layers.first.id;
  }

  final ProjectRepository _repository;
  final HistoryManager _historyManager;
  final CutId _cutId;
  final FrameId _defaultFrameId;

  LayerId? _activeLayerId;

  List<Layer> get layers => _findCut().layers;

  LayerId? get activeLayerId {
    _ensureActiveLayerExists();
    return _activeLayerId;
  }

  Layer? get activeLayer {
    final id = activeLayerId;
    if (id == null) {
      return null;
    }

    return layers.firstWhere((layer) => layer.id == id);
  }

  bool get hasActiveLayer => activeLayer != null;

  FrameId get frameId {
    final layer = activeLayer;
    if (layer == null) {
      return _defaultFrameId;
    }
    if (layer.frames.isEmpty) {
      throw StateError('Active layer has no frames: ${layer.id}');
    }
    return layer.frames.first.id;
  }

  Frame? get activeFrame {
    final layer = activeLayer;
    if (layer == null || layer.frames.isEmpty) {
      return null;
    }
    return layer.frames.first;
  }

  void selectLayer(LayerId layerId) {
    if (!_hasLayer(layerId)) {
      throw StateError('Layer not found: $layerId');
    }
    _activeLayerId = layerId;
  }

  void addLayer({required Layer layer}) {
    _historyManager.execute(
      AddLayerCommand(repository: _repository, cutId: _cutId, layer: layer),
    );
    _activeLayerId = layer.id;
  }

  void addLayerWithDefaults({required LayerId layerId, required String name}) {
    addLayer(
      layer: Layer(
        id: layerId,
        name: name,
        frames: [
          Frame(
            id: FrameId('${_defaultFrameId.value}-${layerId.value}'),
            duration: 1,
            strokes: const [],
          ),
        ],
      ),
    );
  }

  void toggleLayerVisibility(LayerId layerId) {
    _repository.updateLayer(
      layerId: layerId,
      update: (layer) => layer.copyWith(isVisible: !layer.isVisible),
    );
  }

  void setLayerOpacity({required LayerId layerId, required double opacity}) {
    _repository.updateLayer(
      layerId: layerId,
      update: (layer) =>
          layer.copyWith(opacity: opacity.clamp(0.0, 1.0).toDouble()),
    );
  }

  Cut _findCut() {
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == _cutId) {
          return cut;
        }
      }
    }

    throw StateError('Cut not found: $_cutId');
  }

  bool _hasLayer(LayerId layerId) {
    return layers.any((layer) => layer.id == layerId);
  }

  void _ensureActiveLayerExists() {
    final id = _activeLayerId;
    if (id == null) {
      _activeLayerId = layers.isEmpty ? null : layers.first.id;
      return;
    }

    if (!_hasLayer(id)) {
      _activeLayerId = layers.isEmpty ? null : layers.first.id;
    }
  }
}
