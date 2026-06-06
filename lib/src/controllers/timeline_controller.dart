import 'dart:collection';

import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/timeline_exposure.dart';
import '../models/timeline_exposure_type.dart';
import '../models/timeline_mark.dart';
import '../services/commands/update_layer_timeline_command.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

class TimelineController {
  TimelineController({
    required ProjectRepository repository,
    required CutId cutId,
    HistoryManager? historyManager,
    int initialFrameIndex = 0,
  }) : _repository = repository,
       _historyManager = historyManager,
       _cutId = cutId {
    selectFrameIndex(initialFrameIndex);
  }

  final ProjectRepository _repository;
  final HistoryManager? _historyManager;
  final CutId _cutId;

  int _currentFrameIndex = 0;

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
      for (final entry in _entriesForLayer(layer)) {
        final authoredEnd = _authoredEndIndex(layer: layer, entry: entry);
        if (authoredEnd > maxLength) {
          maxLength = authoredEnd;
        }
      }
    }

    return maxLength;
  }

  Frame? resolveFrameForLayer({required Layer layer, int? frameIndex}) {
    final exposure = resolveExposureEntryForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    if (exposure == null || exposure.type == TimelineExposureType.blank) {
      return null;
    }

    final frameId = exposure.frameId;
    if (frameId == null) {
      return null;
    }

    for (final frame in layer.frames) {
      if (frame.id == frameId) {
        return frame;
      }
    }

    return null;
  }

  TimelineExposure? resolveExposureEntryForLayer({
    required Layer layer,
    int? frameIndex,
  }) {
    final targetIndex = frameIndex ?? _currentFrameIndex;
    if (targetIndex < 0 || layer.timeline.isEmpty) {
      return null;
    }

    TimelineExposure? activeExposure;
    for (final entry in layer.timeline.entries) {
      if (entry.key > targetIndex) {
        break;
      }
      activeExposure = entry.value;
    }

    return activeExposure;
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
    return layer.timeline[frameIndex]?.type == TimelineExposureType.drawing;
  }

  bool isBlankStartForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }
    return layer.timeline[frameIndex]?.type == TimelineExposureType.blank;
  }

  bool isHeldExposureForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0 ||
        isDrawingStartForLayer(layer: layer, frameIndex: frameIndex)) {
      return false;
    }

    final exposure = resolveExposureEntryForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    return exposure?.type == TimelineExposureType.drawing;
  }

  bool isBlankHeldForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0 ||
        isBlankStartForLayer(layer: layer, frameIndex: frameIndex)) {
      return false;
    }

    final exposure = resolveExposureEntryForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    return exposure?.type == TimelineExposureType.blank;
  }

  int? exposureStartIndexForLayer({
    required Layer layer,
    required FrameId frameId,
  }) {
    for (final entry in layer.timeline.entries) {
      final exposure = entry.value;
      if (exposure.type == TimelineExposureType.drawing &&
          exposure.frameId == frameId) {
        return entry.key;
      }
    }
    return null;
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

  bool canCreateDrawingAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }

    final authoredExposure = layer.timeline[frameIndex];
    return authoredExposure == null ||
        authoredExposure.type == TimelineExposureType.blank;
  }

  bool canCreateBlankAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0 || layer.timeline.containsKey(frameIndex)) {
      return false;
    }

    final exposure = resolveExposureEntryForLayer(
      layer: layer,
      frameIndex: frameIndex,
    );
    return exposure?.type == TimelineExposureType.drawing;
  }

  bool canIncreaseExposure({required Layer layer, required FrameId frameId}) {
    return _entryForFrame(layer: layer, frameId: frameId) != null;
  }

  bool canDecreaseExposure({required Layer layer, required FrameId frameId}) {
    final entry = _entryForFrame(layer: layer, frameId: frameId);
    if (entry == null) {
      return false;
    }

    final nextEntry = _nextEntryAfterStart(
      layer: layer,
      startIndex: entry.startIndex,
    );
    return nextEntry != null && nextEntry.startIndex - entry.startIndex > 1;
  }

  bool hasMarkAt({required Layer layer, required int frameIndex}) {
    return markAt(layer: layer, frameIndex: frameIndex) != null;
  }

  TimelineMark? markAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return null;
    }
    return layer.marks[frameIndex];
  }

  bool canToggleMarkAt({required Layer layer, required int frameIndex}) {
    return frameIndex >= 0;
  }

  void toggleMarkForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    if (!canToggleMarkAt(layer: before, frameIndex: _currentFrameIndex)) {
      return;
    }

    final nextMarks = SplayTreeMap<int, TimelineMark>.from(before.marks);
    if (nextMarks.containsKey(_currentFrameIndex)) {
      nextMarks.remove(_currentFrameIndex);
    } else {
      nextMarks[_currentFrameIndex] = const TimelineMark.inbetween();
    }

    _applyLayerEdit(
      before: before,
      after: before.copyWith(marks: nextMarks),
    );
  }


  bool canRenameFrameAt({required Layer layer, required int frameIndex}) {
    return resolveFrameForLayer(layer: layer, frameIndex: frameIndex) != null;
  }

  void renameFrameForLayer({
    required LayerId layerId,
    required FrameId frameId,
    required String? name,
  }) {
    final before = _requireLayer(layerId);
    _requireFrameInLayer(layer: before, frameId: frameId);
    final normalizedName = _normalizeFrameName(name);
    final nextFrames = before.frames
        .map(
          (frame) => frame.id == frameId
              ? frame.copyWith(name: normalizedName)
              : frame,
        )
        .toList(growable: false);
    final after = before.copyWith(frames: nextFrames);
    if (after == before) {
      return;
    }

    _applyLayerEdit(before: before, after: after);
  }

  bool canDeleteCellAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }

    return hasMarkAt(layer: layer, frameIndex: frameIndex) ||
        isDrawingStartForLayer(layer: layer, frameIndex: frameIndex) ||
        isBlankStartForLayer(layer: layer, frameIndex: frameIndex);
  }

  void deleteCellForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    if (!canDeleteCellAt(layer: before, frameIndex: _currentFrameIndex)) {
      return;
    }

    final nextMarks = SplayTreeMap<int, TimelineMark>.from(before.marks);
    if (nextMarks.remove(_currentFrameIndex) != null) {
      _applyLayerEdit(before: before, after: before.copyWith(marks: nextMarks));
      return;
    }

    final authoredExposure = before.timeline[_currentFrameIndex];
    if (authoredExposure == null) {
      return;
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    )..remove(_currentFrameIndex);
    var nextFrames = before.frames;
    if (authoredExposure.type == TimelineExposureType.drawing) {
      final frameId = authoredExposure.frameId;
      if (frameId != null && !_timelineReferencesFrame(nextTimeline, frameId)) {
        nextFrames = before.frames
            .where((frame) => frame.id != frameId)
            .toList(growable: false);
      }
    }

    _applyLayerEdit(
      before: before,
      after: before.copyWith(frames: nextFrames, timeline: nextTimeline),
    );
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

    final before = _requireLayer(layerId);
    if (!canCreateDrawingAt(layer: before, frameIndex: _currentFrameIndex)) {
      throw StateError(
        'Timeline exposure already exists at index $_currentFrameIndex.',
      );
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    nextTimeline[_currentFrameIndex] = TimelineExposure.drawing(frameId);
    final after = before.copyWith(
      frames: [
        ...before.frames,
        Frame(id: frameId, duration: duration, strokes: const []),
      ],
      timeline: nextTimeline,
    );
    _applyLayerEdit(before: before, after: after);
  }

  void createBlankExposureForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    if (!canCreateBlankAt(layer: before, frameIndex: _currentFrameIndex)) {
      return;
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    nextTimeline[_currentFrameIndex] = const TimelineExposure.blank();
    final after = before.copyWith(timeline: nextTimeline);
    _applyLayerEdit(before: before, after: after);
  }

  void increaseExposure({required LayerId layerId, required FrameId frameId}) {
    final before = _requireLayer(layerId);
    _requireFrameInLayer(layer: before, frameId: frameId);
    final targetEntry = _entryForFrame(layer: before, frameId: frameId);
    if (targetEntry == null) {
      throw StateError('Timeline entry not found for frame $frameId.');
    }

    final connectedEntries = _connectedFollowingEntries(
      layer: before,
      startIndex: targetEntry.startIndex,
    );
    final nextTimeline = _shiftTimelineEntries(
      before.timeline,
      connectedEntries,
      1,
    );
    final nextFrames = before.frames
        .map(
          (frame) => frame.id == frameId
              ? frame.copyWith(duration: _safeDuration(frame.duration) + 1)
              : frame,
        )
        .toList(growable: false);
    _applyLayerEdit(
      before: before,
      after: before.copyWith(frames: nextFrames, timeline: nextTimeline),
    );
  }

  void decreaseExposure({required LayerId layerId, required FrameId frameId}) {
    final before = _requireLayer(layerId);
    final frame = _requireFrameInLayer(layer: before, frameId: frameId);
    if (!canDecreaseExposure(layer: before, frameId: frameId)) {
      return;
    }

    final targetEntry = _entryForFrame(layer: before, frameId: frameId)!;
    final connectedEntries = _connectedFollowingEntries(
      layer: before,
      startIndex: targetEntry.startIndex,
    );
    final nextTimeline = _shiftTimelineEntries(
      before.timeline,
      connectedEntries,
      -1,
    );
    final nextFrames = before.frames
        .map(
          (existingFrame) => existingFrame.id == frameId
              ? existingFrame.copyWith(
                  duration: _safeDuration(frame.duration) > 1
                      ? _safeDuration(frame.duration) - 1
                      : 1,
                )
              : existingFrame,
        )
        .toList(growable: false);
    _applyLayerEdit(
      before: before,
      after: before.copyWith(frames: nextFrames, timeline: nextTimeline),
    );
  }


  String? _normalizeFrameName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  bool _timelineReferencesFrame(
    Map<int, TimelineExposure> timeline,
    FrameId frameId,
  ) {
    return timeline.values.any(
      (exposure) =>
          exposure.type == TimelineExposureType.drawing &&
          exposure.frameId == frameId,
    );
  }

  Frame _requireFrameInLayer({required Layer layer, required FrameId frameId}) {
    for (final frame in layer.frames) {
      if (frame.id == frameId) {
        return frame;
      }
    }

    throw StateError('Frame not found in layer ${layer.id}: $frameId');
  }

  void _applyLayerEdit({required Layer before, required Layer after}) {
    final command = UpdateLayerTimelineCommand(
      repository: _repository,
      before: before,
      after: after,
    );
    final historyManager = _historyManager;
    if (historyManager == null) {
      command.execute();
    } else {
      historyManager.execute(command);
    }
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

  List<_TimelineEntry> _entriesForLayer(Layer layer) {
    return layer.timeline.entries
        .map(
          (entry) =>
              _TimelineEntry(startIndex: entry.key, exposure: entry.value),
        )
        .toList(growable: false);
  }

  _TimelineEntry? _entryForFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    for (final entry in _entriesForLayer(layer)) {
      if (entry.exposure.type == TimelineExposureType.drawing &&
          entry.exposure.frameId == frameId) {
        return entry;
      }
    }

    return null;
  }

  List<_TimelineEntry> _connectedFollowingEntries({
    required Layer layer,
    required int startIndex,
  }) {
    final entries = _entriesForLayer(layer);
    final targetIndex = entries.indexWhere(
      (entry) => entry.startIndex == startIndex,
    );
    if (targetIndex == -1 || targetIndex + 1 >= entries.length) {
      return const <_TimelineEntry>[];
    }

    final connectedEntries = <_TimelineEntry>[];
    var previousEntry = entries[targetIndex];
    var expectedStartIndex = _authoredEndIndex(
      layer: layer,
      entry: previousEntry,
    );
    for (var index = targetIndex + 1; index < entries.length; index += 1) {
      final entry = entries[index];
      if (entry.startIndex != expectedStartIndex) {
        if (connectedEntries.isEmpty) {
          connectedEntries.add(entry);
        }
        break;
      }

      connectedEntries.add(entry);
      previousEntry = entry;
      expectedStartIndex = _authoredEndIndex(
        layer: layer,
        entry: previousEntry,
      );
    }

    return connectedEntries;
  }

  _TimelineEntry? _nextEntryAfterStart({
    required Layer layer,
    required int startIndex,
  }) {
    for (final entry in _entriesForLayer(layer)) {
      if (entry.startIndex > startIndex) {
        return entry;
      }
    }
    return null;
  }

  int _effectiveEndIndexForEntry({
    required Layer layer,
    required _TimelineEntry entry,
  }) {
    final nextEntry = _nextEntryAfterStart(
      layer: layer,
      startIndex: entry.startIndex,
    );
    if (nextEntry != null) {
      return nextEntry.startIndex;
    }

    final visibleTimelineEnd = totalFrameCount;
    if (visibleTimelineEnd > entry.startIndex) {
      return visibleTimelineEnd;
    }

    return _authoredEndIndex(layer: layer, entry: entry);
  }

  int _authoredEndIndex({required Layer layer, required _TimelineEntry entry}) {
    if (entry.exposure.type == TimelineExposureType.blank) {
      return entry.startIndex + 1;
    }

    final frameId = entry.exposure.frameId;
    final frame = frameId == null
        ? null
        : _frameOrNull(layer: layer, frameId: frameId);
    return entry.startIndex + _safeDuration(frame?.duration ?? 1);
  }

  SplayTreeMap<int, TimelineExposure> _shiftTimelineEntries(
    SplayTreeMap<int, TimelineExposure> timeline,
    Iterable<_TimelineEntry> entries,
    int delta,
  ) {
    final movingIndexes = entries.map((entry) => entry.startIndex).toSet();
    var foundCollision = true;
    while (foundCollision) {
      foundCollision = false;
      for (final movingIndex in movingIndexes.toList(growable: false)) {
        final nextStartIndex = movingIndex + delta;
        if (nextStartIndex < 0) {
          throw StateError('Timeline entry cannot move before index zero.');
        }

        if (timeline.containsKey(nextStartIndex) &&
            !movingIndexes.contains(nextStartIndex)) {
          movingIndexes.add(nextStartIndex);
          foundCollision = true;
        }
      }
    }

    final entriesToMove =
        movingIndexes
            .map(
              (startIndex) => _TimelineEntry(
                startIndex: startIndex,
                exposure: timeline[startIndex]!,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.startIndex.compareTo(b.startIndex));
    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(timeline)
      ..removeWhere((index, _) => movingIndexes.contains(index));

    for (final entry in entriesToMove) {
      final nextStartIndex = entry.startIndex + delta;
      if (nextTimeline.containsKey(nextStartIndex)) {
        throw StateError(
          'Timeline entry already exists at index $nextStartIndex.',
        );
      }
      nextTimeline[nextStartIndex] = entry.exposure;
    }
    return nextTimeline;
  }

  Frame? _frameOrNull({required Layer layer, required FrameId frameId}) {
    for (final frame in layer.frames) {
      if (frame.id == frameId) {
        return frame;
      }
    }
    return null;
  }

  int _safeDuration(int duration) => duration <= 0 ? 1 : duration;
}

class _TimelineEntry {
  const _TimelineEntry({required this.startIndex, required this.exposure});

  final int startIndex;
  final TimelineExposure exposure;
}
