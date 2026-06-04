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
      final entries = _entriesForLayer(layer);
      for (final entry in entries) {
        final authoredEnd = entry.authoredEndIndex;
        if (authoredEnd > maxLength) {
          maxLength = authoredEnd;
        }
      }
    }

    return maxLength;
  }

  Frame? resolveFrameForLayer({required Layer layer, int? frameIndex}) {
    final targetIndex = frameIndex ?? _currentFrameIndex;
    if (targetIndex < 0 || layer.frames.isEmpty) {
      return null;
    }

    final entries = _entriesForLayer(layer);
    if (entries.isEmpty || targetIndex < entries.first.startIndex) {
      return null;
    }

    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      final nextStartIndex = index + 1 < entries.length
          ? entries[index + 1].startIndex
          : null;

      if (targetIndex < entry.startIndex) {
        return null;
      }

      if (nextStartIndex == null || targetIndex < nextStartIndex) {
        return entry.frame;
      }
    }

    return entries.last.frame;
  }

  FrameId? resolveFrameIdForLayer({required Layer layer, int? frameIndex}) {
    return resolveFrameForLayer(layer: layer, frameIndex: frameIndex)?.id;
  }

  Frame? getSelectedFrameForLayer(Layer layer) {
    return resolveFrameForLayer(layer: layer);
  }

  FrameId? getSelectedFrameIdForLayer(Layer layer) {
    return getSelectedFrameForLayer(layer)?.id;
  }

  bool hasSelectedFrameForLayer(Layer layer) {
    return getSelectedFrameForLayer(layer) != null;
  }

  bool hasDrawingAtCurrentFrame({required Layer layer}) {
    return hasSelectedFrameForLayer(layer);
  }

  bool isDrawingStartForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }

    final resolvedFrameId = resolveFrameIdForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    if (resolvedFrameId == null) {
      return false;
    }

    return exposureStartIndexForLayer(layer: layer, frameId: resolvedFrameId) ==
        frameIndex;
  }

  bool isHeldExposureForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }

    final resolvedFrameId = resolveFrameIdForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    if (resolvedFrameId == null) {
      return false;
    }

    return exposureStartIndexForLayer(layer: layer, frameId: resolvedFrameId) !=
        frameIndex;
  }

  int? exposureStartIndexForLayer({
    required Layer layer,
    required FrameId frameId,
  }) {
    return _entryForFrame(layer: layer, frameId: frameId)?.startIndex;
  }

  int? effectiveDurationForLayerFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    final entry = _entryForFrame(layer: layer, frameId: frameId);
    if (entry == null) {
      return null;
    }

    return _effectiveEndIndexForEntry(layer: layer, entry: entry) -
        entry.startIndex;
  }

  bool canIncreaseExposure({required Layer layer, required FrameId frameId}) {
    return _entryForFrame(layer: layer, frameId: frameId) != null;
  }

  bool canDecreaseExposure({required Layer layer, required FrameId frameId}) {
    final entry = _entryForFrame(layer: layer, frameId: frameId);
    if (entry == null) {
      return false;
    }

    return _nextEntryForFrame(layer: layer, frameId: frameId) != null &&
        _effectiveEndIndexForEntry(layer: layer, entry: entry) -
                entry.startIndex >
            1;
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

    final layer = _requireLayer(layerId);
    final hasFrameAtCurrentIndex = _entriesForLayer(
      layer,
    ).any((entry) => entry.startIndex == _currentFrameIndex);
    if (hasFrameAtCurrentIndex) {
      throw StateError(
        'Drawing frame already exists at timeline index $_currentFrameIndex.',
      );
    }

    _repository.addFrame(
      layerId: layerId,
      frame: Frame(id: frameId, duration: duration, strokes: const []),
    );
    _explicitFrameStarts.putIfAbsent(layerId, () => <FrameId, int>{})[frameId] =
        _currentFrameIndex;
  }

  void increaseExposure({required LayerId layerId, required FrameId frameId}) {
    final layer = _requireLayer(layerId);
    _requireFrameInLayer(layer: layer, frameId: frameId);
    final connectedEntries = _connectedFollowingEntries(
      layer: layer,
      frameId: frameId,
    );

    if (connectedEntries.isNotEmpty) {
      _shiftFrameStarts(layerId: layerId, entries: connectedEntries, delta: 1);
    }

    _repository.updateFrame(
      frameId: frameId,
      update: (frame) =>
          frame.copyWith(duration: _safeDuration(frame.duration) + 1),
    );
  }

  void decreaseExposure({required LayerId layerId, required FrameId frameId}) {
    final layer = _requireLayer(layerId);
    final frame = _requireFrameInLayer(layer: layer, frameId: frameId);
    if (!canDecreaseExposure(layer: layer, frameId: frameId)) {
      return;
    }

    final connectedEntries = _connectedFollowingEntries(
      layer: layer,
      frameId: frameId,
    );

    if (connectedEntries.isNotEmpty) {
      _shiftFrameStarts(layerId: layerId, entries: connectedEntries, delta: -1);
    }

    final currentDuration = _safeDuration(frame.duration);
    if (currentDuration > 1) {
      _repository.updateFrame(
        frameId: frameId,
        update: (frame) => frame.copyWith(duration: currentDuration - 1),
      );
    }
  }

  Frame _requireFrameInLayer({required Layer layer, required FrameId frameId}) {
    for (final frame in layer.frames) {
      if (frame.id == frameId) {
        return frame;
      }
    }

    throw StateError('Frame not found in layer ${layer.id}: $frameId');
  }

  Layer _requireLayer(LayerId layerId) {
    final cut = _findCutOrNull();
    if (cut == null) {
      throw StateError('Cut not found: $_cutId');
    }

    for (final layer in cut.layers) {
      if (layer.id == layerId) {
        return layer;
      }
    }

    throw StateError('Layer not found: $layerId');
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

  List<_FrameExposureEntry> _entriesForLayer(Layer layer) {
    final explicitStarts =
        _explicitFrameStarts[layer.id] ?? const <FrameId, int>{};
    var nextImplicitStart = 0;
    final entries = <_FrameExposureEntry>[];

    for (final frame in layer.frames) {
      final startIndex = explicitStarts[frame.id] ?? nextImplicitStart;
      final duration = _safeDuration(frame.duration);
      entries.add(
        _FrameExposureEntry(
          frame: frame,
          startIndex: startIndex,
          duration: duration,
        ),
      );
      nextImplicitStart = startIndex + duration;
    }

    entries.sort((a, b) {
      final startComparison = a.startIndex.compareTo(b.startIndex);
      if (startComparison != 0) {
        return startComparison;
      }

      return layer.frames
          .indexWhere((frame) => frame.id == a.frame.id)
          .compareTo(
            layer.frames.indexWhere((frame) => frame.id == b.frame.id),
          );
    });
    return entries;
  }

  _FrameExposureEntry? _entryForFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    for (final entry in _entriesForLayer(layer)) {
      if (entry.frame.id == frameId) {
        return entry;
      }
    }

    return null;
  }

  List<_FrameExposureEntry> _connectedFollowingEntries({
    required Layer layer,
    required FrameId frameId,
  }) {
    final entries = _entriesForLayer(layer);
    final targetIndex = entries.indexWhere(
      (entry) => entry.frame.id == frameId,
    );
    if (targetIndex == -1 || targetIndex + 1 >= entries.length) {
      return const <_FrameExposureEntry>[];
    }

    final targetEntry = entries[targetIndex];
    final connectedEntries = <_FrameExposureEntry>[];
    var expectedStartIndex = _effectiveEndIndexForEntry(
      layer: layer,
      entry: targetEntry,
    );
    for (var index = targetIndex + 1; index < entries.length; index += 1) {
      final entry = entries[index];
      if (entry.startIndex != expectedStartIndex) {
        break;
      }

      connectedEntries.add(entry);
      expectedStartIndex = entry.authoredEndIndex;
    }

    return connectedEntries;
  }

  _FrameExposureEntry? _nextEntryForFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    final entries = _entriesForLayer(layer);
    final targetIndex = entries.indexWhere(
      (entry) => entry.frame.id == frameId,
    );
    if (targetIndex == -1 || targetIndex + 1 >= entries.length) {
      return null;
    }

    return entries[targetIndex + 1];
  }

  int _effectiveEndIndexForEntry({
    required Layer layer,
    required _FrameExposureEntry entry,
  }) {
    final nextEntry = _nextEntryForFrame(layer: layer, frameId: entry.frame.id);
    if (nextEntry != null) {
      return nextEntry.startIndex;
    }

    final visibleTimelineEnd = totalFrameCount;
    if (visibleTimelineEnd > entry.startIndex) {
      return visibleTimelineEnd;
    }

    return entry.authoredEndIndex;
  }

  void _shiftFrameStarts({
    required LayerId layerId,
    required Iterable<_FrameExposureEntry> entries,
    required int delta,
  }) {
    final layerStarts = _explicitFrameStarts.putIfAbsent(
      layerId,
      () => <FrameId, int>{},
    );
    for (final entry in entries) {
      final nextStartIndex = entry.startIndex + delta;
      if (nextStartIndex < 0) {
        throw StateError(
          'Frame start cannot be shifted before timeline index zero.',
        );
      }

      layerStarts[entry.frame.id] = nextStartIndex;
    }
  }

  int _safeDuration(int duration) => duration <= 0 ? 1 : duration;
}

class _FrameExposureEntry {
  const _FrameExposureEntry({
    required this.frame,
    required this.startIndex,
    required this.duration,
  });

  final Frame frame;
  final int startIndex;
  final int duration;

  int get authoredEndIndex => startIndex + duration;
}
