import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../services/project_repository.dart';

class TimelineController {
  TimelineController({
    required ProjectRepository repository,
    required CutId cutId,
    int initialFrameIndex = 0,
  }) : _repository = repository,
       _cutId = cutId {
    selectFrameIndex(initialFrameIndex);
  }

  final ProjectRepository _repository;
  final CutId _cutId;

  int _currentFrameIndex = 0;
  final Map<LayerId, Map<FrameId, int>> _explicitFrameStarts =
      <LayerId, Map<FrameId, int>>{};

  int get currentFrameIndex => _currentFrameIndex;

  void selectFrameIndex(int frameIndex) {
    if (frameIndex < 0) {
      throw ArgumentError.value(
        frameIndex,
        'frameIndex',
        'Timeline frame index cannot be negative.',
      );
    }

    _currentFrameIndex = frameIndex;
  }

  int get totalFrameCount {
    final cut = _findCutOrNull();
    if (cut == null || cut.layers.isEmpty) {
      return 0;
    }

    var maxLength = 0;
    for (final layer in cut.layers) {
      var layerLength = 0;
      final explicitStarts =
          _explicitFrameStarts[layer.id] ?? const <FrameId, int>{};
      for (final frame in layer.frames) {
        final explicitStart = explicitStarts[frame.id];
        if (explicitStart != null) {
          final explicitEnd = explicitStart + _safeDuration(frame.duration);
          if (explicitEnd > layerLength) {
            layerLength = explicitEnd;
          }
          continue;
        }

        layerLength += _safeDuration(frame.duration);
      }

      if (layerLength > maxLength) {
        maxLength = layerLength;
      }
    }

    return maxLength;
  }

  Frame? resolveFrameForLayer({required Layer layer, int? frameIndex}) {
    final targetIndex = frameIndex ?? _currentFrameIndex;
    if (targetIndex < 0 || layer.frames.isEmpty) {
      return null;
    }

    final explicitStarts =
        _explicitFrameStarts[layer.id] ?? const <FrameId, int>{};
    for (final frame in layer.frames) {
      final explicitStart = explicitStarts[frame.id];
      if (explicitStart == null) {
        continue;
      }

      final endExclusive = explicitStart + _safeDuration(frame.duration);
      if (targetIndex >= explicitStart && targetIndex < endExclusive) {
        return frame;
      }
    }

    var currentStart = 0;
    for (final frame in layer.frames) {
      if (explicitStarts.containsKey(frame.id)) {
        continue;
      }

      final endExclusive = currentStart + _safeDuration(frame.duration);
      if (targetIndex >= currentStart && targetIndex < endExclusive) {
        return frame;
      }
      currentStart = endExclusive;
    }

    return null;
  }

  FrameId? resolveFrameIdForLayer({required Layer layer, int? frameIndex}) {
    return resolveFrameForLayer(layer: layer, frameIndex: frameIndex)?.id;
  }

  bool hasDrawingAtCurrentFrame({required Layer layer}) {
    return resolveFrameForLayer(layer: layer) != null;
  }

  void createDrawingFrameForLayer({
    required LayerId layerId,
    required FrameId frameId,
    int duration = 1,
  }) {
    if (duration < 1) {
      throw ArgumentError.value(
        duration,
        'duration',
        'Drawing frame duration must be at least 1.',
      );
    }

    _explicitFrameStarts
        .putIfAbsent(layerId, () => <FrameId, int>{})[frameId] =
        _currentFrameIndex;
    _repository.addFrame(
      layerId: layerId,
      frame: Frame(id: frameId, duration: duration, strokes: const []),
    );
  }

  Cut? _findCutOrNull() {
    final project = _repository.currentProject;
    if (project == null) {
      return null;
    }

    for (final track in project.tracks) {
      for (final cut in track.cuts) {
        if (cut.id == _cutId) {
          return cut;
        }
      }
    }

    return null;
  }

  int _safeDuration(int duration) => duration <= 0 ? 1 : duration;
}
