import '../models/attached_layer_resolve.dart';
import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/layer_kind.dart';
import 'default_layer_helpers.dart';
import '../services/commands/add_layer_command.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

class LayerController {
  LayerController({
    required ProjectRepository repository,
    required HistoryManager historyManager,
    required CutId? cutId,
    required FrameId frameId,
    LayerId? initialActiveLayerId,
    List<Layer> Function()? trackSeDisplayLayers,
  }) : _repository = repository,
       _historyManager = historyManager,
       _cutId = cutId,
       _defaultFrameId = frameId,
       _trackSeDisplayLayers = trackSeDisplayLayers,
       _activeLayerId = initialActiveLayerId {
    if (_activeLayerId != null && !_hasLayer(_activeLayerId!)) {
      throw StateError('Layer not found: $_activeLayerId');
    }
    _activeLayerId ??= layers.isEmpty ? null : layers.first.id;
  }

  final ProjectRepository _repository;
  final HistoryManager _historyManager;

  /// NULL = no active cut (gap state, UI-R9 #3): [layers] is empty and
  /// layer creation stands down.
  final CutId? _cutId;
  final FrameId _defaultFrameId;

  /// The track's SE rows as cut-local DISPLAY clones (the session windows
  /// them per active cut). They join [layers] so selection, row rendering
  /// and every read path see one composed list; mutations detect SE ids
  /// and edit the track's GLOBAL layers instead (never these clones).
  final List<Layer> Function()? _trackSeDisplayLayers;

  LayerId? _activeLayerId;

  List<Layer> get layers {
    final cut = _findCutOrNull();
    if (cut == null) {
      // Gap state: no rows at all — not even the track SE clones (the
      // timeline shows its empty state).
      return const <Layer>[];
    }
    final cutLayers = cut.layers;
    // Attach rows join as DISPLAY clones whose timeline mirrors the base
    // through the cell links (W5) — the same read-clone pattern as the
    // track SE rows below; writes address the real layers via commands.
    final displayed = [
      for (final layer in cutLayers)
        if (isAttachedLayer(layer))
          switch (attachedBaseOf(layer, cutLayers)) {
            null => layer,
            final base => attachedDisplayLayer(attached: layer, base: base),
          }
        else
          layer,
    ];
    final trackSe = _trackSeDisplayLayers?.call() ?? const <Layer>[];
    if (trackSe.isEmpty) {
      return displayed;
    }
    return [...displayed, ...trackSe];
  }

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

  void addLayer({required Layer layer, int? insertionIndex}) {
    final cutId = _cutId;
    if (cutId == null) {
      return; // Gap state: nowhere to add (the UI stands down too).
    }
    _historyManager.execute(
      AddLayerCommand(
        repository: _repository,
        cutId: cutId,
        layer: layer,
        insertionIndex: insertionIndex ?? _insertionIndexAboveActiveLayer(),
      ),
    );
    _activeLayerId = layer.id;
  }

  void addLayerWithDefaults({
    required LayerId layerId,
    String? name,
    LayerKind kind = LayerKind.animation,
  }) {
    final cut = _findCutOrNull();
    if (cut == null) {
      return;
    }
    addLayer(
      layer: createDefaultAnimationLayer(
        layerId: layerId,
        cut: cut,
      ).copyWith(kind: kind),
    );
  }

  void toggleLayerVisibility(LayerId layerId) {
    _repository.updateLayer(
      layerId: layerId,
      update: (layer) => layer.copyWith(isVisible: !layer.isVisible),
    );
  }

  /// The audio counterpart of [toggleLayerVisibility]: silences the SE
  /// row's sounds without touching them (view state, not undoable).
  void toggleLayerMuted(LayerId layerId) {
    _repository.updateLayer(
      layerId: layerId,
      update: (layer) => layer.copyWith(muted: !layer.muted),
    );
  }

  void setLayerOpacity({required LayerId layerId, required double opacity}) {
    _repository.updateLayer(
      layerId: layerId,
      update: (layer) =>
          layer.copyWith(opacity: opacity.clamp(0.0, 1.0).toDouble()),
    );
  }

  Cut? _findCutOrNull() {
    if (_cutId == null) {
      return null;
    }
    final project = _repository.requireProject();
    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == _cutId) {
          return cut;
        }
      }
    }
    return null;
  }

  bool _hasLayer(LayerId layerId) {
    return layers.any((layer) => layer.id == layerId);
  }

  int _insertionIndexAboveActiveLayer() {
    // Insertion is into the CUT's layer list; a track-SE active layer is
    // not in it and appends like no-selection does.
    final cutLayers = _findCutOrNull()?.layers ?? const <Layer>[];
    final id = _activeLayerId;
    if (id == null) {
      return cutLayers.length;
    }

    final index = cutLayers.indexWhere((layer) => layer.id == id);
    return index < 0 ? cutLayers.length : index + 1;
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
