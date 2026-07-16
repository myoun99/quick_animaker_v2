/// Coverage queries over a layer's unified timeline map, shared by the
/// timeline controller, the playback composite plan/signature, and the UI
/// state mapping so every consumer agrees on what a frame shows.
///
/// A drawing entry at `s` with length `n` covers `[s, s + n)`; every
/// timeline entry is a drawing (inbetween dots live INSIDE entries as
/// [TimelineExposure.breakdownOffsets]). Everything else is empty
/// (rendered as "X" cells). Lookups use the SplayTreeMap navigation
/// methods (lastKeyBefore / firstKeyAfter), so a query costs O(log n).
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

  final key = timeline.containsKey(frameIndex)
      ? frameIndex
      : timeline.lastKeyBefore(frameIndex);
  if (key == null) {
    return null;
  }
  return TimelineDrawingBlock(startIndex: key, entry: timeline[key]!);
}

/// The drawing block covering [frameIndex], or `null` when the cell is
/// empty (an "X" cell).
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
  final key = timeline.firstKeyAfter(frameIndex);
  if (key == null) {
    return null;
  }
  return TimelineDrawingBlock(startIndex: key, entry: timeline[key]!);
}

/// The last drawing block starting strictly before [frameIndex].
TimelineDrawingBlock? previousDrawingBlockBefore(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  final key = timeline.lastKeyBefore(frameIndex);
  if (key == null) {
    return null;
  }
  return TimelineDrawingBlock(startIndex: key, entry: timeline[key]!);
}

/// Whether a block-owned inbetween dot (중간나누기 ●) renders at
/// [frameIndex]: the covering block carries a breakdown offset there.
bool hasBreakdownDotAt(
  SplayTreeMap<int, TimelineExposure> timeline,
  int frameIndex,
) {
  final block = coveringDrawingBlockAt(timeline, frameIndex);
  if (block == null) {
    return false;
  }
  return block.entry.hasBreakdownAt(frameIndex - block.startIndex);
}

/// One past the last authored cell: the maximum drawing block end. Zero
/// for an empty timeline.
int authoredTimelineExtent(SplayTreeMap<int, TimelineExposure> timeline) {
  final lastKey = timeline.lastKey();
  if (lastKey == null) {
    return 0;
  }
  return lastKey + timeline[lastKey]!.length!;
}

/// All drawing blocks in start order.
List<TimelineDrawingBlock> drawingBlocks(
  SplayTreeMap<int, TimelineExposure> timeline,
) {
  return [
    for (final entry in timeline.entries)
      TimelineDrawingBlock(startIndex: entry.key, entry: entry.value),
  ];
}

/// Validates the coverage invariant: drawing blocks must not overlap the
/// next drawing start. Throws [ArgumentError] on violation.
void validateTimelineCoverage(SplayTreeMap<int, TimelineExposure> timeline) {
  TimelineDrawingBlock? previous;
  for (final entry in timeline.entries) {
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
