import 'dart:collection';

import '../models/cut.dart';
import '../models/cut_id.dart';
import '../models/frame.dart';
import '../models/frame_id.dart';
import '../models/layer.dart';
import '../models/layer_id.dart';
import '../models/timeline_coverage.dart';
import '../models/timeline_exposure.dart';
import '../services/commands/update_layer_timeline_command.dart';
import '../services/history_manager.dart';
import '../services/project_repository.dart';

/// Timeline queries and editing commands over the unified timeline model
/// (drawing blocks with explicit lengths + inbetween marks; emptiness is
/// the absence of coverage).
///
/// All coverage lookups go through `timeline_coverage.dart` (SplayTreeMap
/// navigation, O(log n)) so the controller, playback compositing and UI
/// mapping always agree.
class TimelineController {
  TimelineController({
    required ProjectRepository repository,
    required CutId cutId,
    HistoryManager? historyManager,
    int initialFrameIndex = 0,
    int Function(LayerId layerId)? frameOffsetForLayer,
    List<Layer> Function()? trackSeLayers,
  }) : _repository = repository,
       _historyManager = historyManager,
       _cutId = cutId,
       _frameOffsetForLayer = frameOffsetForLayer,
       _trackSeLayers = trackSeLayers {
    selectFrameIndex(initialFrameIndex);
  }

  final ProjectRepository _repository;
  final HistoryManager? _historyManager;
  final CutId _cutId;

  /// Track-owned SE support: SE timelines live on the track's GLOBAL frame
  /// axis while this controller's playhead is cut-local. [_requireLayer]
  /// falls back to these GLOBAL layers, and every index-based mutation
  /// shifts by [_frameOffsetForLayer] (the active cut's global start for
  /// track-SE ids, 0 otherwise). Read-side `can*` gates keep taking the
  /// cut-local DISPLAY clones + local indexes — the same coverage answer.
  final int Function(LayerId layerId)? _frameOffsetForLayer;
  final List<Layer> Function()? _trackSeLayers;

  int _currentFrameIndex = 0;

  int _editFrameIndexFor(LayerId layerId) =>
      _currentFrameIndex + (_frameOffsetForLayer?.call(layerId) ?? 0);

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

  // --- Queries -------------------------------------------------------------

  int get authoredTimelineExtentFrameCount {
    final cut = _findCutOrNull();
    if (cut == null || cut.layers.isEmpty) {
      return 0;
    }

    var maxExtent = 0;
    for (final layer in cut.layers) {
      final extent = authoredTimelineExtent(layer.timeline);
      if (extent > maxExtent) {
        maxExtent = extent;
      }
    }
    return maxExtent;
  }

  /// The drawing block covering [frameIndex] (or the current frame).
  TimelineDrawingBlock? blockForLayerAt({
    required Layer layer,
    int? frameIndex,
  }) {
    final targetIndex = frameIndex ?? _currentFrameIndex;
    if (targetIndex < 0) {
      return null;
    }
    return coveringDrawingBlockAt(layer.timeline, targetIndex);
  }

  Frame? resolveFrameForLayer({required Layer layer, int? frameIndex}) {
    final frameId = blockForLayerAt(
      layer: layer,
      frameIndex: frameIndex,
    )?.frameId;
    if (frameId == null) {
      return null;
    }
    return _frameOrNull(layer: layer, frameId: frameId);
  }

  FrameId? resolveFrameIdForLayer({required Layer layer, int? frameIndex}) {
    return blockForLayerAt(layer: layer, frameIndex: frameIndex)?.frameId;
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
    return layer.timeline[frameIndex]?.isDrawing ?? false;
  }

  bool isHeldExposureForLayer({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0 ||
        isDrawingStartForLayer(layer: layer, frameIndex: frameIndex)) {
      return false;
    }
    return coveringDrawingBlockAt(layer.timeline, frameIndex) != null;
  }

