/// Coverage queries over a layer's unified timeline map, shared by the
/// timeline controller, the playback composite plan/signature, and the UI
/// state mapping so every consumer agrees on what a frame shows.
///
/// A drawing entry at `s` with length `n` covers `[s, s + n)`. Marks never
/// cover anything. Everything else is empty (rendered as "X" cells).
/// Lookups use the SplayTreeMap navigation methods (lastKeyBefore /
/// firstKeyAfter), so a query costs O(log n) plus a walk over any marks
/// directly between the query point and its covering drawing.
library;

import 'dart:collection';

import 'frame_id.dart';
import 'timeline_exposure.dart';

/// Which edge of a drawing block a comma adjustment grabs.
enum TimelineBlockEdge { start, end }

/// A drawing entry located on the timeline: its start index plus the entry.
class TimelineDrawingBlock {
  const TimelineDrawingBlock({required this.startIndex, required this.entry})
    : assert(startIndex >= 0);

  final int startIndex;
  final TimelineExposure entry;

  int get length => entry.length!;
  int get endIndexExclusive => startIndex + length;
  FrameId get frameId => entry.frameId!;

  bool covers(int frameIndex) =>
      frameIndex >= startIndex && frameIndex < endIndexExclusive;
}

/// The drawing block whose start is the last drawing key at or before
/// [frameIndex]; `null` when no drawing starts at or before it. The result
/// does NOT necessarily cover [frameIndex] — see [coveringDrawingBlockAt].
TimelineDrawingBlock? lastDrawingBlockAtOrBefore(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  if (frameIndex < 0 || timeline.isEmpty) {
    return null;
  }

  var key = timeline.containsKey(frameIndex)
      ? frameIndex
      : timeline.lastKeyBefore(frameIndex);
  while (key != null) {
    final entry = timeline[key]!;
    if (entry.isDrawing) {
      return TimelineDrawingBlock(startIndex: key, entry: entry);
    }
    key = timeline.lastKeyBefore(key);
  }
  return null;
}

/// The drawing block covering [frameIndex], or `null` when the cell is
/// empty (an "X" cell) or holds only a mark.
TimelineDrawingBlock? coveringDrawingBlockAt(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  final block = lastDrawingBlockAtOrBefore(timeline, frameIndex);
  if (block == null || !block.covers(frameIndex)) {
    return null;
  }
  return block;
}

/// The frame id exposed at [frameIndex]; `null` for empty cells.
FrameId? exposedFrameIdAt(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  return coveringDrawingBlockAt(timeline, frameIndex)?.frameId;
}

/// The first drawing block starting strictly after [frameIndex].
TimelineDrawingBlock? nextDrawingBlockAfter(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  var key = timeline.firstKeyAfter(frameIndex);
  while (key != null) {
    final entry = timeline[key]!;
    if (entry.isDrawing) {
      return TimelineDrawingBlock(startIndex: key, entry: entry);
    }
    key = timeline.firstKeyAfter(key);
  }
  return null;
}

/// The last drawing block starting strictly before [frameIndex].
TimelineDrawingBlock? previousDrawingBlockBefore(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  var key = timeline.lastKeyBefore(frameIndex);
  while (key != null) {
    final entry = timeline[key]!;
    if (entry.isDrawing) {
      return TimelineDrawingBlock(startIndex: key, entry: entry);
    }
    key = timeline.lastKeyBefore(key);
  }
  return null;
}

/// Whether a mark entry sits exactly at [frameIndex].
bool hasMarkAt(SplayTreeMap<int, TimelineExposure> timeline, int frameIndex) {
  return timeline[frameIndex]?.isMark ?? false;
}

/// One past the last authored cell: the maximum drawing block end or
/// mark index + 1. Zero for an empty timeline.
int authoredTimelineExtent(SplayTreeMap<int, TimelineExposure> timeline) {
  if (timeline.isEmpty) {
    return 0;
  }

  final lastKey = timeline.lastKey()!;
  final lastEntry = timeline[lastKey]!;
  final lastAuthoredEnd = lastEntry.isMark ? lastKey + 1 : lastKey + lastEntry.length!;

  // The last drawing block can end past a trailing mark; compare both.
  final lastDrawing = lastEntry.isDrawing
      ? null
      : previousDrawingBlockBefore(timeline, lastKey);
  final lastDrawingEnd = lastDrawing?.endIndexExclusive ?? 0;
  return lastAuthoredEnd > lastDrawingEnd ? lastAuthoredEnd : lastDrawingEnd;
}

/// All drawing blocks in start order.
List<TimelineDrawingBlock> drawingBlocks(
  SplayTreeMap<int, TimelineExposure> timeline,
) {
  final blocks = <TimelineDrawingBlock>[];
  for (final entry in timeline.entries) {
    if (entry.value.isDrawing) {
      blocks.add(
        TimelineDrawingBlock(startIndex: entry.key, entry: entry.value),
      );
    }
  }
  return blocks;
}

/// Validates the coverage invariant: drawing blocks must not overlap the
/// next drawing start, and marks must not sit on a covered start... marks
/// MAY sit inside holds or empty space, but never share an index with a
/// drawing entry (impossible by map keys) — so the only structural
/// invariant is block overlap. Throws [ArgumentError] on violation.
void validateTimelineCoverage(SplayTreeMap<int, TimelineExposure> timeline) {
  TimelineDrawingBlock? previous;
  for (final entry in timeline.entries) {
    if (!entry.value.isDrawing) {
      continue;
    }
    final block = TimelineDrawingBlock(
      startIndex: entry.key,
      entry: entry.value,
    );
    if (previous != null && previous.endIndexExclusive > block.startIndex) {
      throw ArgumentError(
        'Timeline drawing blocks overlap: '
        '[${previous.startIndex}, ${previous.endIndexExclusive}) and '
        '[${block.startIndex}, ${block.endIndexExclusive}).',
      );
    }
    previous = block;
  }
}