  bool hasMarkAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }
    return layer.timeline[frameIndex]?.isMark ?? false;
  }

  int? exposureStartIndexForLayer({
    required Layer layer,
    required FrameId frameId,
  }) {
    for (final entry in layer.timeline.entries) {
      if (entry.value.isDrawing && entry.value.frameId == frameId) {
        return entry.key;
      }
    }
    return null;
  }

  int? effectiveDurationForLayerFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    final startIndex = exposureStartIndexForLayer(
      layer: layer,
      frameId: frameId,
    );
    if (startIndex == null) {
      return null;
    }
    return layer.timeline[startIndex]!.length;
  }

  int? effectiveDurationForLayerAt({required Layer layer, int? frameIndex}) {
    return blockForLayerAt(layer: layer, frameIndex: frameIndex)?.length;
  }

  int linkedUseCountForLayerFrame({
    required Layer layer,
    required FrameId frameId,
  }) {
    return layer.timeline.values
        .where((entry) => entry.isDrawing && entry.frameId == frameId)
        .length;
  }

  // --- Drawing creation ------------------------------------------------------

  /// A drawing can be created on any uncovered cell (a mark there is
  /// replaced — the drawing wins).
  bool canCreateDrawingAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }
    return coveringDrawingBlockAt(layer.timeline, frameIndex) == null;
  }

  void createDrawingFrameForLayer({
    required LayerId layerId,
    required FrameId frameId,
    int length = 1,
    String? name,
    String? seName,
  }) {
    if (length < 1) {
      throw ArgumentError.value(
        length,
        'length',
        'Drawing exposure length must be at least 1.',
      );
    }

    final before = _requireLayer(layerId);
    final frameIndex = _editFrameIndexFor(layerId);
    if (!canCreateDrawingAt(layer: before, frameIndex: frameIndex)) {
      throw StateError(
        'Timeline cell is already covered at index $frameIndex.',
      );
    }

    final nextBlock = nextDrawingBlockAfter(before.timeline, frameIndex);
    final maxLength = nextBlock == null
        ? length
        : nextBlock.startIndex - frameIndex;
    final clampedLength = length > maxLength ? maxLength : length;

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    nextTimeline[frameIndex] = TimelineExposure.drawing(
      frameId,
      length: clampedLength,
    );
    final after = before.copyWith(
      frames: [
        ...before.frames,
        Frame(
          id: frameId,
          duration: clampedLength,
          strokes: const [],
          name: _normalizeFrameName(name),
          seName: _normalizeFrameName(seName),
        ),
      ],
      timeline: nextTimeline,
    );
    _applyLayerEdit(before: before, after: after);
  }

  // --- Cut exposure (the timesheet "X here" action) -------------------------

  /// Ends the covering block's hold just before [frameIndex] so the cell
  /// (and the rest of the old hold) becomes empty. Only meaningful on held
  /// cells — cutting at a block start would leave a zero-length block.
  bool canCutExposureAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }
    final block = coveringDrawingBlockAt(layer.timeline, frameIndex);
    return block != null && frameIndex > block.startIndex;
  }

  void cutExposureForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    final frameIndex = _editFrameIndexFor(layerId);
    if (!canCutExposureAt(layer: before, frameIndex: frameIndex)) {
      return;
    }

    final block = coveringDrawingBlockAt(before.timeline, frameIndex)!;
    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    nextTimeline[block.startIndex] = block.entry.copyWith(
      length: frameIndex - block.startIndex,
    );
    _applyLayerEdit(
      before: before,
      after: before.copyWith(timeline: nextTimeline),
    );
  }

  // --- Marks -----------------------------------------------------------------

  /// Marks live on held or empty cells only; a drawing start keeps its
  /// drawing (the unified map records one thing per index).
  bool canToggleMarkAt({required Layer layer, required int frameIndex}) {
    if (frameIndex < 0) {
      return false;
    }
    return !(layer.timeline[frameIndex]?.isDrawing ?? false);
  }

  void toggleMarkForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    final frameIndex = _editFrameIndexFor(layerId);
    if (!canToggleMarkAt(layer: before, frameIndex: frameIndex)) {
      return;
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    if (nextTimeline[frameIndex]?.isMark ?? false) {
      nextTimeline.remove(frameIndex);
    } else {
      nextTimeline[frameIndex] = const TimelineExposure.mark();
    }
    _applyLayerEdit(
      before: before,
      after: before.copyWith(timeline: nextTimeline),
    );
  }

  // --- Cell deletion ----------------------------------------------------------

  bool canDeleteCellAt({required Layer layer, required int frameIndex}) {
    return isDrawingStartForLayer(layer: layer, frameIndex: frameIndex);
  }

  void deleteCellForLayer({required LayerId layerId}) {
    final before = _requireLayer(layerId);
    final frameIndex = _editFrameIndexFor(layerId);
    if (!canDeleteCellAt(layer: before, frameIndex: frameIndex)) {
      return;
    }

    final entry = before.timeline[frameIndex]!;
    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    )..remove(frameIndex);
    var nextFrames = before.frames;
    final frameId = entry.frameId;
    if (frameId != null && !_timelineReferencesFrame(nextTimeline, frameId)) {
      nextFrames = before.frames
          .where((frame) => frame.id != frameId)
          .toList(growable: false);
    }

    _applyLayerEdit(
      before: before,
      after: before.copyWith(frames: nextFrames, timeline: nextTimeline),
    );
  }

  // --- Linked paste ------------------------------------------------------------

  bool canPasteLinkedFrameAt({
    required Layer layer,
    required int frameIndex,
    required FrameId copiedFrameId,
  }) {
    if (frameIndex < 0) {
      return false;
    }
    return _frameOrNull(layer: layer, frameId: copiedFrameId) != null;
  }

  void pasteLinkedFrameForLayer({
    required LayerId layerId,
    required FrameId frameId,
  }) {
    final before = _requireLayer(layerId);
    final index = _editFrameIndexFor(layerId);
    if (!canPasteLinkedFrameAt(
      layer: before,
      frameIndex: index,
      copiedFrameId: frameId,
    )) {
      return;
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>.from(
      before.timeline,
    );
    final covering = coveringDrawingBlockAt(before.timeline, index);
    FrameId? replacedFrameId;

    if (covering != null && covering.startIndex == index) {
      // On a block start: relink the block to the pasted frame.
      replacedFrameId = covering.frameId;
      nextTimeline[index] = covering.entry.copyWith(frameId: frameId);
    } else if (covering != null) {
      // Inside a hold: split — the covering block ends here, the pasted
      // frame holds for the rest of the old coverage.
      nextTimeline[covering.startIndex] = covering.entry.copyWith(
        length: index - covering.startIndex,
      );
      nextTimeline[index] = TimelineExposure.drawing(
        frameId,
        length: covering.endIndexExclusive - index,
      );
    } else {
      // Empty cell: fill up to the next block (or a single frame).
      final nextBlock = nextDrawingBlockAfter(before.timeline, index);
      nextTimeline[index] = TimelineExposure.drawing(
        frameId,
        length: nextBlock == null ? 1 : nextBlock.startIndex - index,
      );
    }

    var nextFrames = before.frames;
    if (replacedFrameId != null &&
        replacedFrameId != frameId &&
        !_timelineReferencesFrame(nextTimeline, replacedFrameId)) {
      final removedFrameId = replacedFrameId;
      nextFrames = before.frames
          .where((frame) => frame.id != removedFrameId)
          .toList(growable: false);
    }

    _applyLayerEdit(
      before: before,
      after: before.copyWith(frames: nextFrames, timeline: nextTimeline),
    );
  }

  // --- Frame rename / link -------------------------------------------------------

  bool canRenameFrameAt({required Layer layer, required int frameIndex}) {
    return resolveFrameForLayer(layer: layer, frameIndex: frameIndex) != null;
  }

  FrameId? conflictingFrameIdForRename({
    required Layer layer,
    required FrameId frameId,
    required String? name,
  }) {
    _requireFrameInLayer(layer: layer, frameId: frameId);
    final normalizedName = _normalizeFrameName(name);
    if (normalizedName == null) {
      return null;
    }

    for (final frame in layer.frames) {
      if (frame.id != frameId && frame.name == normalizedName) {
        return frame.id;
      }
    }

    return null;
  }

  void renameFrameForLayer({
    required LayerId layerId,
    required FrameId frameId,
    required String? name,
    bool allowDuplicateName = false,
    String? seName,
    bool updateSeName = false,
  }) {
    final before = _requireLayer(layerId);
    _requireFrameInLayer(layer: before, frameId: frameId);
    if (!allowDuplicateName) {
      final conflictingFrameId = conflictingFrameIdForRename(
        layer: before,
        frameId: frameId,
        name: name,
      );
      if (conflictingFrameId != null) {
        return;
      }
    }

    final normalizedName = _normalizeFrameName(name);
    final normalizedSeName = _normalizeFrameName(seName);
    final nextFrames = before.frames
        .map(
          (frame) => frame.id == frameId
              ? (updateSeName
                    // Name + SE speaker name land in the same edit — the SE
                    // dialog commits both as ONE undo step.
                    ? frame.copyWith(
                        name: normalizedName,
                        seName: normalizedSeName,
                      )
                    : frame.copyWith(name: normalizedName))
              : frame,
        )
        .toList(growable: false);
    final after = before.copyWith(frames: nextFrames);
    if (after == before) {
      return;
    }

    _applyLayerEdit(before: before, after: after);
  }

  void linkFrameForLayer({
    required LayerId layerId,
    required FrameId sourceFrameId,
    required FrameId targetFrameId,
  }) {
    final before = _requireLayer(layerId);
    _requireFrameInLayer(layer: before, frameId: sourceFrameId);
    _requireFrameInLayer(layer: before, frameId: targetFrameId);
    if (sourceFrameId == targetFrameId) {
      return;
    }

    final nextTimeline = SplayTreeMap<int, TimelineExposure>();
    for (final entry in before.timeline.entries) {
      final exposure = entry.value;
      if (exposure.isDrawing && exposure.frameId == sourceFrameId) {
        nextTimeline[entry.key] = exposure.copyWith(frameId: targetFrameId);
      } else {
        nextTimeline[entry.key] = exposure;
      }
    }

    var nextFrames = before.frames;
    if (!_timelineReferencesFrame(nextTimeline, sourceFrameId)) {
      nextFrames = before.frames
          .where((frame) => frame.id != sourceFrameId)
          .toList(growable: false);
    }

    final after = before.copyWith(frames: nextFrames, timeline: nextTimeline);
    if (after == before) {
      return;
    }

    _applyLayerEdit(before: before, after: after);
  }

  // --- Comma adjustment (TVPaint-style edge shift) ------------------------------

  /// Whether the block starting at [blockStartIndex] can shift its [edge]
  /// at all in the direction of [delta] (used to enable UI affordances;
  /// the actual applied delta is clamped by [clampExposureEdgeDelta]).
  bool canShiftExposureEdge({
    required Layer layer,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    return clampExposureEdgeDelta(
          layer: layer,
          blockStartIndex: blockStartIndex,
          edge: edge,
          delta: delta,
        ) !=
        0;
  }

  /// The largest applicable portion of [delta] for an edge shift:
  /// shrinking stops at length 1, and start-edge growth stops when the
  /// pushed chain would cross frame 0. Growth toward the open end is
  /// unlimited.
  int clampExposureEdgeDelta({
    required Layer layer,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    final entry = layer.timeline[blockStartIndex];
    if (entry == null || !entry.isDrawing || delta == 0) {
      return 0;
    }
    final length = entry.length!;

    switch (edge) {
      case TimelineBlockEdge.end:
        if (delta > 0) {
          return delta;
        }
        // Shrink from the end: keep at least one frame.
        return delta < 1 - length ? 1 - length : delta;
      case TimelineBlockEdge.start:
        if (delta > 0) {
          // Shrink from the front: keep at least one frame.
          return delta > length - 1 ? length - 1 : delta;
        }
        // Grow backward: limited by the room the preceding glued/pushed
        // chain has before frame 0.
        final maxGrow = _startEdgeGrowRoom(
          layer.timeline,
          blockStartIndex: blockStartIndex,
        );
        return delta < -maxGrow ? -maxGrow : delta;
    }
  }

  /// Pure computation of the layer after a comma edge shift; `null` when
  /// the clamped delta is zero. Exposed for drag previews (apply directly,
  /// commit once on release) while [shiftExposureEdge] applies it as a
  /// single undoable command.
  Layer? shiftedLayerForEdge({
    required Layer layer,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    final clampedDelta = clampExposureEdgeDelta(
      layer: layer,
      blockStartIndex: blockStartIndex,
      edge: edge,
      delta: delta,
    );
    if (clampedDelta == 0) {
      return null;
    }

    final nextTimeline = _shiftEdgeTimeline(
      layer.timeline,
      blockStartIndex: blockStartIndex,
      edge: edge,
      delta: clampedDelta,
    );
    return layer.copyWith(timeline: nextTimeline);
  }

  void shiftExposureEdge({
    required LayerId layerId,
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    final before = _requireLayer(layerId);
    // Callers pass the block start as DISPLAYED (cut-local); track-SE
    // layers store it at the global offset.
    final after = shiftedLayerForEdge(
      layer: before,
      blockStartIndex:
          blockStartIndex + (_frameOffsetForLayer?.call(layerId) ?? 0),
      edge: edge,
      delta: delta,
    );
    if (after == null || after == before) {
      return;
    }
    _applyLayerEdit(before: before, after: after);
  }

  /// Commits an already-applied drag as one undoable step: the repository
  /// currently holds [after]; the command's execute is idempotent.
  void commitLayerTimelineDrag({required Layer before, required Layer after}) {
    if (before == after) {
      return;
    }
    _applyLayerEdit(before: before, after: after);
  }

  // --- Shift internals -----------------------------------------------------------

  /// How far the start edge can grow backward: empty space in front plus
  /// the gaps the preceding glued/pushed chain can absorb before its head
  /// hits frame 0. Mirrors the shift algorithm's contact rules.
  int _startEdgeGrowRoom(
    SplayTreeMap<int, TimelineExposure> timeline, {
    required int blockStartIndex,
  }) {
    // Total space before the block minus the total length of all blocks in
    // front of it: pushing can compact every gap, so that difference is
    // exactly the reachable room.
    var precedingLengths = 0;
    for (final entry in timeline.entries) {
      if (entry.key >= blockStartIndex) {
        break;
      }
      if (entry.value.isDrawing) {
        precedingLengths += entry.value.length!;
      }
    }
    return blockStartIndex - precedingLengths;
  }

  SplayTreeMap<int, TimelineExposure> _shiftEdgeTimeline(
    SplayTreeMap<int, TimelineExposure> timeline, {
    required int blockStartIndex,
    required TimelineBlockEdge edge,
    required int delta,
  }) {
    final blocks = drawingBlocks(timeline);
    final targetIndex = blocks.indexWhere(
      (block) => block.startIndex == blockStartIndex,
    );
    if (targetIndex == -1) {
      throw StateError('No drawing block starts at index $blockStartIndex.');
    }

    // New start/length per block, seeded with the resized target.
    final newStarts = List<int>.generate(
      blocks.length,
      (i) => blocks[i].startIndex,
      growable: false,
    );
    final newLengths = List<int>.generate(
      blocks.length,
      (i) => blocks[i].length,
      growable: false,
    );

    final target = blocks[targetIndex];
    switch (edge) {
      case TimelineBlockEdge.end:
        newLengths[targetIndex] = target.length + delta;
      case TimelineBlockEdge.start:
        newStarts[targetIndex] = target.startIndex + delta;
        newLengths[targetIndex] = target.length - delta;
    }

    // Ripple following blocks (end-edge resizes and front shrinks change
    // where the target ends; contact rules: glued blocks stay glued,
    // separated blocks move only when overlapped).
    var prevOldEnd = target.endIndexExclusive;
    var prevNewEnd = newStarts[targetIndex] + newLengths[targetIndex];
    for (var i = targetIndex + 1; i < blocks.length; i += 1) {
      final block = blocks[i];
      final glued = block.startIndex == prevOldEnd;
      var start = glued ? prevNewEnd : block.startIndex;
      if (start < prevNewEnd) {
        start = prevNewEnd;
      }
      newStarts[i] = start;
      prevOldEnd = block.endIndexExclusive;
      prevNewEnd = start + block.length;
    }

    // Ripple preceding blocks (start-edge moves): mirror of the above.
    var nextOldStart = target.startIndex;
    var nextNewStart = newStarts[targetIndex];
    for (var i = targetIndex - 1; i >= 0; i -= 1) {
      final block = blocks[i];
      final glued = block.endIndexExclusive == nextOldStart;
      var end = glued ? nextNewStart : block.endIndexExclusive;
      if (end > nextNewStart) {
        end = nextNewStart;
      }
      newStarts[i] = end - block.length;
      nextOldStart = block.startIndex;
      nextNewStart = newStarts[i];
    }

    if (newStarts.isNotEmpty && newStarts.first < 0) {
      throw StateError(
        'Comma edge shift would push a block before frame 0 '
        '(clamp deltas with clampExposureEdgeDelta first).',
      );
    }

    // Rebuild: drawings at their new starts; marks ride with the block that
    // covered them (target-block marks stay absolute), free marks stay put.
    final next = SplayTreeMap<int, TimelineExposure>();
    for (var i = 0; i < blocks.length; i += 1) {
      next[newStarts[i]] = blocks[i].entry.copyWith(length: newLengths[i]);
    }

    for (final entry in timeline.entries) {
      if (!entry.value.isMark) {
        continue;
      }
      var markIndex = entry.key;
      for (var i = 0; i < blocks.length; i += 1) {
        if (i != targetIndex && blocks[i].covers(markIndex)) {
          markIndex += newStarts[i] - blocks[i].startIndex;
          break;
        }
      }
      if (markIndex >= 0 && !next.containsKey(markIndex)) {
        next[markIndex] = entry.value;
      }
    }

    return next;
  }

  // --- Shared internals -------------------------------------------------------

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
      (exposure) => exposure.isDrawing && exposure.frameId == frameId,
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

    // Track-owned SE rows: mutations edit the GLOBAL layer (never the
    // cut-local display clone) — indexes shift via _editFrameIndexFor.
    for (final layer in _trackSeLayers?.call() ?? const <Layer>[]) {
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

  Frame? _frameOrNull({required Layer layer, required FrameId frameId}) {
    for (final frame in layer.frames) {
      if (frame.id == frameId) {
        return frame;
      }
    }
    return null;
  }
}
